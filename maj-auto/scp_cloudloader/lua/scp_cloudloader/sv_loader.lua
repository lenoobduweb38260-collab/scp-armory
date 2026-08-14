-- SCP Cloud Loader — serveur (v2)
--
-- À chaque démarrage : récupère le dernier commit de la branche, télécharge
-- les fichiers modifiés (cache data/scp_cloudloader/), exécute l'armurerie
-- (voir sh_runner) puis distribue les fichiers client aux joueurs par le
-- réseau, en file d'attente pour ne jamais saturer leur connexion. Chaque
-- client confirme son chargement : la console dit qui a réellement reçu
-- l'armurerie. Si GitHub est injoignable, démarrage sur le cache.
--
-- Diagnostic : commande console « scp_cloud_status » (serveur ou superadmin).
--
-- Confiance et sécurité :
--  - sources épinglées : uniquement api.github.com et raw.githubusercontent.com,
--    sur le dépôt et la branche configurés ci-dessous, en HTTPS ;
--  - tailles, nombres de fichiers et réponses bornés et validés ;
--  - les fichiers serveur (sv_*, init.lua d'entité) ne partent jamais aux clients ;
--  - requêtes des clients limitées en cadence et validées ;
--  - si l'addon scp-armory est présent sur le disque, le cloud se désactive.

util.AddNetworkString("SCPCloud_Hello")
util.AddNetworkString("SCPCloud_Manifest")
util.AddNetworkString("SCPCloud_Need")
util.AddNetworkString("SCPCloud_File")
util.AddNetworkString("SCPCloud_Done")

-- ------------------------------------------------ configuration du dépôt
local REPO   = "lenoobduweb38260-collab/scp-armory"
local BRANCH = "claude/ready-or-not-loadout-gbii3v"
-- -----------------------------------------------------------------------

local MAX_FILES    = 400
local MAX_LUA_SIZE = 262144   -- 256 Ko par fichier lua
local MAX_MAT_SIZE = 8388608  -- 8 Mo par image de fond
local CACHE_DIR    = "scp_cloudloader"
local INDEX_FILE   = CACHE_DIR .. "/index.txt"
local CHUNK        = 40000
local BOOT_DELAY   = 5        -- l'HTTP de GMod n'est pas fiable trop tôt au boot
local RETRY_DELAY  = 15

local Log = SCPCloud.Log

local files = nil      -- [chemin] = { sha, size } (fichiers lua)
local mats = nil       -- { { path, sha, size } } (images de fond)
local commitSha = nil
local loaded = false
local manifestComp = nil
local waiting = {}     -- joueurs connectés avant la fin du chargement
local retried = false

-- État exposé pour le diagnostic
SCPCloud.SV = { state = "démarrage", errors = {}, clients = {} }

local function CachePath(sha)
	return CACHE_DIR .. "/" .. string.sub(sha, 1, 32) .. ".txt"
end

-- GET avec délai de garde : le démarrage ne reste jamais suspendu
local function Fetch(url, cb)
	local done = false
	HTTP({
		method = "GET",
		url = url,
		headers = { ["User-Agent"] = "scp-cloudloader" },
		success = function(code, body)
			if done then return end
			done = true
			cb(code == 200 and body or nil)
		end,
		failed = function()
			if done then return end
			done = true
			cb(nil)
		end,
	})
	timer.Simple(45, function()
		if not done then
			done = true
			cb(nil)
		end
	end)
end

local function ReadCode(entry)
	return file.Read(CachePath(entry.sha), "DATA")
end

-- Un fichier appartient-il au lot livré aux clients ? Les fichiers serveur
-- (sv_* et init.lua d'entité) restent sur le serveur, comme dans le jeu.
local function IsClientPath(path)
	if string.find(path, "/sv_", 1, true) then return false end
	if string.match(path, "^lua/entities/.+/init%.lua$") then return false end
	return true
end

-- Manifeste envoyé aux clients : fichiers non serveur + images de fond
local function BuildManifest()
	local list = {}
	for path, e in pairs(files) do
		if IsClientPath(path) then
			table.insert(list, { p = path, s = e.sha, z = e.size })
		end
	end
	table.sort(list, function(a, b) return a.p < b.p end)

	local m = {}
	for _, e in ipairs(mats or {}) do
		table.insert(m, {
			p = e.path, s = e.sha, z = e.size,
			u = "https://raw.githubusercontent.com/" .. REPO .. "/" .. commitSha .. "/" .. e.path,
		})
	end

	return util.Compress(util.TableToJSON({ commit = commitSha, files = list, mats = m }))
end

local function ClientTag(ply)
	return ply:Nick() .. " (" .. (ply:SteamID() or "?") .. ")"
end

local function SendManifest(ply)
	if not manifestComp or not IsValid(ply) then return end
	net.Start("SCPCloud_Manifest")
	net.WriteUInt(#manifestComp, 24)
	net.WriteData(manifestComp, #manifestComp)
	net.Send(ply)
	SCPCloud.SV.clients[ply:SteamID() or "?"] = "manifeste envoyé"
	Log("Manifeste envoyé à " .. ClientTag(ply) .. ".")
end

local function FlushWaiting()
	for _, ply in ipairs(waiting) do
		SendManifest(ply)
	end
	waiting = {}
end

local function Activate(fromCache)
	local stats = SCPCloud.Execute(files, ReadCode)
	loaded = true
	manifestComp = BuildManifest()
	SCPCloud.SV.errors = stats.errors
	SCPCloud.SV.commit = string.sub(commitSha or "?", 1, 7)

	if #stats.errors == 0 then
		SCPCloud.SV.state = "armurerie active"
		Log((fromCache and "GitHub injoignable — copie en cache" or "GitHub") .. " : armurerie EXÉCUTÉE ("
			.. stats.ran .. " fichiers, commit " .. SCPCloud.SV.commit .. "). Serveur prêt.")
	else
		SCPCloud.SV.state = "exécutée avec " .. #stats.errors .. " erreur(s)"
		Log("Armurerie exécutée avec " .. #stats.errors
			.. " ERREUR(S) — détail ci-dessus et via scp_cloud_status.")
	end
	FlushWaiting()
end

local function LoadIndex()
	local idx = util.JSONToTable(file.Read(INDEX_FILE, "DATA") or "")
	if not istable(idx) or not istable(idx.files) or not isstring(idx.commit) then return false end
	for _, e in pairs(idx.files) do
		if not istable(e) or not isstring(e.sha) or not file.Exists(CachePath(e.sha), "DATA") then
			return false
		end
	end
	files = idx.files
	mats = istable(idx.mats) and idx.mats or {}
	commitSha = idx.commit
	return true
end

local Boot

local function FallbackCache(reason)
	Log(reason .. " — tentative sur la dernière copie en cache…")
	if LoadIndex() then
		Activate(true)
	elseif not retried then
		retried = true
		SCPCloud.SV.state = "nouvel essai dans " .. RETRY_DELAY .. " s"
		Log("Aucun cache utilisable : nouvel essai GitHub dans " .. RETRY_DELAY .. " s.")
		timer.Simple(RETRY_DELAY, Boot)
	else
		SCPCloud.SV.state = "échec : " .. reason
		Log("Échec définitif pour ce démarrage : armurerie indisponible (" .. reason .. ").")
	end
end

Boot = function()
	-- L'addon réel est sur le disque : le cloud s'efface complètement
	if istable(SCPArmory) and SCPArmory.Slots then
		SCPCloud.SV.state = "désactivé (addon sur le disque)"
		Log("Addon scp-armory présent sur le disque : chargement cloud désactivé.")
		loaded = true
		manifestComp = util.Compress(util.TableToJSON({ disabled = true }))
		FlushWaiting()
		return
	end

	SCPCloud.SV.state = "téléchargement GitHub…"
	file.CreateDir(CACHE_DIR)

	Fetch("https://api.github.com/repos/" .. REPO .. "/commits/" .. BRANCH, function(body)
		local data = body and util.JSONToTable(body)
		local sha = data and isstring(data.sha) and string.match(data.sha, "^%x+$") and data.sha or nil
		if not sha or #sha > 64 then
			FallbackCache("GitHub inaccessible (commit)")
			return
		end
		commitSha = sha

		Fetch("https://api.github.com/repos/" .. REPO .. "/git/trees/" .. sha .. "?recursive=1", function(tbody)
			local tree = tbody and util.JSONToTable(tbody)
			if not (istable(tree) and istable(tree.tree)) then
				FallbackCache("GitHub inaccessible (arborescence)")
				return
			end

			local wantLua, wantMats, count = {}, {}, 0
			for _, e in ipairs(tree.tree) do
				if istable(e) and e.type == "blob" and isstring(e.path) and isstring(e.sha)
					and string.match(e.sha, "^%x+$") then
					local size = tonumber(e.size) or 0
					if string.match(e.path, "^lua/[%w_/%-]+%.lua$") and size <= MAX_LUA_SIZE then
						wantLua[e.path] = { sha = e.sha, size = size }
						count = count + 1
					elseif string.match(e.path, "^materials/scp_armory/[%w_%-]+%.png$") and size <= MAX_MAT_SIZE then
						table.insert(wantMats, { path = e.path, sha = e.sha, size = size })
						count = count + 1
					end
					if count > MAX_FILES then
						FallbackCache("Dépôt anormalement volumineux")
						return
					end
				end
			end
			if next(wantLua) == nil then
				FallbackCache("Aucun fichier lua dans le dépôt")
				return
			end

			-- Seuls les fichiers absents du cache sont téléchargés
			local missing = {}
			for path, e in pairs(wantLua) do
				if not file.Exists(CachePath(e.sha), "DATA") then
					table.insert(missing, path)
				end
			end

			local pending = #missing
			local failed = false
			local function Finish()
				if failed then
					FallbackCache("Téléchargement incomplet")
					return
				end
				files = wantLua
				mats = wantMats
				file.Write(INDEX_FILE, util.TableToJSON({ commit = commitSha, files = files, mats = mats }))
				Activate(false)
			end

			if pending == 0 then
				Finish()
				return
			end

			Log("Téléchargement de " .. pending .. " fichier(s) depuis GitHub…")
			for _, path in ipairs(missing) do
				local e = wantLua[path]
				Fetch("https://raw.githubusercontent.com/" .. REPO .. "/" .. commitSha .. "/" .. path, function(code)
					if isstring(code) and #code > 0 and #code <= MAX_LUA_SIZE then
						file.Write(CachePath(e.sha), code)
					else
						failed = true
					end
					pending = pending - 1
					if pending == 0 then Finish() end
				end)
			end
		end)
	end)
end

hook.Add("InitPostEntity", "SCPCloud_Boot", function()
	Log("Chargeur cloud v2 — démarrage dans " .. BOOT_DELAY .. " s.")
	timer.Simple(BOOT_DELAY, Boot)
end)

-- ----------------------------------------- distribution aux joueurs

-- Envoi d'un fichier complet (quelques messages) à un joueur
local function SendFile(ply, sha)
	local code = file.Read(CachePath(sha), "DATA")
	if not isstring(code) or not IsValid(ply) then return end

	local comp = util.Compress(code)
	local total = math.ceil(#comp / CHUNK)
	for part = 1, total do
		local piece = string.sub(comp, (part - 1) * CHUNK + 1, part * CHUNK)
		net.Start("SCPCloud_File")
		net.WriteString(sha)
		net.WriteUInt(part, 8)
		net.WriteUInt(total, 8)
		net.WriteUInt(#piece, 16)
		net.WriteData(piece, #piece)
		net.Send(ply)
	end
end

-- File d'attente d'envoi : 2 fichiers toutes les 0,1 s et par joueur au plus,
-- pour ne jamais saturer le canal réseau d'un client (messages perdus/kick)
local sendQueue = {}

local function PumpQueue()
	for _ = 1, 2 do
		local item = table.remove(sendQueue, 1)
		if not item then
			timer.Remove("SCPCloud_Pump")
			return
		end
		if IsValid(item.ply) then
			SendFile(item.ply, item.sha)
		end
	end
end

local function QueueFiles(ply, shas)
	for _, sha in ipairs(shas) do
		table.insert(sendQueue, { ply = ply, sha = sha })
	end
	if not timer.Exists("SCPCloud_Pump") then
		timer.Create("SCPCloud_Pump", 0.1, 0, PumpQueue)
	end
end

net.Receive("SCPCloud_Hello", function(_, ply)
	if not IsValid(ply) then return end
	if (ply.SCPCloudHelloRL or 0) > CurTime() then return end
	ply.SCPCloudHelloRL = CurTime() + 4

	if loaded then
		SendManifest(ply)
	else
		table.insert(waiting, ply)
		SCPCloud.SV.clients[ply:SteamID() or "?"] = "en attente du chargement serveur"
	end
end)

net.Receive("SCPCloud_Need", function(_, ply)
	if not IsValid(ply) or not loaded or not files then return end
	if (ply.SCPCloudNeedRL or 0) > CurTime() then return end
	ply.SCPCloudNeedRL = CurTime() + 4

	-- Seuls les sha réellement servis aux clients sont acceptés
	local allowed = {}
	for path, e in pairs(files) do
		if IsClientPath(path) then
			allowed[e.sha] = true
		end
	end

	local n = math.min(net.ReadUInt(9), MAX_FILES)
	local list, seen = {}, {}
	for _ = 1, n do
		local sha = net.ReadString()
		if #sha <= 64 and allowed[sha] and not seen[sha] then
			seen[sha] = true
			table.insert(list, sha)
		end
	end

	if #list > 0 then
		SCPCloud.SV.clients[ply:SteamID() or "?"] = "envoi de " .. #list .. " fichier(s)…"
		Log("Envoi de " .. #list .. " fichier(s) à " .. ClientTag(ply) .. "…")
		QueueFiles(ply, list)
	end
end)

-- Confirmation du client : l'armurerie tourne (ou pas) chez lui
net.Receive("SCPCloud_Done", function(_, ply)
	if not IsValid(ply) then return end
	if (ply.SCPCloudDoneRL or 0) > CurTime() then return end
	ply.SCPCloudDoneRL = CurTime() + 4

	local errs = net.ReadUInt(8)
	local msg = (errs == 0) and "armurerie chargée chez le joueur"
		or ("chargée chez le joueur avec " .. errs .. " erreur(s) — voir sa console")
	SCPCloud.SV.clients[ply:SteamID() or "?"] = msg
	Log(ClientTag(ply) .. " : " .. msg .. ".")
end)

-- Les superadmins voient l'état du cloud en arrivant (diagnostic sans console)
hook.Add("PlayerInitialSpawn", "SCPCloud_AdminNotice", function(ply)
	timer.Simple(15, function()
		if not (IsValid(ply) and ply:IsSuperAdmin()) then return end
		ply:ChatPrint("[ARMURERIE CLOUD] Serveur : " .. tostring(SCPCloud.SV.state)
			.. (SCPCloud.SV.commit and (" (commit " .. SCPCloud.SV.commit .. ")") or "")
			.. ". Détail : scp_cloud_status en console.")
	end)
end)

-- Diagnostic : scp_cloud_status (console serveur ou superadmin)
concommand.Add("scp_cloud_status", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local out = IsValid(ply)
		and function(m) ply:PrintMessage(HUD_PRINTCONSOLE, "[ARMURERIE CLOUD] " .. m) end
		or Log

	out("État serveur : " .. tostring(SCPCloud.SV.state))
	out("Commit : " .. tostring(SCPCloud.SV.commit or "?") .. " — dépôt " .. REPO .. " @ " .. BRANCH)
	out("Fichiers lua : " .. (files and table.Count(files) or 0)
		.. ", erreurs d'exécution : " .. #SCPCloud.SV.errors)
	for _, e in ipairs(SCPCloud.SV.errors) do out("  ERREUR " .. e) end
	for sid, st in pairs(SCPCloud.SV.clients) do out("  Joueur " .. sid .. " : " .. st) end
end, nil, "État du chargeur cloud de l'armurerie.")
