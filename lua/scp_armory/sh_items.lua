-- SCP Armory — base de données d'équipement (partagée client/serveur)
--
-- Chaque objet :
--   id        : identifiant unique dans son pool
--   name      : nom affiché
--   desc      : description (menu)
--   weight    : poids en kg (influence la mobilité)
--   class     : classe d'arme à donner (optionnel — armes uniquement)
--   model     : modèle pour l'icône du menu (optionnel)
--   icon      : URL d'image directe imgur (https://i.imgur.com/xxxx.png) —
--               remplace le rendu 3D dans le menu ; configurable en jeu via
--               le panneau superadmin (scp_armory_config)
--   ammo      : { { type = "SMG1", amount = 90 }, ... } (optionnel)
--   armor     : points d'armure apportés (optionnel)
--   mobilityMod : bonus/malus direct de mobilité (optionnel)
--   stats     : { degats, cadence, controle, precision } sur 100 (affichage)
--   jobs      : { "Nom exact du job", ... } (optionnel) — l'objet n'existe QUE
--               pour ces jobs/teams : les autres joueurs ne le voient même pas
--               dans le menu, façon Ready or Not. Sans ce champ : tous les jobs.
--               Configurable en jeu via le panneau superadmin.
--
-- Les armes des packs installés (ARC9, M9K…) sont ajoutées automatiquement
-- aux pools primary/secondary par sh_autoload.lua (config AutoLoadWeapons).

SCPArmory = SCPArmory or {}

local NONE = function(label)
	return { id = "none", name = label or "— Aucun —", desc = "Emplacement laissé vide pour alléger le chargement.", weight = 0 }
end

SCPArmory.Items = {
	primary = {
		NONE("— Sans arme principale —"),
		{
			id = "smg", name = "PM « Éclaireur-9 »",
			desc = "Pistolet-mitrailleur standard des FGM. Polyvalent, contrôlable, idéal en espace confiné.",
			weight = 3.1,
			class = "weapon_smg1", model = "models/weapons/w_smg1.mdl",
			ammo = { { type = "SMG1", amount = 135 }, { type = "SMG1_Grenade", amount = 1 } },
			stats = { degats = 55, cadence = 82, controle = 74, precision = 60 },
		},
		{
			id = "ar2", name = "Fusil à impulsions « Suppression »",
			desc = "Fusil d'assaut à énergie dirigée. Puissance de feu élevée pour les brèches de confinement majeures.",
			weight = 3.8,
			class = "weapon_ar2", model = "models/weapons/w_irifle.mdl",
			ammo = { { type = "AR2", amount = 90 }, { type = "AR2AltFire", amount = 1 } },
			stats = { degats = 72, cadence = 70, controle = 58, precision = 76 },
		},
		{
			id = "shotgun", name = "Fusil à pompe « Brèche »",
			desc = "Calibre 12 de dotation. Dévastateur à courte portée, ouverture de portes récalcitrantes incluse.",
			weight = 3.6,
			class = "weapon_shotgun", model = "models/weapons/w_shotgun.mdl",
			ammo = { { type = "Buckshot", amount = 32 } },
			stats = { degats = 92, cadence = 24, controle = 44, precision = 35 },
		},
		{
			id = "crossbow", name = "Arbalète thermique « Vigie »",
			desc = "Carreaux surchauffés, silencieuse et chirurgicale. Pour neutraliser sans alerter tout le site.",
			weight = 4.2,
			class = "weapon_crossbow", model = "models/weapons/w_crossbow.mdl",
			ammo = { { type = "XBowBolt", amount = 10 } },
			stats = { degats = 95, cadence = 12, controle = 38, precision = 96 },
		},
	},

	secondary = {
		NONE("— Sans arme secondaire —"),
		{
			id = "pistol", name = "Pistolet de service 9 mm",
			desc = "Arme de poing réglementaire de la Fondation. Fiable, légère, toujours à portée de main.",
			weight = 0.9,
			class = "weapon_pistol", model = "models/weapons/w_pistol.mdl",
			ammo = { { type = "Pistol", amount = 90 } },
			stats = { degats = 40, cadence = 58, controle = 86, precision = 58 },
		},
		{
			id = "revolver", name = "Revolver .357 « Dernier Recours »",
			desc = "Six chambres, zéro compromis. Quand la procédure de confinement a déjà échoué.",
			weight = 1.2,
			class = "weapon_357", model = "models/weapons/w_357.mdl",
			ammo = { { type = "357", amount = 24 } },
			stats = { degats = 75, cadence = 22, controle = 52, precision = 66 },
		},
	},

	tactical = {
		NONE(),
		{
			id = "medkit", name = "Kit médical de terrain",
			desc = "Trousse de premiers soins. Stabilise les blessures en attendant l'évacuation médicale.",
			weight = 1.8,
			class = "weapon_medkit", model = "models/items/healthkit.mdl",
		},
		{
			id = "stunstick", name = "Matraque électrique",
			desc = "Neutralisation non létale du personnel de Classe-D récalcitrant. Décharge calibrée.",
			weight = 1.0,
			class = "weapon_stunstick", model = "models/weapons/w_stunbaton.mdl",
		},
		{
			id = "breach", name = "Outil de brèche",
			desc = "Levier renforcé pour forcer les accès condamnés. Rustique mais approuvé par la logistique.",
			weight = 2.3,
			class = "weapon_crowbar", model = "models/weapons/w_crowbar.mdl",
		},
	},

	grenade = {
		NONE(),
		{
			id = "frag", name = "Grenades à fragmentation ×3",
			desc = "Dotation offensive standard. À n'employer qu'en zone déjà compromise.",
			weight = 1.4,
			class = "weapon_frag", model = "models/weapons/w_grenade.mdl",
			ammo = { { type = "Grenade", amount = 3 } },
		},
		{
			id = "slam", name = "Charges SLAM ×3",
			desc = "Mines magnétiques à déclenchement laser. Verrouillage de couloir pendant un repli.",
			weight = 1.6,
			class = "weapon_slam", model = "models/weapons/w_slam.mdl",
			ammo = { { type = "slam", amount = 3 } },
		},
	},

	armor = {
		{ id = "none", name = "Sans gilet", desc = "Mobilité maximale, protection nulle. Déconseillé au-delà de la Zone d'Entrée.", weight = 0 },
		{
			id = "light", name = "Gilet léger (Kevlar)",
			desc = "Protection souple contre les armes de poing. Le standard des patrouilles de site.",
			weight = 4.5, armor = 25,
			model = "models/items/battery.mdl",
		},
		{
			id = "ceramic", name = "Plaques céramique",
			desc = "Plaques rigides multi-impacts. Bon compromis masse/protection pour les interventions.",
			weight = 8.0, armor = 50,
			model = "models/items/battery.mdl",
		},
		{
			id = "heavy", name = "Blindage lourd d'intervention",
			desc = "Protection intégrale niveau IV. Vous encaisserez — mais vous ne courrez plus.",
			weight = 12.0, armor = 100,
			model = "models/items/battery.mdl",
		},
	},

	helmet = {
		{ id = "none", name = "Sans casque", desc = "Béret d'opérateur. Élégant, strictement décoratif.", weight = 0 },
		{
			id = "fast", name = "Casque balistique FAST",
			desc = "Coque légère avec rail d'accessoires. Protège des éclats et des chutes de plafond.",
			weight = 1.4, armor = 10,
		},
		{
			id = "riot", name = "Casque anti-émeute à visière",
			desc = "Visière intégrale en polycarbonate. Recommandé face aux humanoïdes hostiles de Classe Euclide.",
			weight = 2.3, armor = 20,
		},
		{
			id = "nbc", name = "Masque NBC intégral",
			desc = "Filtration nucléaire, biologique, chimique. Obligatoire en cas de brèche de SCP-008.",
			weight = 2.8, armor = 15,
		},
	},
}

-- Emplacements du loadout, dans l'ordre (l'ordre sert aussi au protocole réseau)
SCPArmory.Slots = {
	{ key = "primary",   pool = "primary",   label = "ARME PRINCIPALE" },
	{ key = "secondary", pool = "secondary", label = "ARME SECONDAIRE" },
	{ key = "tactical1", pool = "tactical",  label = "TACTIQUE I" },
	{ key = "tactical2", pool = "tactical",  label = "TACTIQUE II" },
	{ key = "grenade",   pool = "grenade",   label = "GRENADE" },
	{ key = "armor",     pool = "armor",     label = "GILET BALISTIQUE" },
	{ key = "helmet",    pool = "helmet",    label = "CASQUE" },
}

-- Loadout proposé par défaut
function SCPArmory.DefaultLoadout()
	return {
		primary   = "smg",
		secondary = "pistol",
		tactical1 = "medkit",
		tactical2 = "none",
		grenade   = "frag",
		armor     = "light",
		helmet    = "fast",
	}
end

-- Recherche d'un objet par pool + id
function SCPArmory.GetItem(pool, id)
	local items = SCPArmory.Items[pool]
	if not items then return nil end
	for _, item in ipairs(items) do
		if item.id == id then return item end
	end
	return nil
end

-- Mobilité (0-110) déduite du poids total et des modificateurs
function SCPArmory.GetMobility(weight, mobilityMod)
	return math.Clamp(math.Round(115 - weight * 3 + (mobilityMod or 0)), 40, 110)
end

-- Classe de chargement façon Ready or Not
function SCPArmory.GetWeightClass(mobility)
	if mobility >= 90 then return "LÉGER" end
	if mobility >= 65 then return "INTERMÉDIAIRE" end
	return "LOURD"
end

-- Statistiques agrégées d'un loadout { slotKey = itemId }
function SCPArmory.ComputeStats(loadout)
	local weight, armor, mobilityMod = 0, 0, 0

	for _, slot in ipairs(SCPArmory.Slots) do
		local id = loadout[slot.key]
		if id and id ~= "none" then
			local item = SCPArmory.GetItem(slot.pool, id)
			if item then
				weight = weight + (item.weight or 0)
				armor = armor + (item.armor or 0)
				mobilityMod = mobilityMod + (item.mobilityMod or 0)
			end
		end
	end

	local mobility = SCPArmory.GetMobility(weight, mobilityMod)

	return {
		weight   = math.Round(weight * 10) / 10,
		armor    = math.min(armor, SCPArmory.Config.MaxArmor),
		mobility = mobility,
		class    = SCPArmory.GetWeightClass(mobility),
	}
end
