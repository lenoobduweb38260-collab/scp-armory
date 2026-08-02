-- SCP Armory — pont ARC9 (partagé)
-- Récupère automatiquement les emplacements d'accessoires des armes ARC9 et
-- le registre global d'accessoires, sans jamais ouvrir le menu ARC9.
-- Tout est protégé par pcall / vérifications : l'addon fonctionne sans ARC9.

SCPArmory = SCPArmory or {}
SCPArmory.ARC9Bridge = SCPArmory.ARC9Bridge or {}
local Bridge = SCPArmory.ARC9Bridge

local slotCache = {}

local function ToTable(v)
	if istable(v) then return v end
	if v == nil then return {} end
	return { v }
end

-- L'arme (par classe) est-elle une arme ARC9 ?
function Bridge.IsARC9Class(class)
	if not class then return false end
	local tbl = weapons.GetStored(class) or weapons.Get(class)
	if not tbl then return false end
	if tbl.ARC9 then return true end
	local base = tbl.Base
	return isstring(base) and string.StartsWith(base, "arc9") or string.StartsWith(class, "arc9_")
end

-- Emplacements d'accessoires de premier niveau d'une classe d'arme ARC9
-- Retour : { { index = i, name = "OPTIQUE", cats = { "optic", ... } }, ... }
function Bridge.GetSlots(class)
	if slotCache[class] then return slotCache[class] end

	local out = {}
	if Bridge.IsARC9Class(class) then
		local tbl = weapons.Get(class)
		if tbl and istable(tbl.Attachments) then
			for i, slot in ipairs(tbl.Attachments) do
				if istable(slot) and not slot.Hidden and not slot.Integral then
					local cats = ToTable(slot.Slot or slot.Category)
					if #cats > 0 then
						table.insert(out, {
							index = i,
							name = SCPArmory.FrUpper(tostring(slot.PrintName or ("EMPLACEMENT " .. i))),
							cats = cats,
						})
					end
				end
			end
		end
	end

	slotCache[class] = out
	return out
end

-- Entrée du registre global ARC9 pour un accessoire
function Bridge.GetAtt(attId)
	if not (ARC9 and istable(ARC9.Attachments)) then return nil end
	return ARC9.Attachments[attId]
end

function Bridge.AttName(attId)
	local att = Bridge.GetAtt(attId)
	if not att then return attId or "?" end
	return tostring(att.CompactName or att.PrintName or attId)
end

-- Accessoires du registre ARC9 compatibles avec les catégories d'un emplacement
-- Retour trié : { { id, name, cat, desc }, ... }
function Bridge.GetCompatible(cats)
	if not (ARC9 and istable(ARC9.Attachments)) then return {} end

	local wanted = {}
	for _, c in ipairs(ToTable(cats)) do
		wanted[string.lower(tostring(c))] = true
	end

	local out = {}
	for id, att in pairs(ARC9.Attachments) do
		if istable(att) and not att.Hidden and not att.InvAtt then
			for _, ac in ipairs(ToTable(att.Category)) do
				if wanted[string.lower(tostring(ac))] then
					table.insert(out, {
						id = id,
						name = SCPArmory.FrUpper(tostring(att.CompactName or att.PrintName or id)),
						cat = SCPArmory.FrUpper(tostring(ToTable(att.Category)[1] or "")),
						desc = att.Description,
					})
					break
				end
			end
		end
	end

	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- Validation serveur : cet accessoire va-t-il sur cet emplacement de cette arme ?
function Bridge.IsCompatible(class, slotIndex, attId)
	if not Bridge.GetAtt(attId) then return false end
	for _, slot in ipairs(Bridge.GetSlots(class)) do
		if slot.index == slotIndex then
			for _, entry in ipairs(Bridge.GetCompatible(slot.cats)) do
				if entry.id == attId then return true end
			end
			return false
		end
	end
	return false
end

if SERVER then
	-- L'accessoire est-il posé sur cet emplacement de l'arme ?
	function Bridge.IsInstalled(wep, slotIndex, attId)
		if not IsValid(wep) or not istable(wep.Attachments) then return false end
		local slot = wep.Attachments[slotIndex]
		return istable(slot) and slot.Installed == attId
	end

	-- Applique d'un coup tous les accessoires choisis sur une arme ARC9,
	-- en reproduisant exactement le chemin serveur d'ARC9 quand il reçoit
	-- un loadout client (SWEP:ReceiveWeapon) : BuildSubAttachments sur
	-- l'arbre complet, puis Prune/FillIntegral, SendWeapon (diffusion aux
	-- clients — c'est ce qui rend les accessoires visibles) et PostModify.
	-- Ce chemin ne passe pas par SWEP:Attach, donc ni l'inventaire ARC9 ni
	-- arc9_atts_nocustomize ne peuvent bloquer la pose.
	function Bridge.ApplyTree(wep, attMap)
		if not IsValid(wep) or not istable(wep.Attachments) then return false end

		if not isfunction(wep.BuildSubAttachments) then
			-- Version d'ARC9 inconnue : pose directe minimale
			for idx, attId in pairs(attMap) do
				if istable(wep.Attachments[idx]) and Bridge.GetAtt(attId) then
					wep.Attachments[idx].Installed = attId
				end
			end
		else
			-- Arbre complet : les emplacements non configurés gardent leur
			-- contenu d'origine (pièces intégrales, défauts d'usine…)
			local tree = {}
			for i, slot in ipairs(wep.Attachments) do
				local id = attMap[i]
				if id and not Bridge.GetAtt(id) then id = nil end
				tree[i] = {
					Installed = id or (istable(slot) and slot.Installed or nil),
					SubAttachments = {},
				}
			end

			local ok = pcall(wep.BuildSubAttachments, wep, tree)
			if not ok then return false end
		end

		-- Même chaîne de rafraîchissement que SWEP:ReceiveWeapon côté serveur
		if isfunction(wep.DoInvalidateCache) then pcall(wep.DoInvalidateCache, wep) end
		if isfunction(wep.PruneAttachments) then pcall(wep.PruneAttachments, wep) end
		if isfunction(wep.FillIntegralSlots) then pcall(wep.FillIntegralSlots, wep) end
		if isfunction(wep.SendWeapon) then pcall(wep.SendWeapon, wep) end
		if isfunction(wep.PostModify) then pcall(wep.PostModify, wep) end

		return true
	end
end

if CLIENT then
	-- Désactivation du menu de personnalisation ARC9 (touche C) :
	-- les accessoires ne se choisissent que via l'armurerie.

	hook.Add("PlayerBindPress", "SCPArmory_BlockARC9Customize", function(ply, bind, pressed)
		if not SCPArmory.Config.BlockARC9Customize then return end
		if not string.find(bind, "+menu_context", 1, true) then return end

		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep.ARC9 then return true end
	end)

	hook.Add("InitPostEntity", "SCPArmory_DetourARC9Customize", function()
		if not SCPArmory.Config.BlockARC9Customize then return end

		local base = weapons.GetStored("arc9_base")
		if not base or not isfunction(base.ToggleCustomize) then return end

		local orig = base.ToggleCustomize
		base.ToggleCustomize = function(swep, on, ...)
			-- Seule la fermeture explicite reste autorisée
			if on == false then return orig(swep, on, ...) end
		end
	end)
end
