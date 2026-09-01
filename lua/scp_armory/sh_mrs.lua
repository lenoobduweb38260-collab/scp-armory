-- SCP Armory — pont MRS (Advanced Rank System, partagé)
-- Permet de restreindre un objet par grade MRS : « catégorie:indice du
-- grade » (ex. "NYPD:3"). La table MRS.Ranks est synchronisée aux clients
-- par MRS lui-même ; tout est protégé par vérifications — l'armurerie
-- fonctionne sans MRS (les restrictions par grade sont alors ignorées à
-- la configuration et ne laissent rien passer au déploiement).

SCPArmory = SCPArmory or {}
SCPArmory.MRSBridge = SCPArmory.MRSBridge or {}
local Bridge = SCPArmory.MRSBridge

function Bridge.Installed()
	return istable(MRS) and istable(MRS.Ranks)
end

-- Liste plate des grades pour la config, triée par catégorie puis grade :
-- { { id = "catégorie:indice", label = "CATÉGORIE — GRADE" }, ... }
function Bridge.RankOptions()
	if not Bridge.Installed() then return {} end

	local out = {}
	for gid, grp in SortedPairs(MRS.Ranks) do
		if istable(grp) and istable(grp.ranks) then
			local gname = SCPArmory.FrUpper(tostring(grp.id or gid))
			for i, rank in ipairs(grp.ranks) do
				local rname = istable(rank) and tostring(rank.name or i) or tostring(i)
				table.insert(out, {
					id = tostring(gid) .. ":" .. i,
					label = gname .. " — " .. SCPArmory.FrUpper(rname),
				})
			end
		end
	end
	return out
end

-- Libellé lisible d'un id de grade (pour les résumés de la config)
function Bridge.RankLabel(id)
	local gid, idx = string.match(tostring(id), "^(.*):(%d+)$")
	if gid and Bridge.Installed() then
		local grp = MRS.Ranks[gid]
		local rank = istable(grp) and istable(grp.ranks) and grp.ranks[tonumber(idx)]
		if istable(rank) then
			return SCPArmory.FrUpper(tostring(grp.id or gid)) .. " — " .. SCPArmory.FrUpper(tostring(rank.name or idx))
		end
	end
	return tostring(id)
end

-- Le joueur occupe-t-il exactement ce grade (catégorie ET indice) ?
-- Les données MRSdata sont posées par MRS côté serveur et synchronisées
-- aux clients : la même vérification vaut des deux côtés.
function Bridge.PlayerHasRank(ply, id)
	if not Bridge.Installed() or not IsValid(ply) then return false end

	local gid, idx = string.match(tostring(id), "^(.*):(%d+)$")
	if not gid then return false end

	local data = ply.MRSdata
	if not istable(data) then return false end

	return tostring(data.Group) == gid and tonumber(data.Rank) == tonumber(idx)
end
