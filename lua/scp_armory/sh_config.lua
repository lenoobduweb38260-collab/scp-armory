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
	local grp = ply:GetUserGroup()
	return SCPArmory.Config.ClearanceGroups[grp] or SCPArmory.Config.DefaultClearance
end
