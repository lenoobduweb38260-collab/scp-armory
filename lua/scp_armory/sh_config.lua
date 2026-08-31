-- SCP Armory — configuration partagée
-- Ces valeurs sont les défauts : le panneau en jeu (scp_armory_config,
-- superadmin) les écrase et les sauvegarde côté serveur.

SCPArmory = SCPArmory or {}

SCPArmory.Config = {
	-- Commandes chat qui ouvrent l'armurerie (le message est masqué du chat)
	ChatCommands = { "!armurerie", "!loadout", "!armory" },

	-- Commandes chat qui ouvrent le panneau de configuration (superadmin)
	ConfigChatCommands = { "!armurerieconfig", "!armoryconfig", "!configarmurerie" },

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

	-- Si true, le menu et le déploiement ne fonctionnent qu'à proximité
	-- d'une armoire d'armurerie (entité scp_armory_locker), comme dans Ready or Not
	RequireEntity = false,

	-- Distance maximale (unités) à l'armoire pour s'équiper quand RequireEntity = true
	UseDistance = 160,

	-- Modèle de l'armoire d'armurerie (entité scp_armory_locker)
	LockerModel = "models/props_c17/FurnitureDrawer001a.mdl",

	-- Hauteur de l'étiquette 3D2D au-dessus de l'armoire
	LockerLabelHeight = 58,

	-- Bloque le menu de personnalisation ARC9 (touche C) : les accessoires
	-- ne se choisissent que via l'armurerie
	BlockARC9Customize = true,

	-- Distance de la caméra sur l'opérateur dans le menu (plus grand = plus loin)
	PreviewDistance = 120,

	-- Décor 3D dans l'aperçu du menu : armoires et caisses derrière
	-- l'opérateur, caisse d'armes sous l'arme en personnalisation
	MenuScene = true,

	-- Langue de l'interface : "fr", "de" ou "pl" (choix dans la config en jeu)
	Language = "fr",

	-- Style de l'interface (choix dans la config en jeu) :
	-- "ron" = Ready or Not épuré et plat (défaut),
	-- "mw"  = Modern Warfare : sélection en grandes cartes façon killstreaks
	UITheme = "ron",

	-- Fonds personnalisés du menu : URL directe (https) de VOTRE image,
	-- affichée telle quelle. Un fond par lieu (écran opérateur / écran de
	-- modification d'arme) et par style d'interface (vide = fond livré).
	MenuBGRonURL       = "", -- Ready or Not — écran opérateur (loadout)
	MenuBGRonWeaponURL = "", -- Ready or Not — écran modification d'arme
	MenuBGMwURL        = "", -- Modern Warfare — écran des cartes
	MenuBGMwWeaponURL  = "", -- Modern Warfare — écran modification d'arme

	-- Couleur d'accent de l'interface, appliquée partout dans les menus
	-- (rouge Fondation par défaut ; réglable dans la config en jeu)
	UIColorR = 190,
	UIColorG = 34,
	UIColorB = 28,

	-- Séquence de pose de l'opérateur dans le menu (bras croisés si dispo)
	PreviewPose = "pose_standing_02",

	-- Commandes chat qui ouvrent le menu d'apparence (bodygroups)
	BGChatCommands = { "!apparence", "!bodygroups" },

	-- Journalisation serveur : fichiers datés dans data/scp_armory/logs/
	LogToFile = true,

	-- Journalisation dans la console serveur
	LogToConsole = true,

	-- Durée de conservation des fichiers de logs (jours, 0 = illimité)
	LogRetentionDays = 14,

	-- Charge automatiquement les armes des packs installés (ARC9, M9K…)
	-- dans les pools principale/secondaire selon leur emplacement d'arme
	AutoLoadWeapons = true,

	-- Classes d'armes à ignorer lors du chargement automatique
	AutoLoadBlacklist = {},

	-- Packs d'armes supplémentaires (MRS…) : préfixes de classes, séparés
	-- par des virgules, chargés dans les pools même si le pack ne marque pas
	-- ses armes comme spawnables (pris en compte au prochain redémarrage)
	ForceLoadPrefixes = "mrs_",
}

-- Majuscules compatibles avec les accents français (string.upper les ignore)
local ACCENTS = {
	["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["ë"] = "Ë",
	["à"] = "À", ["â"] = "Â", ["ä"] = "Ä",
	["î"] = "Î", ["ï"] = "Ï",
	["ô"] = "Ô", ["ö"] = "Ö",
	["ù"] = "Ù", ["û"] = "Û", ["ü"] = "Ü",
	["ç"] = "Ç", ["œ"] = "Œ",
}

-- Mémoïsé : appelé dans les Paint à chaque frame, le gsub ne doit tourner
-- qu'une fois par chaîne distincte
local upperCache = {}
local upperCount = 0

function SCPArmory.FrUpper(s)
	s = tostring(s or "")
	local hit = upperCache[s]
	if hit then return hit end

	local out = string.upper(s)
	for l, u in pairs(ACCENTS) do
		out = string.gsub(out, l, u)
	end

	if upperCount > 2048 then
		upperCache = {}
		upperCount = 0
	end
	upperCache[s] = out
	upperCount = upperCount + 1

	return out
end

-- Couleur d'accent configurée, bornée — utilisée par tous les panneaux
function SCPArmory.AccentColor()
	local c = SCPArmory.Config
	return math.Clamp(math.floor(tonumber(c.UIColorR) or 190), 0, 255),
		math.Clamp(math.floor(tonumber(c.UIColorG) or 34), 0, 255),
		math.Clamp(math.floor(tonumber(c.UIColorB) or 28), 0, 255)
end

-- Bodygroups des playermodels que les joueurs ont le droit de modifier
-- (noms en minuscules, cochés dans le panneau de configuration en jeu)
SCPArmory.AllowedBodygroups = SCPArmory.AllowedBodygroups or {}

-- Un objet réservé à certains jobs (champ item.jobs) est totalement invisible
-- pour les autres, comme dans Ready or Not : on ne voit que son arsenal.
--
-- Cas particuliers :
--   - une ARME (pools principale/secondaire, champ isWeapon) sans métier
--     assigné n'est donnée à PERSONNE — c'est le défaut : assignez les
--     métiers (ou TOUS) dans la config en jeu pour la rendre disponible ;
--   - l'entrée "*" dans item.jobs = tous les métiers.
function SCPArmory.IsItemAvailable(ply, item)
	if not item.jobs then
		return not item.isWeapon
	end
	if not IsValid(ply) then return false end

	local jobName = team.GetName(ply:Team())
	for _, job in ipairs(item.jobs) do
		if job == "*" or job == jobName then return true end
	end
	return false
end
