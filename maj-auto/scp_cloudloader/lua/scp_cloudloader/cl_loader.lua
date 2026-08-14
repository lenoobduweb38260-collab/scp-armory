-- SCP Cloud Loader — client
--
-- À la connexion : demande le manifeste au serveur, télécharge les fichiers
-- manquants (cache data/scp_cloudloader/, donc instantané aux reconnexions),
-- exécute l'armurerie côté client (sh_runner), puis récupère les images de
-- fond directement depuis GitHub dans data/scp_armory/ (le menu les y
-- cherche quand materials/ n'est pas monté).

local CACHE_DIR    = "scp_cloudloader"
local MAT_INDEX    = CACHE_DIR .. "/mats.txt"
local MAX_LUA_SIZE = 262144
local MAX_MAT_SIZE = 8388608
local CHUNK        = 40000

local Log = SCPCloud.Log

local files = nil
local mats = nil
local needed = {}   -- sha -> true (en attente du serveur)
local parts = {}    -- sha -> morceaux reçus
local started = false
local executed = false

local function CachePath(sha)
	return CACHE_DIR .. "/" .. string.sub(sha, 1, 32) .. ".txt"
end

local function ReadCode(entry)
	return file.Read(CachePath(entry.sha), "DATA")
end

-- Fonds du menu : téléchargés une fois par version dans data/scp_armory/
local function FetchMaterials()
	local idx = util.JSONToTable(file.Read(MAT_INDEX, "DATA") or "")
	if not istable(idx) then idx = {} end

	for _, m in ipairs(mats or {}) do
		local base = isstring(m.p) and string.match(m.p, "([%w_%-]+%.png)$") or nil
		if base and isstring(m.s) and isstring(m.u)
			and string.find(m.u, "^https://raw%.githubusercontent%.com/") then
			if idx[base] ~= m.s or not file.Exists("scp_armory/" .. base, "DATA") then
				HTTP({
					method = "GET",
					url = m.u,
					headers = { ["User-Agent"] = "scp-cloudloader" },
					success = function(code, body)
						if code == 200 and isstring(body) and #body > 0 and #body <= MAX_MAT_SIZE then
							file.CreateDir("scp_armory")
							file.Write("scp_armory/" .. base, body)
							idx[base] = m.s
							file.Write(MAT_INDEX, util.TableToJSON(idx))
						end
					end,
					failed = function() end,
				})
			end
		end
	end
end

local function ExecuteAll()
	if executed then return end
	executed = true
	Log("Armurerie chargée (" .. table.Count(files) .. " fichiers client).")
	SCPCloud.Execute(files, ReadCode)
	FetchMaterials()
end

net.Receive("SCPCloud_Manifest", function()
	if started then return end

	local len = net.ReadUInt(24)
	local data = util.JSONToTable(util.Decompress(net.ReadData(len) or "", 4194304) or "")
	if not istable(data) or data.disabled or not istable(data.files) then return end
	started = true

	file.CreateDir(CACHE_DIR)
	files = {}
	mats = istable(data.mats) and data.mats or {}

	local missing = {}
	for _, e in ipairs(data.files) do
		if istable(e) and isstring(e.p) and isstring(e.s) and #e.s <= 64
			and string.match(e.p, "^lua/[%w_/%-]+%.lua$") then
			files[e.p] = { sha = e.s, size = tonumber(e.z) or 0 }
			if not file.Exists(CachePath(e.s), "DATA") and not needed[e.s] then
				needed[e.s] = true
				table.insert(missing, e.s)
			end
		end
	end

	if #missing == 0 then
		ExecuteAll()
		return
	end

	Log("Téléchargement de " .. #missing .. " fichier(s)…")
	local count = math.min(#missing, 400)
	net.Start("SCPCloud_Need")
	net.WriteUInt(count, 9)
	for i = 1, count do
		net.WriteString(missing[i])
	end
	net.SendToServer()
end)

net.Receive("SCPCloud_File", function()
	local sha = net.ReadString()
	local part = net.ReadUInt(8)
	local total = net.ReadUInt(8)
	local len = net.ReadUInt(16)
	local piece = net.ReadData(len)

	if not needed[sha] or total == 0 or part > total or len > CHUNK then return end

	local st = parts[sha]
	if not st then
		st = { got = 0, total = total }
		parts[sha] = st
	end
	if st[part] == nil then
		st[part] = piece
		st.got = st.got + 1
	end
	if st.got < st.total then return end

	local comp = table.concat(st, "", 1, st.total)
	parts[sha] = nil
	needed[sha] = nil

	local code = util.Decompress(comp, MAX_LUA_SIZE + 1024)
	if isstring(code) and #code > 0 and #code <= MAX_LUA_SIZE then
		file.Write(CachePath(sha), code)
	end

	if next(needed) == nil then
		ExecuteAll()
	end
end)

hook.Add("InitPostEntity", "SCPCloud_Hello", function()
	timer.Simple(2, function()
		-- L'addon réel est monté chez ce client : rien à charger
		if istable(SCPArmory) and SCPArmory.Slots then return end
		net.Start("SCPCloud_Hello")
		net.SendToServer()
	end)
end)
