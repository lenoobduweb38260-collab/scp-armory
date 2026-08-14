-- SCP AutoUpdate — vérificateur de mises à jour des addons synchronisés
--
-- Le script maj-auto/update_addons.sh (ou .bat) synchronise les dépôts au
-- démarrage du serveur et écrit data/scp_autoupdate/etat.txt (commit local
-- de chaque addon). Ici, on compare régulièrement ce commit avec GitHub :
-- dès que Claude pousse une modification, la console serveur et les
-- superadmins sont prévenus qu'un simple redémarrage appliquera la mise
-- à jour. Optionnel : arrêt automatique quand le serveur est vide
-- (scp_autoupdate_autoquit 1) pour les serveurs relancés en boucle.
--
-- Sécurité : lecture seule (aucune écriture de fichier, aucune exécution),
-- uniquement des requêtes GET vers api.github.com, dépôts validés par motif,
-- réponses bornées, commande réservée aux superadmins et limitée en cadence.

ScpAutoUpdate = ScpAutoUpdate or {}

local STATE_FILE = "scp_autoupdate/etat.txt"
local RECHECK = 3600 -- secondes entre deux vérifications (quota API GitHub)

local COL_TAG = Color(190, 34, 28)
local COL_TXT = Color(235, 235, 235)

local cvarAutoQuit = CreateConVar("scp_autoupdate_autoquit", "0", FCVAR_ARCHIVE,
	"Si 1 : quand une mise à jour est détectée et que le serveur est VIDE, il se ferme"
	.. " pour être relancé à jour (nécessite un script de démarrage en boucle).")

local outdated = {} -- dossier -> infos de la mise à jour disponible

local function Log(msg)
	MsgC(COL_TAG, "[MAJ AUTO] ", COL_TXT, msg .. "\n")
end

local function ReadState()
	if not file.Exists(STATE_FILE, "DATA") then return nil end
	return util.JSONToTable(file.Read(STATE_FILE, "DATA") or "")
end

-- Une seule vague de vérifications à la fois
local checking = false

local function CheckAll(reporter)
	local state = ReadState()
	if not istable(state) then
		if reporter then
			reporter("Aucun état trouvé — le script update_addons n'a pas encore tourné au démarrage de ce serveur.")
		end
		return
	end
	if checking then
		if reporter then reporter("Vérification déjà en cours…") end
		return
	end
	checking = true
	local pending = 0

	-- Jeton facultatif écrit par le script de démarrage (dépôt privé)
	local headers = { ["User-Agent"] = "gmod-scp-autoupdate" }
	if isstring(state._token) and #state._token > 0 and #state._token <= 120 then
		headers["Authorization"] = "Bearer " .. state._token
	end

	for folder, info in pairs(state) do
		if istable(info) and isstring(info.repo) and isstring(info.branch) and isstring(info.commit)
			and string.match(info.repo, "^[%w%.%-_]+/[%w%.%-_]+$") and #info.commit <= 64 then
			pending = pending + 1

			HTTP({
				method = "GET",
				url = "https://api.github.com/repos/" .. info.repo .. "/commits/"
					.. string.gsub(info.branch, "[^%w%.%-_/]", ""),
				headers = headers,
				success = function(code, body)
					pending = pending - 1
					if pending <= 0 then checking = false end
					if code ~= 200 or not isstring(body) or #body > 262144 then return end

					local data = util.JSONToTable(body)
					local sha = data and isstring(data.sha) and data.sha or nil
					if not sha then return end

					if sha == info.commit then
						outdated[folder] = nil
						if reporter then
							reporter(folder .. " : à jour (" .. string.sub(sha, 1, 7) .. ").")
						end
						return
					end

					-- Première ligne du message de commit, bornée
					local msg = data.commit and isstring(data.commit.message)
						and string.match(data.commit.message, "^[^\r\n]*") or "?"
					outdated[folder] = {
						localc = string.sub(info.commit, 1, 7),
						remote = string.sub(sha, 1, 7),
						message = string.sub(msg, 1, 120),
					}

					Log(string.format(
						"Mise à jour disponible pour « %s » : %s → %s — « %s ». Redémarrez le serveur pour l'appliquer.",
						folder, outdated[folder].localc, outdated[folder].remote, outdated[folder].message))
					if reporter then
						reporter(folder .. " : mise à jour disponible — « " .. outdated[folder].message
							.. " ». Redémarrez le serveur pour l'appliquer.")
					end

					-- Arrêt automatique optionnel, uniquement serveur vide
					if cvarAutoQuit:GetBool() and #player.GetHumans() == 0 then
						Log("Serveur vide : arrêt dans 15 s pour appliquer la mise à jour (relance via votre script en boucle).")
						timer.Create("ScpAutoUpdate_Quit", 15, 1, function()
							if #player.GetHumans() == 0 then
								game.ConsoleCommand("quit\n")
							end
						end)
					end
				end,
				failed = function()
					pending = pending - 1
					if pending <= 0 then checking = false end
				end,
			})
		end
	end

	if pending == 0 then checking = false end
end

ScpAutoUpdate.CheckAll = CheckAll

-- État au démarrage + vérification différée puis horaire
hook.Add("InitPostEntity", "ScpAutoUpdate_Boot", function()
	local state = ReadState()
	if istable(state) then
		for folder, info in pairs(state) do
			if istable(info) and isstring(info.commit) then
				Log(string.format("%s synchronisé sur %s (commit %s).",
					folder, tostring(info.branch), string.sub(info.commit, 1, 7)))
			end
		end
	else
		Log("data/scp_autoupdate/etat.txt absent — lancez maj-auto/update_addons.sh (ou .bat) au démarrage du serveur.")
	end

	timer.Simple(10, function() CheckAll(nil) end)
	timer.Create("ScpAutoUpdate_Recheck", RECHECK, 0, function() CheckAll(nil) end)
end)

-- Les superadmins qui se connectent sont prévenus des mises à jour en attente
hook.Add("PlayerInitialSpawn", "ScpAutoUpdate_Notice", function(ply)
	timer.Simple(8, function()
		if not (IsValid(ply) and ply:IsSuperAdmin()) then return end
		for folder, up in pairs(outdated) do
			ply:ChatPrint(string.format(
				"[MAJ AUTO] %s : mise à jour disponible (« %s ») — redémarrez le serveur pour l'appliquer.",
				folder, up.message))
		end
	end)
end)

-- Commande chat !maj : vérification à la demande (superadmin, anti-spam)
hook.Add("PlayerSay", "ScpAutoUpdate_Cmd", function(ply, text)
	local t = string.Trim(string.lower(text))
	if t ~= "!maj" and t ~= "!update" then return end

	if not ply:IsSuperAdmin() then
		ply:ChatPrint("[MAJ AUTO] Commande réservée aux superadmins.")
		return ""
	end
	if (ply.ScpAutoUpdateRL or 0) > CurTime() then return "" end
	ply.ScpAutoUpdateRL = CurTime() + 30

	ply:ChatPrint("[MAJ AUTO] Vérification en cours…")
	CheckAll(function(msg)
		if IsValid(ply) then ply:ChatPrint("[MAJ AUTO] " .. msg) end
	end)
	return ""
end)

-- Équivalent console : scp_autoupdate_check (console serveur ou superadmin)
concommand.Add("scp_autoupdate_check", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if IsValid(ply) then
		CheckAll(function(msg) ply:PrintMessage(HUD_PRINTCONSOLE, "[MAJ AUTO] " .. msg) end)
	else
		CheckAll(Log)
	end
end, nil, "Vérifie immédiatement si les addons synchronisés ont une mise à jour.")
