-- SCP Armory — journalisation serveur
-- Fichiers datés dans data/scp_armory/logs/, sortie console, rotation
-- automatique, et diffusion vers les systèmes de logs du staff :
--   * hook universel : hook.Add("SCPArmory_Log", ...) — catégorie, message, joueur
--   * intégrations best-effort détectées à chaud (bLogs, mLogs), protégées
--     par pcall : si l'API diffère, les logs fichier/console restent intacts.

local LOG_DIR = "scp_armory/logs"

function SCPArmory.PlayerTag(ply)
	if not IsValid(ply) then return "console" end
	return string.format("%s (%s)", ply:Nick(), ply:SteamID() or "?")
end

local function WriteFileLog(line)
	if SCPArmory.Config.LogToFile == false then return end
	file.CreateDir(LOG_DIR)
	file.Append(LOG_DIR .. "/" .. os.date("%Y-%m-%d") .. ".txt", line .. "\n")
end

function SCPArmory.AddLog(category, message, ply)
	local line = string.format("[%s] [%s] %s", os.date("%H:%M:%S"), category, message)

	if SCPArmory.Config.LogToConsole ~= false then
		MsgC(Color(190, 34, 28), "[SCP Armory] ", Color(235, 235, 235), line .. "\n")
	end

	WriteFileLog(line)

	-- Hook universel : n'importe quel système de logs peut s'y brancher
	hook.Run("SCPArmory_Log", category, message, ply)

	-- bLogs (Billy's Logs) — détection de l'API disponible
	if istable(bLogs) then
		local fn = bLogs.AddLog or bLogs.Log or bLogs.NewLog
		if isfunction(fn) then
			pcall(fn, bLogs, "SCP Armory", "[" .. category .. "] " .. message)
		end
	end

	-- mLogs
	if istable(mLogs) and isfunction(mLogs.log) then
		pcall(mLogs.log, "scparmory", "event", {
			cat = category,
			msg = message,
			ply = IsValid(ply) and (ply:SteamID64() or ply:SteamID()) or nil,
		})
	end
end

-- Rotation : purge des fichiers plus vieux que LogRetentionDays jours
hook.Add("Initialize", "SCPArmory_LogPrune", function()
	local days = tonumber(SCPArmory.Config.LogRetentionDays) or 14
	if days <= 0 then return end

	local files = file.Find(LOG_DIR .. "/*.txt", "DATA") or {}
	local cutoff = os.time() - days * 86400

	for _, fname in ipairs(files) do
		local y, m, d = string.match(fname, "^(%d%d%d%d)%-(%d%d)%-(%d%d)%.txt$")
		if y then
			local t = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
			if t and t < cutoff then
				file.Delete(LOG_DIR .. "/" .. fname)
			end
		end
	end
end)
