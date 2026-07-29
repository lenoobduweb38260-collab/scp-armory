-- SCP Armory — configuration partagée

SCPArmory = SCPArmory or {}

SCPArmory.Config = {
	-- Commandes chat qui ouvrent l'armurerie (le message est masqué du chat)
	ChatCommands = { "!armurerie", "!loadout", "!armory" },

	-- Niveau d'accréditation par défaut (1-4). Les objets anormaux demandent le niveau 4.
	DefaultClearance = 3,

	-- Accréditation par groupe d'utilisateurs (prioritaire sur DefaultClearance)
	ClearanceGroups = {
		superadmin = 4,
		admin      = 4,
	},

	-- Accréditation par job/team (prioritaire sur ClearanceGroups) — nom exact du job
	-- Exemple DarkRP : ["Chef des FGM"] = 4, ["Agent de sécurité"] = 2
	ClearanceJobs = {},

	-- Si true, le menu et le déploiement ne fonctionnent qu'à proximité
	-- d'un casier d'armurerie (entité scp_armory_locker), comme dans Ready or Not
	RequireEntity = false,

	-- Distance maximale (unités) au casier pour s'équiper quand RequireEntity = true
	UseDistance = 160,

	-- Vitesses de base sur lesquelles s'applique le multiplicateur de mobilité
	BaseWalkSpeed = 200,
	BaseRunSpeed  = 400,

	-- Armure maximale applicable
	MaxArmor = 100,

	-- Armes conservées / redonnées après un déploiement (outils sandbox)
	KeepWeapons = {
		"weapon_physgun",
		"weapon_physcannon",
		"gmod_tool",
		"gmod_camera",
	},
}

-- Accréditation effective d'un joueur (fonction partagée : utilisée par le menu et le serveur)
function SCPArmory.GetClearance(ply)
	if not IsValid(ply) then return 1 end

	local jobClearance = SCPArmory.Config.ClearanceJobs[team.GetName(ply:Team())]
	if jobClearance then return jobClearance end

	return SCPArmory.Config.ClearanceGroups[ply:GetUserGroup()] or SCPArmory.Config.DefaultClearance
end

-- Un objet réservé à certains jobs (champ item.jobs) est totalement invisible
-- pour les autres, comme dans Ready or Not : on ne voit que son arsenal.
function SCPArmory.IsItemAvailable(ply, item)
	if not item.jobs then return true end
	if not IsValid(ply) then return false end

	local jobName = team.GetName(ply:Team())
	for _, job in ipairs(item.jobs) do
		if job == jobName then return true end
	end
	return false
end
