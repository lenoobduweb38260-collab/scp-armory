-- SCP Armory — chargement automatique des packs d'armes installés (partagé)
-- Parcourt le registre des armes scriptées (ARC9, M9K, CW…) et remplit les
-- pools principale/secondaire sans configuration manuelle. Le tri par nom
-- garantit le même ordre sur le client et le serveur.

SCPArmory = SCPArmory or {}
SCPArmory.ItemIcons = SCPArmory.ItemIcons or {} -- "pool/id" -> URL image
SCPArmory.ItemJobs = SCPArmory.ItemJobs or {}   -- "pool/id" -> { "Job", ... }

-- Applique aux objets les icônes et restrictions de jobs configurées
-- (y compris pour les armes auto-chargées après coup)
function SCPArmory.ApplyPendingItemConfig()
	for key, url in pairs(SCPArmory.ItemIcons) do
		local pool, id = string.match(key, "^([%w_]+)/([%w_]+)$")
		local item = pool and SCPArmory.GetItem(pool, id)
		if item then item.icon = url end
	end

	for key, jobs in pairs(SCPArmory.ItemJobs) do
		local pool, id = string.match(key, "^([%w_]+)/([%w_]+)$")
		local item = pool and SCPArmory.GetItem(pool, id)
		if item then
			item.jobs = (istable(jobs) and #jobs > 0) and jobs or nil
		end
	end
end

local function PoolHasClass(pool, class)
	for _, item in ipairs(SCPArmory.Items[pool]) do
		if item.class == class then return true end
	end
	return false
end

function SCPArmory.AutoLoadWeapons()
	if not SCPArmory.Config.AutoLoadWeapons then
		SCPArmory.ApplyPendingItemConfig()
		return
	end

	local blacklist = {}
	for _, class in ipairs(SCPArmory.Config.AutoLoadBlacklist or {}) do
		blacklist[class] = true
	end

	local added = { primary = {}, secondary = {} }

	for _, swep in ipairs(weapons.GetList()) do
		local class = swep.ClassName

		if isstring(class) and not blacklist[class]
			and swep.Spawnable and not swep.AdminOnly
			and isstring(swep.PrintName) and swep.PrintName ~= "" then

			-- Emplacement HL2 : 1 = armes de poing, 2/3 = PM, fusils, snipers
			local slot = tonumber(swep.Slot)
			local pool = nil
			if slot == 1 then
				pool = "secondary"
			elseif slot == 2 or slot == 3 then
				pool = "primary"
			end

			if pool and not PoolHasClass(pool, class) and not SCPArmory.GetItem(pool, class) then
				local ammoType = istable(swep.Primary) and swep.Primary.Ammo or nil
				if not isstring(ammoType) or ammoType == "" or string.lower(ammoType) == "none" then
					ammoType = nil
				end

				table.insert(added[pool], {
					id = class,
					name = tostring(swep.PrintName),
					desc = tostring(swep.Purpose or ""),
					weight = (pool == "primary") and 3.0 or 1.0,
					class = class,
					model = isstring(swep.WorldModel) and swep.WorldModel ~= "" and swep.WorldModel or nil,
					ammo = ammoType and { { type = ammoType, amount = (pool == "primary") and 120 or 60 } } or nil,
				})
			end
		end
	end

	for pool, list in pairs(added) do
		table.sort(list, function(a, b)
			if a.name == b.name then return a.id < b.id end
			return a.name < b.name
		end)
		for _, item in ipairs(list) do
			table.insert(SCPArmory.Items[pool], item)
		end
	end

	SCPArmory.ApplyPendingItemConfig()
end

hook.Add("InitPostEntity", "SCPArmory_AutoLoad", SCPArmory.AutoLoadWeapons)
