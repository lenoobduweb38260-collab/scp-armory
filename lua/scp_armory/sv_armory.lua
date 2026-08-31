-- SCP Armory — logique serveur : validation, application du loadout,
-- configuration en jeu et effets

util.AddNetworkString("SCPArmory_Apply")
util.AddNetworkString("SCPArmory_Open")
util.AddNetworkString("SCPArmory_OpenConfig")
util.AddNetworkString("SCPArmory_Config")
util.AddNetworkString("SCPArmory_SaveConfig")
util.AddNetworkString("SCPArmory_RequestConfig")
util.AddNetworkString("SCPArmory_ApplyBG")
util.AddNetworkString("SCPArmory_OpenBG")

local cvarAutoApply = CreateConVar("scp_armory_autoapply", "1", FCVAR_ARCHIVE,
	"Réapplique automatiquement le dernier loadout au respawn (si le joueur l'a demandé).")

SCPArmory.Stored = SCPArmory.Stored or {}   -- clé joueur -> loadout
SCPArmory.AutoFlag = SCPArmory.AutoFlag or {} -- clé joueur -> bool (réappliquer au respawn)

local function Notify(ply, msg)
	if IsValid(ply) then ply:ChatPrint("[ARMURERIE] " .. msg) end
end

-- Clé de stockage robuste (SteamID64 indisponible en solo/bots)
local function StoreKey(ply)
	return ply:SteamID64() or ply:SteamID() or tostring(ply:EntIndex())
end

-- Anti-spam réseau : au plus une action par fenêtre de temps et par joueur
local function RateLimit(ply, key, delay)
	if not IsValid(ply) then return false end
	local t = CurTime()
	if (ply[key] or 0) > t then return false end
	ply[key] = t + delay
	return true
end

-- Le joueur est-il à portée d'une armoire d'armurerie ?
function SCPArmory.NearLocker(ply)
	local maxDist = SCPArmory.Config.UseDistance ^ 2
	for _, ent in ipairs(ents.FindByClass("scp_armory_locker")) do
		if ent:GetPos():DistToSqr(ply:GetPos()) <= maxDist then return true end
	end
	return false
end

-- Applique un loadout validé au joueur
function SCPArmory.Apply(ply, loadout)
	if not IsValid(ply) or not ply:Alive() then return end

	local stats = SCPArmory.ComputeStats(loadout)
	local cfg = SCPArmory.Config

	ply:StripWeapons()
	ply:StripAmmo()

	for _, class in ipairs(cfg.KeepWeapons) do
		ply:Give(class)
	end

	local firstWeapon = nil

	for _, slot in ipairs(SCPArmory.Slots) do
		local id = loadout[slot.key]
		if id and id ~= "none" then
			local item = SCPArmory.GetItem(slot.pool, id)
			if item then
				if item.class then
					ply:Give(item.class)
					firstWeapon = firstWeapon or item.class
				end
				if item.ammo then
					for _, a in ipairs(item.ammo) do
						ply:GiveAmmo(a.amount, a.type, true)
					end
				end
			end
		end
	end

	ply:SetArmor(stats.armor)

	-- Gilet/casque reflétés sur le playermodel quand il a les bodygroups
	SCPArmory.ApplyBodygroups(ply, loadout)

	local mult = stats.mobility / 100
	ply:SetWalkSpeed(math.Round(cfg.BaseWalkSpeed * mult))
	ply:SetRunSpeed(math.Round(cfg.BaseRunSpeed * mult))

	if firstWeapon then
		timer.Simple(0.1, function()
			if IsValid(ply) and ply:HasWeapon(firstWeapon) then
				ply:SelectWeapon(firstWeapon)
			end
		end)
	end

	-- Pose des accessoires ARC9 sur les armes fraîchement données,
	-- avec une seconde passe de vérification (l'arme peut s'initialiser tard)
	if loadout.atts and next(loadout.atts) ~= nil then
		local function ApplyAtts()
			if not IsValid(ply) or not ply:Alive() then return end
			for wkey, attMap in pairs(loadout.atts) do
				local id = loadout[wkey]
				local item = id and id ~= "none" and SCPArmory.GetItem(wkey, id) or nil
				local wep = item and item.class and ply:GetWeapon(item.class) or nil
				if IsValid(wep) then
					-- Mémorisé sur l'arme : ré-appliqué quand on la sort
					-- (les armes en holster ratent parfois l'init ARC9)
					wep.SCPArmoryPendingAtts = attMap

					local needsApply = false
					for idx, attId in pairs(attMap) do
						if not SCPArmory.ARC9Bridge.IsInstalled(wep, idx, attId) then
							needsApply = true
							break
						end
					end
					if needsApply then
						SCPArmory.ARC9Bridge.ApplyTree(wep, attMap)
					end
				end
			end
		end

		timer.Simple(0.3, ApplyAtts)
		timer.Simple(0.9, ApplyAtts)
	end

	Notify(ply, string.format(SCPArmory.T("Chargement déployé — %.1f kg, mobilité %d%% (%s), armure %d."),
		stats.weight, stats.mobility, SCPArmory.T(stats.class), stats.armor))
end

-- Réception du loadout choisi par le client
net.Receive("SCPArmory_Apply", function(_, ply)
	if not RateLimit(ply, "SCPArmoryRL_Apply", 1.5) then return end

	if SCPArmory.Config.RequireEntity and not SCPArmory.NearLocker(ply) then
		Notify(ply, SCPArmory.T("Vous devez être à proximité d'une armoire d'armurerie pour vous équiper."))
		return
	end

	local loadout = {}
	local refused = false

	for _, slot in ipairs(SCPArmory.Slots) do
		local id = net.ReadString()
		-- Chaînes bornées : un id fantaisiste géant est rejeté sans lookup
		if #id > 64 then id = "none" end
		local item = SCPArmory.GetItem(slot.pool, id)

		if id == "none" or not item then
			loadout[slot.key] = "none"
		elseif not SCPArmory.IsItemAvailable(ply, item) then
			loadout[slot.key] = "none"
			refused = true
		else
			loadout[slot.key] = id
		end
	end

	local autoApply = net.ReadBool()

	-- Accessoires ARC9 choisis pour les armes principale et secondaire,
	-- validés contre le registre ARC9 (emplacement + compatibilité)
	local atts = {}
	for _, wkey in ipairs({ "primary", "secondary" }) do
		local count = net.ReadUInt(6)
		local map = {}
		for _ = 1, count do
			local idx = net.ReadUInt(6)
			local attId = net.ReadString()
			map[idx] = attId
		end

		local id = loadout[wkey]
		local item = id and id ~= "none" and SCPArmory.GetItem(wkey, id) or nil
		if item and item.class and SCPArmory.ARC9Bridge.IsARC9Class(item.class) then
			local clean = {}
			for idx, attId in pairs(map) do
				if #attId <= 96 and SCPArmory.ARC9Bridge.IsCompatible(item.class, idx, attId) then
					clean[idx] = attId
				end
			end
			if next(clean) ~= nil then atts[wkey] = clean end
		end
	end
	loadout.atts = atts

	-- Apparence : bodygroups personnalisés (noms autorisés en config)
	local bgCount = net.ReadUInt(5)
	local bgMap = {}
	for _ = 1, math.min(bgCount, 24) do
		local name = string.lower(net.ReadString())
		local val = net.ReadUInt(5)
		if #name <= 48 and SCPArmory.AllowedBodygroups[name] then
			bgMap[name] = val
		end
	end
	if next(bgMap) ~= nil then loadout.bg = bgMap end

	local sid = StoreKey(ply)
	SCPArmory.Stored[sid] = loadout
	SCPArmory.AutoFlag[sid] = autoApply

	if refused then
		Notify(ply, SCPArmory.T("Certains objets ne sont pas autorisés pour votre métier et ont été retirés."))
		SCPArmory.AddLog("REFUS", SCPArmory.PlayerTag(ply)
			.. " a tenté d'équiper des objets non autorisés pour son métier ["
			.. (team.GetName(ply:Team()) or "?") .. "]", ply)
	end

	SCPArmory.Apply(ply, loadout)

	-- Journal du déploiement (les ré-applications au respawn ne sont pas loguées)
	local attCount = 0
	for _, map in pairs(loadout.atts or {}) do
		for _ in pairs(map) do attCount = attCount + 1 end
	end
	local stats = SCPArmory.ComputeStats(loadout)
	SCPArmory.AddLog("DÉPLOIEMENT", string.format(
		"%s [%s] — principale: %s, secondaire: %s, accessoires: %d, %.1f kg / mobilité %d%% / armure %d",
		SCPArmory.PlayerTag(ply), team.GetName(ply:Team()) or "?",
		loadout.primary or "none", loadout.secondary or "none",
		attCount, stats.weight, stats.mobility, stats.armor), ply)
end)

-- Réapplication au respawn + remise à zéro des effets
hook.Add("PlayerSpawn", "SCPArmory_Respawn", function(ply)
	ply:SetWalkSpeed(SCPArmory.Config.BaseWalkSpeed)
	ply:SetRunSpeed(SCPArmory.Config.BaseRunSpeed)

	if not cvarAutoApply:GetBool() then return end

	local sid = StoreKey(ply)
	local loadout = SCPArmory.Stored[sid]
	if not loadout or not SCPArmory.AutoFlag[sid] then return end

	timer.Simple(0.2, function()
		if IsValid(ply) and ply:Alive() then
			SCPArmory.Apply(ply, loadout)
		end
	end)
end)

-- Commandes chat : armurerie + panneau de configuration
hook.Add("PlayerSay", "SCPArmory_ChatCommand", function(ply, text)
	local lowered = string.Trim(string.lower(text))

	for _, cmd in ipairs(SCPArmory.Config.ChatCommands) do
		if lowered == cmd then
			if SCPArmory.Config.RequireEntity and not SCPArmory.NearLocker(ply) then
				Notify(ply, SCPArmory.T("Rendez-vous à une armoire d'armurerie pour accéder à votre équipement."))
			else
				net.Start("SCPArmory_Open")
				net.Send(ply)
			end
			return ""
		end
	end

	for _, cmd in ipairs(SCPArmory.Config.ConfigChatCommands) do
		if lowered == cmd then
			if ply:IsSuperAdmin() then
				net.Start("SCPArmory_OpenConfig")
				net.Send(ply)
			else
				Notify(ply, SCPArmory.T("Le panneau de configuration est réservé aux superadmins."))
			end
			return ""
		end
	end

	for _, cmd in ipairs(SCPArmory.Config.BGChatCommands or {}) do
		if lowered == cmd then
			net.Start("SCPArmory_OpenBG")
			net.Send(ply)
			return ""
		end
	end
end)

-- Menu d'apparence autonome : application immédiate des bodygroups choisis
net.Receive("SCPArmory_ApplyBG", function(_, ply)
	if not RateLimit(ply, "SCPArmoryRL_BG", 1) then return end

	local count = net.ReadUInt(5)
	local map = {}
	for _ = 1, math.min(count, 24) do
		local name = string.lower(net.ReadString())
		local val = net.ReadUInt(5)
		if #name <= 48 and SCPArmory.AllowedBodygroups[name] then
			map[name] = val
		end
	end

	local sid = StoreKey(ply)
	SCPArmory.StoredBG = SCPArmory.StoredBG or {}
	SCPArmory.StoredBG[sid] = map

	-- Mémorisé aussi dans le loadout pour le respawn automatique
	if SCPArmory.Stored[sid] then SCPArmory.Stored[sid].bg = map end

	SCPArmory.ApplyCustomBG(ply, map)
end)

-- Filet de sécurité : quand le joueur sort une arme dont les accessoires
-- n'ont pas pris (arme secondaire restée en holster au déploiement),
-- on les ré-applique à la sortie de l'arme
hook.Add("PlayerSwitchWeapon", "SCPArmory_AttsOnSwitch", function(_, _, new)
	if not IsValid(new) or not istable(new.SCPArmoryPendingAtts) then return end

	-- Debounce : le spam de changement d'arme ne crée pas un timer par switch
	if (new.SCPArmoryAttsCheck or 0) > CurTime() then return end
	new.SCPArmoryAttsCheck = CurTime() + 1

	local map = new.SCPArmoryPendingAtts
	timer.Simple(0.15, function()
		if not IsValid(new) then return end
		for idx, attId in pairs(map) do
			if not SCPArmory.ARC9Bridge.IsInstalled(new, idx, attId) then
				SCPArmory.ARC9Bridge.ApplyTree(new, map)
				return
			end
		end
	end)
end)

-- Ré-application de l'apparence après le respawn (le modèle est réinitialisé)
hook.Add("PlayerSpawn", "SCPArmory_BGRespawn", function(ply)
	timer.Simple(0.35, function()
		if not IsValid(ply) or not ply:Alive() then return end
		local map = SCPArmory.StoredBG and SCPArmory.StoredBG[StoreKey(ply)]
		if map then SCPArmory.ApplyCustomBG(ply, map) end
	end)
end)

-- Nettoyage à la déconnexion
hook.Add("PlayerDisconnected", "SCPArmory_Cleanup", function(ply)
	local sid = StoreKey(ply)
	SCPArmory.Stored[sid] = nil
	SCPArmory.AutoFlag[sid] = nil
	if SCPArmory.StoredBG then SCPArmory.StoredBG[sid] = nil end
end)

-- ------------------------------------------------------------------------
-- Configuration en jeu : persistance serveur + diffusion aux clients
-- ------------------------------------------------------------------------

local CONFIG_FILE = "scp_armory/server_config.json"

-- Options modifiables depuis le panneau de configuration (avec leur type)
local EDITABLE = {
	RequireEntity      = "boolean",
	BlockARC9Customize = "boolean",
	AutoLoadWeapons    = "boolean",
	MenuScene          = "boolean",
	LogToFile          = "boolean",
	LogToConsole       = "boolean",
	LogRetentionDays   = "number",
	UseDistance        = "number",
	PreviewDistance    = "number",
	BaseWalkSpeed      = "number",
	BaseRunSpeed       = "number",
	MaxArmor           = "number",
	LockerModel        = "string",
	Language           = "string",
	UITheme            = "string",
	MenuBGURL          = "string",
	MenuBGWeaponURL    = "string",
	UIColorR           = "number",
	UIColorG           = "number",
	UIColorB           = "number",
}

-- Langues d'interface disponibles (sh_lang.lua)
local VALID_LANGS = { fr = true, de = true, pl = true }

-- Styles d'interface disponibles (cl_menu.lua)
local VALID_THEMES = { ron = true, mw = true }

-- Transforme "Job A, Job B" (ou une table) en liste propre de noms de jobs
-- (bornée : 24 jobs max par objet, 64 caractères max par nom)
local function ParseJobs(v)
	local list = {}
	if isstring(v) then
		for part in string.gmatch(v, "[^,]+") do
			part = string.Trim(part)
			if part ~= "" and #part <= 64 then table.insert(list, part) end
			if #list >= 24 then break end
		end
	elseif istable(v) then
		for _, part in ipairs(v) do
			if isstring(part) and #part <= 64 and string.Trim(part) ~= "" then
				table.insert(list, string.Trim(part))
			end
			if #list >= 24 then break end
		end
	end
	return list
end

-- Bornes de sécurité par option numérique (un superadmin compromis ne peut
-- pas casser le serveur avec des valeurs absurdes)
local NUM_BOUNDS = {
	UseDistance      = { 32, 2048 },
	PreviewDistance  = { 40, 400 },
	BaseWalkSpeed    = { 50, 1000 },
	BaseRunSpeed     = { 50, 2000 },
	MaxArmor         = { 1, 1000 },
	LogRetentionDays = { 0, 365 },
	UIColorR         = { 0, 255 },
	UIColorG         = { 0, 255 },
	UIColorB         = { 0, 255 },
}

local function ApplyOverrides(data)
	if istable(data.config) then
		for k, expected in pairs(EDITABLE) do
			local v = data.config[k]
			if type(v) == expected then
				if expected == "number" then
					local b = NUM_BOUNDS[k]
					v = b and math.Clamp(v, b[1], b[2]) or math.Clamp(v, 0, 100000)
				elseif expected == "string" and #v > 260 then
					v = nil
				end
				if v ~= nil then SCPArmory.Config[k] = v end
			end
		end
	end

	-- La langue ne peut être qu'une des langues traduites
	if not VALID_LANGS[SCPArmory.Config.Language] then
		SCPArmory.Config.Language = "fr"
	end

	-- Le style d'interface ne peut être qu'un des styles existants
	if not VALID_THEMES[SCPArmory.Config.UITheme] then
		SCPArmory.Config.UITheme = "ron"
	end

	-- Les fonds personnalisés doivent être des URL http(s) directes
	for _, k in ipairs({ "MenuBGURL", "MenuBGWeaponURL" }) do
		local v = SCPArmory.Config[k]
		if not isstring(v) or (v ~= "" and not string.find(v, "^https?://")) then
			SCPArmory.Config[k] = ""
		end
	end

	-- Icônes : stockées même si l'objet n'existe pas encore
	-- (armes auto-chargées après le chargement de la config).
	-- Itérations plafonnées pour borner le CPU.
	if istable(data.icons) then
		local n = 0
		for key, url in pairs(data.icons) do
			n = n + 1
			if n > 512 then break end
			if isstring(key) and isstring(url) and #url < 300
				and string.match(key, "^[%w_]+/[%w_]+$") then
				if url == "" then
					SCPArmory.ItemIcons[key] = nil
				elseif string.find(url, "^https?://") then
					SCPArmory.ItemIcons[key] = url
				end
			end
		end
	end

	-- Restrictions par job, même principe
	if istable(data.jobs) then
		local n = 0
		for key, v in pairs(data.jobs) do
			n = n + 1
			if n > 512 then break end
			if isstring(key) and string.match(key, "^[%w_]+/[%w_]+$") then
				local list = ParseJobs(v)
				SCPArmory.ItemJobs[key] = (#list > 0) and list or nil
			end
		end
	end

	-- Bodygroups autorisés aux joueurs (32 noms max, 48 caractères max)
	if istable(data.bgallow) then
		local set, n = {}, 0
		for _, name in ipairs(data.bgallow) do
			if isstring(name) and #name > 0 and #name <= 48 then
				set[string.lower(name)] = true
				n = n + 1
				if n >= 32 then break end
			end
		end
		SCPArmory.AllowedBodygroups = set
	end

	SCPArmory.ApplyPendingItemConfig()
end

local function CurrentConfigPayload()
	local cfg = {}
	for k in pairs(EDITABLE) do cfg[k] = SCPArmory.Config[k] end

	local bgallow = {}
	for name in pairs(SCPArmory.AllowedBodygroups or {}) do
		table.insert(bgallow, name)
	end
	table.sort(bgallow)

	return { config = cfg, icons = SCPArmory.ItemIcons, jobs = SCPArmory.ItemJobs, bgallow = bgallow }
end

local function SaveConfigToDisk()
	file.CreateDir("scp_armory")
	file.Write(CONFIG_FILE, util.TableToJSON(CurrentConfigPayload(), true))
end

local function LoadConfigFromDisk()
	if not file.Exists(CONFIG_FILE, "DATA") then return end
	local data = util.JSONToTable(file.Read(CONFIG_FILE, "DATA") or "")
	if istable(data) then ApplyOverrides(data) end
end

local function SendConfig(target)
	local comp = util.Compress(util.TableToJSON(CurrentConfigPayload()))
	if not comp or #comp > 60000 then return end
	net.Start("SCPArmory_Config")
	net.WriteUInt(#comp, 16)
	net.WriteData(comp, #comp)
	if target then net.Send(target) else net.Broadcast() end
end

net.Receive("SCPArmory_RequestConfig", function(_, ply)
	if not RateLimit(ply, "SCPArmoryRL_Request", 5) then return end
	SendConfig(ply)
end)

net.Receive("SCPArmory_SaveConfig", function(_, ply)
	if not IsValid(ply) then return end
	if not ply:IsSuperAdmin() then
		-- Un client modifié qui tente d'écrire la config est signalé au staff
		if RateLimit(ply, "SCPArmoryRL_BadSave", 10) then
			SCPArmory.AddLog("SÉCURITÉ", SCPArmory.PlayerTag(ply)
				.. " a tenté d'enregistrer la configuration sans être superadmin", ply)
		end
		return
	end
	if not RateLimit(ply, "SCPArmoryRL_Save", 2) then return end

	local len = net.ReadUInt(16)
	-- Décompression plafonnée à 1 Mo : une « bombe » zlib est rejetée
	local json = util.Decompress(net.ReadData(len) or "", 1048576) or ""
	local data = util.JSONToTable(json)
	if not istable(data) then return end

	-- Instantané avant application, pour journaliser le diff
	local before = {}
	for k in pairs(EDITABLE) do before[k] = SCPArmory.Config[k] end

	ApplyOverrides(data)
	SaveConfigToDisk()
	SendConfig()
	Notify(ply, SCPArmory.T("Configuration enregistrée et diffusée à tous les joueurs."))

	local changes = {}
	for k in pairs(EDITABLE) do
		if SCPArmory.Config[k] ~= before[k] then
			table.insert(changes, string.format("%s: %s → %s",
				k, tostring(before[k]), tostring(SCPArmory.Config[k])))
		end
	end
	table.sort(changes)

	SCPArmory.AddLog("CONFIG", string.format(
		"%s a enregistré la configuration — %s ; icônes: %d, objets restreints par job: %d",
		SCPArmory.PlayerTag(ply),
		#changes > 0 and table.concat(changes, ", ") or "options inchangées",
		table.Count(SCPArmory.ItemIcons), table.Count(SCPArmory.ItemJobs)), ply)
end)

LoadConfigFromDisk()
