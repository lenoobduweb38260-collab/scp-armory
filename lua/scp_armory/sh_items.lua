-- SCP Armory — base de données d'équipement (partagée client/serveur)
--
-- Chaque objet :
--   id        : identifiant unique dans son pool
--   name      : nom affiché
--   desc      : description (menu)
--   weight    : poids en kg (influence la mobilité)
--   clearance : niveau d'accréditation requis (1-4)
--   class     : classe d'arme à donner (optionnel — armes uniquement)
--   model     : modèle pour l'icône du menu (optionnel)
--   ammo      : { { type = "SMG1", amount = 90 }, ... } (optionnel)
--   armor     : points d'armure apportés (optionnel)
--   resist    : résistance aux dégâts, 0-1 (optionnel — objets anormaux)
--   mobilityMod : bonus/malus direct de mobilité (optionnel)
--   stats     : { degats, cadence, controle, precision } sur 100 (affichage)
--   apply     : function(ply) effet spécial au déploiement (optionnel, serveur)
--   jobs      : { "Nom exact du job", ... } (optionnel) — l'objet n'existe QUE
--               pour ces jobs/teams : les autres joueurs ne le voient même pas
--               dans le menu, façon Ready or Not. Sans ce champ : tous les jobs.
--               Exemple : jobs = { "Chef des FGM", "Opérateur Epsilon-11" }

SCPArmory = SCPArmory or {}

local NONE = function(label)
	return { id = "none", name = label or "— Aucun —", desc = "Emplacement laissé vide pour alléger le chargement.", weight = 0, clearance = 1 }
end

SCPArmory.Items = {
	primary = {
		NONE("— Sans arme principale —"),
		{
			id = "smg", name = "PM « Éclaireur-9 »",
			desc = "Pistolet-mitrailleur standard des FGM. Polyvalent, contrôlable, idéal en espace confiné.",
			weight = 3.1, clearance = 1,
			class = "weapon_smg1", model = "models/weapons/w_smg1.mdl",
			ammo = { { type = "SMG1", amount = 135 }, { type = "SMG1_Grenade", amount = 1 } },
			stats = { degats = 55, cadence = 82, controle = 74, precision = 60 },
		},
		{
			id = "ar2", name = "Fusil à impulsions « Suppression »",
			desc = "Fusil d'assaut à énergie dirigée. Puissance de feu élevée pour les brèches de confinement majeures.",
			weight = 3.8, clearance = 2,
			class = "weapon_ar2", model = "models/weapons/w_irifle.mdl",
			ammo = { { type = "AR2", amount = 90 }, { type = "AR2AltFire", amount = 1 } },
			stats = { degats = 72, cadence = 70, controle = 58, precision = 76 },
		},
		{
			id = "shotgun", name = "Fusil à pompe « Brèche »",
			desc = "Calibre 12 de dotation. Dévastateur à courte portée, ouverture de portes récalcitrantes incluse.",
			weight = 3.6, clearance = 2,
			class = "weapon_shotgun", model = "models/weapons/w_shotgun.mdl",
			ammo = { { type = "Buckshot", amount = 32 } },
			stats = { degats = 92, cadence = 24, controle = 44, precision = 35 },
		},
		{
			id = "crossbow", name = "Arbalète thermique « Vigie »",
			desc = "Carreaux surchauffés, silencieuse et chirurgicale. Pour neutraliser sans alerter tout le site.",
			weight = 4.2, clearance = 3,
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
			weight = 0.9, clearance = 1,
			class = "weapon_pistol", model = "models/weapons/w_pistol.mdl",
			ammo = { { type = "Pistol", amount = 90 } },
			stats = { degats = 40, cadence = 58, controle = 86, precision = 58 },
		},
		{
			id = "revolver", name = "Revolver .357 « Dernier Recours »",
			desc = "Six chambres, zéro compromis. Quand la procédure de confinement a déjà échoué.",
			weight = 1.2, clearance = 2,
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
			weight = 1.8, clearance = 1,
			class = "weapon_medkit", model = "models/items/healthkit.mdl",
		},
		{
			id = "stunstick", name = "Matraque électrique",
			desc = "Neutralisation non létale du personnel de Classe-D récalcitrant. Décharge calibrée.",
			weight = 1.0, clearance = 1,
			class = "weapon_stunstick", model = "models/weapons/w_stunbaton.mdl",
		},
		{
			id = "breach", name = "Outil de brèche",
			desc = "Levier renforcé pour forcer les accès condamnés. Rustique mais approuvé par la logistique.",
			weight = 2.3, clearance = 1,
			class = "weapon_crowbar", model = "models/weapons/w_crowbar.mdl",
		},
	},

	grenade = {
		NONE(),
		{
			id = "frag", name = "Grenades à fragmentation ×3",
			desc = "Dotation offensive standard. À n'employer qu'en zone déjà compromise.",
			weight = 1.4, clearance = 2,
			class = "weapon_frag", model = "models/weapons/w_grenade.mdl",
			ammo = { { type = "Grenade", amount = 3 } },
		},
		{
			id = "slam", name = "Charges SLAM ×3",
			desc = "Mines magnétiques à déclenchement laser. Verrouillage de couloir pendant un repli.",
			weight = 1.6, clearance = 3,
			class = "weapon_slam", model = "models/weapons/w_slam.mdl",
			ammo = { { type = "slam", amount = 3 } },
		},
	},

	armor = {
		{ id = "none", name = "Sans gilet", desc = "Mobilité maximale, protection nulle. Déconseillé au-delà de la Zone d'Entrée.", weight = 0, clearance = 1 },
		{
			id = "light", name = "Gilet léger (Kevlar)",
			desc = "Protection souple contre les armes de poing. Le standard des patrouilles de site.",
			weight = 4.5, clearance = 1, armor = 25,
			model = "models/items/battery.mdl",
		},
		{
			id = "ceramic", name = "Plaques céramique",
			desc = "Plaques rigides multi-impacts. Bon compromis masse/protection pour les interventions.",
			weight = 8.0, clearance = 2, armor = 50,
			model = "models/items/battery.mdl",
		},
		{
			id = "heavy", name = "Blindage lourd d'intervention",
			desc = "Protection intégrale niveau IV. Vous encaisserez — mais vous ne courrez plus.",
			weight = 12.0, clearance = 3, armor = 100,
			model = "models/items/battery.mdl",
		},
	},

	helmet = {
		{ id = "none", name = "Sans casque", desc = "Béret d'opérateur. Élégant, strictement décoratif.", weight = 0, clearance = 1 },
		{
			id = "fast", name = "Casque balistique FAST",
			desc = "Coque légère avec rail d'accessoires. Protège des éclats et des chutes de plafond.",
			weight = 1.4, clearance = 1, armor = 10,
		},
		{
			id = "riot", name = "Casque anti-émeute à visière",
			desc = "Visière intégrale en polycarbonate. Recommandé face aux humanoïdes hostiles de Classe Euclide.",
			weight = 2.3, clearance = 2, armor = 20,
		},
		{
			id = "nbc", name = "Masque NBC intégral",
			desc = "Filtration nucléaire, biologique, chimique. Obligatoire en cas de brèche de SCP-008.",
			weight = 2.8, clearance = 3, armor = 15,
		},
	},

	anomaly = {
		{ id = "none", name = "Aucun objet anormal", desc = "Aucune autorisation d'emport anormal demandée pour cette opération.", weight = 0, clearance = 1 },
		{
			id = "scp500", name = "SCP-500-1 (dose unique)",
			desc = "Panacée. Une pilule rouge guérissant toute affection. Consommée au déploiement : restaure l'intégralité des points de vie.",
			weight = 0.1, clearance = 4,
			model = "models/props_lab/jar01a.mdl",
			apply = function(ply) ply:SetHealth(ply:GetMaxHealth()) end,
		},
		{
			id = "scp714", name = "SCP-714 — Bague de jade",
			desc = "Protège l'esprit et le corps des influences anormales (-25 % de dégâts subis), au prix d'une fatigue constante (mobilité réduite).",
			weight = 0.1, clearance = 4,
			resist = 0.25, mobilityMod = -15,
		},
		{
			id = "sra", name = "Ancre de Réalité Scranton portative",
			desc = "Stabilise la réalité locale autour du porteur (-15 % de dégâts subis). Encombrante : l'humilité pèse 6,5 kg.",
			weight = 6.5, clearance = 4,
			resist = 0.15,
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
	{ key = "anomaly",   pool = "anomaly",   label = "OBJET ANORMAL" },
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
		anomaly   = "none",
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
	local weight, armor, resist, mobilityMod = 0, 0, 0, 0

	for _, slot in ipairs(SCPArmory.Slots) do
		local id = loadout[slot.key]
		if id and id ~= "none" then
			local item = SCPArmory.GetItem(slot.pool, id)
			if item then
				weight = weight + (item.weight or 0)
				armor = armor + (item.armor or 0)
				resist = resist + (item.resist or 0)
				mobilityMod = mobilityMod + (item.mobilityMod or 0)
			end
		end
	end

	local mobility = SCPArmory.GetMobility(weight, mobilityMod)

	return {
		weight   = math.Round(weight * 10) / 10,
		armor    = math.min(armor, SCPArmory.Config.MaxArmor),
		resist   = math.min(resist, 0.5),
		mobility = mobility,
		class    = SCPArmory.GetWeightClass(mobility),
	}
end
