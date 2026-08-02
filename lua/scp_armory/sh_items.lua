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
--   bodygroups : { ["nom_du_bodygroup"] = valeur } (optionnel — gilets/casques) :
--               force ces bodygroups sur le playermodel quand l'objet est
--               équipé ; sans ce champ, une heuristique active les bodygroups
--               nommés vest/armor/gilet (gilet) ou helmet/casque/hat (casque)
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
	-- Les armes de base HL2/GMod sont volontairement exclues des pools
	-- principale/secondaire : ils sont remplis par le chargement automatique
	-- des packs installés (ARC9, M9K…) via sh_autoload.lua.
	primary = {
		NONE("— Sans arme principale —"),
	},

	secondary = {
		NONE("— Sans arme secondaire —"),
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
		primary   = "none",
		secondary = "none",
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

-- Reflète le gilet et le casque équipés sur un modèle (joueur en jeu ou
-- aperçu du menu) via ses bodygroups, quand le playermodel en possède.
function SCPArmory.ApplyBodygroups(ent, loadout)
	if not IsValid(ent) then return end
	local groups = ent:GetBodyGroups()
	if not istable(groups) then return end

	local wantVest = loadout.armor ~= nil and loadout.armor ~= "none"
	local wantHelmet = loadout.helmet ~= nil and loadout.helmet ~= "none"

	-- Valeurs explicites définies sur les objets équipés (item.bodygroups)
	local explicit = {}
	for _, slotKey in ipairs({ "armor", "helmet" }) do
		local item = SCPArmory.GetItem(slotKey, loadout[slotKey])
		if item and istable(item.bodygroups) then
			for bgName, val in pairs(item.bodygroups) do
				explicit[string.lower(tostring(bgName))] = tonumber(val) or 0
			end
		end
	end

	for _, bg in ipairs(groups) do
		local name = string.lower(tostring(bg.name or ""))
		local count = tonumber(bg.num) or 0

		if explicit[name] ~= nil then
			ent:SetBodygroup(bg.id, math.Clamp(explicit[name], 0, math.max(count - 1, 0)))
		elseif count > 1 then
			if string.find(name, "vest", 1, true) or string.find(name, "armor", 1, true)
				or string.find(name, "armour", 1, true) or string.find(name, "gilet", 1, true) then
				ent:SetBodygroup(bg.id, wantVest and (count - 1) or 0)
			elseif string.find(name, "helmet", 1, true) or string.find(name, "casque", 1, true)
				or string.find(name, "headgear", 1, true) or string.find(name, "hat", 1, true) then
				ent:SetBodygroup(bg.id, wantHelmet and (count - 1) or 0)
			end
		end
	end
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
