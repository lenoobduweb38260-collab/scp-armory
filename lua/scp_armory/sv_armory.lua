-- SCP Armory — logique serveur : validation, application du loadout,
-- configuration en jeu et effets

util.AddNetworkString("SCPArmory_Apply")
util.AddNetworkString("SCPArmory_Open")
util.AddNetworkString("SCPArmory_OpenConfig")
util.AddNetworkString("SCPArmory_Config")
util.AddNetworkString("SCPArmory_SaveConfig")
util.AddNetworkString("SCPArmory_RequestConfig")

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

	-- Pose des accessoires ARC9 sur les armes fraîchement données
	if loadout.atts and next(loadout.atts) ~= nil then
		timer.Simple(0.3, function()
			if not IsValid(ply) or not ply:Alive() then return end
			for wkey, attMap in pairs(loadout.atts) do
				local id = loadout[wkey]
				local item = id and id ~= "none" and SCPArmory.GetItem(wkey, id) or nil
				local wep = item and item.class and ply:GetWeapon(item.class) or nil
				if IsValid(wep) then
					for idx, attId in pairs(attMap) do
						SCPArmory.ARC9Bridge.TryAttach(wep, idx, attId)
					end
				end
			end
		end)
	end

	Notify(ply, string.format("Chargement déployé — %.1f kg, mobilité %d%% (%s), armure %d.",
		stats.weight, stats.mobility, stats.class, stats.armor))
end

-- Réception du loadout choisi par le client
net.Receive("SCPArmory_Apply", function(_, ply)
	if SCPArmory.Config.RequireEntity and not SCPArmory.NearLocker(ply) then
		Notify(ply, "Vous devez être à proximité d'une armoire d'armurerie pour vous équiper.")
		return
	end

	local loadout = {}
	local refused = false

	for _, slot in ipairs(SCPArmory.Slots) do
		local id = net.ReadString()
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
				if SCPArmory.ARC9Bridge.IsCompatible(item.class, idx, attId) then
					clean[idx] = attId
				end
			end
			if next(clean) ~= nil then atts[wkey] = clean end
		end
	end
	loadout.atts = atts

	local sid = StoreKey(ply)
	SCPArmory.Stored[sid] = loadout
	SCPArmory.AutoFlag[sid] = autoApply

	if refused then
		Notify(ply, "Certains objets ne sont pas autorisés pour votre métier et ont été retirés.")
	end

	SCPArmory.Apply(ply, loadout)
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
				Notify(ply, "Rendez-vous à une armoire d'armurerie pour accéder à votre équipement.")
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
				Notify(ply, "Le panneau de configuration est réservé aux superadmins.")
			end
			return ""
		end
	end
end)

-- Nettoyage à la déconnexion
hook.Add("PlayerDisconnected", "SCPArmory_Cleanup", function(ply)
	local sid = StoreKey(ply)
	SCPArmory.Stored[sid] = nil
	SCPArmory.AutoFlag[sid] = nil
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
	UseDistance        = "number",
	PreviewDistance    = "number",
	BaseWalkSpeed      = "number",
	BaseRunSpeed       = "number",
	MaxArmor           = "number",
	LockerModel        = "string",
}

-- Transforme "Job A, Job B" (ou une table) en liste propre de noms de jobs
local function ParseJobs(v)
	local list = {}
	if isstring(v) then
		for part in string.gmatch(v, "[^,]+") do
			part = string.Trim(part)
			if part ~= "" then table.insert(list, part) end
		end
	elseif istable(v) then
		for _, part in ipairs(v) do
			if isstring(part) and string.Trim(part) ~= "" then
				table.insert(list, string.Trim(part))
			end
		end
	end
	return list
end

local function ApplyOverrides(data)
	if istable(data.config) then
		for k, expected in pairs(EDITABLE) do
			local v = data.config[k]
			if type(v) == expected then
				if expected == "number" then v = math.Clamp(v, 0, 100000) end
				SCPArmory.Config[k] = v
			end
		end
	end

	-- Icônes : stockées même si l'objet n'existe pas encore
	-- (armes auto-chargées après le chargement de la config)
	if istable(data.icons) then
		for key, url in pairs(data.icons) do
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
		for key, v in pairs(data.jobs) do
			if isstring(key) and string.match(key, "^[%w_]+/[%w_]+$") then
				local list = ParseJobs(v)
				SCPArmory.ItemJobs[key] = (#list > 0) and list or nil
			end
		end
	end

	SCPArmory.ApplyPendingItemConfig()
end

local function CurrentConfigPayload()
	local cfg = {}
	for k in pairs(EDITABLE) do cfg[k] = SCPArmory.Config[k] end
	return { config = cfg, icons = SCPArmory.ItemIcons, jobs = SCPArmory.ItemJobs }
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
	SendConfig(ply)
end)

net.Receive("SCPArmory_SaveConfig", function(_, ply)
	if not IsValid(ply) or not ply:IsSuperAdmin() then return end

	local len = net.ReadUInt(16)
	local json = util.Decompress(net.ReadData(len) or "") or ""
	local data = util.JSONToTable(json)
	if not istable(data) then return end

	ApplyOverrides(data)
	SaveConfigToDisk()
	SendConfig()
	Notify(ply, "Configuration enregistrée et diffusée à tous les joueurs.")
end)

LoadConfigFromDisk()
