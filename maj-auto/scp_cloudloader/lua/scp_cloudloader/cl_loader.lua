-- SCP Cloud Loader — client (v2)
--
-- À la connexion : demande le manifeste au serveur (avec relances tant qu'il
-- ne répond pas), télécharge les fichiers manquants (cache
-- data/scp_cloudloader/, donc instantané aux reconnexions), exécute
-- l'armurerie côté client (sh_runner), confirme au serveur, puis récupère
-- les images de fond depuis GitHub dans data/scp_armory/.
--
-- Diagnostic : commande console « scp_cloud_status » côté client.

local CACHE_DIR    = "scp_cloudloader"
local MAT_INDEX    = CACHE_DIR .. "/mats.txt"
local MAX_LUA_SIZE = 262144
local MAX_MAT_SIZE = 8388608
local CHUNK        = 40000
local HELLO_TRIES  = 8      -- relances du bonjour (serveur encore en chargement…)
local HELLO_EVERY  = 8
local NEED_TRIES   = 4      -- relances de la demande de fichiers manquants
local NEED_EVERY   = 20

local Log = SCPCloud.Log

local files = nil
local mats = nil
local needed = {}   -- sha -> true (en attente du serveur)
local parts = {}    -- sha -> morceaux reçus
local started = false
local executed = false

-- État exposé pour le diagnostic
SCPCloud.CL = { state = "attente du serveur", missing = 0, errors = {} }

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

	local stats = SCPCloud.Execute(files, ReadCode)
	SCPCloud.CL.errors = stats.errors
	SCPCloud.CL.state = (#stats.errors == 0)
		and ("armurerie chargée (" .. stats.ran .. " fichiers)")
		or ("chargée avec " .. #stats.errors .. " erreur(s)")
	Log("Client : " .. SCPCloud.CL.state .. ".")

	-- Confirme au serveur (visible dans sa console : qui a vraiment chargé)
	net.Start("SCPCloud_Done")
	net.WriteUInt(math.min(#stats.errors, 255), 8)
	net.SendToServer()

	FetchMaterials()
end

-- Demande des fichiers manquants, relancée tant qu'il en reste
local function RequestMissing()
	local missing = {}
	for sha in pairs(needed) do
		table.insert(missing, sha)
	end
	if #missing == 0 then return end

	SCPCloud.CL.state = "téléchargement de " .. #missing .. " fichier(s)…"
	SCPCloud.CL.missing = #missing

	local count = math.min(#missing, 400)
	net.Start("SCPCloud_Need")
	net.WriteUInt(count, 9)
	for i = 1, count do
		net.WriteString(missing[i])
	end
	net.SendToServer()
end

net.Receive("SCPCloud_Manifest", function()
	if started then return end

	local len = net.ReadUInt(24)
	local data = util.JSONToTable(util.Decompress(net.ReadData(len) or "", 4194304) or "")
	if not istable(data) then return end
	if data.disabled then
		started = true
		SCPCloud.CL.state = "désactivé (addon sur le disque du serveur)"
		return
	end
	if not istable(data.files) then return end
	started = true

	file.CreateDir(CACHE_DIR)
	files = {}
	mats = istable(data.mats) and data.mats or {}

	for _, e in ipairs(data.files) do
		if istable(e) and isstring(e.p) and isstring(e.s) and #e.s <= 64
			and string.match(e.p, "^lua/[%w_/%-]+%.lua$") then
			files[e.p] = { sha = e.s, size = tonumber(e.z) or 0 }
			if not file.Exists(CachePath(e.s), "DATA") then
				needed[e.s] = true
			end
		end
	end

	if next(needed) == nil then
		ExecuteAll()
		return
	end

	RequestMissing()

	-- Relances : un message réseau peut se perdre, le serveur être occupé…
	local tries = 0
	timer.Create("SCPCloud_NeedRetry", NEED_EVERY, NEED_TRIES, function()
		if executed or next(needed) == nil then
			timer.Remove("SCPCloud_NeedRetry")
			return
		end
		tries = tries + 1
		Log("Fichiers toujours manquants (" .. table.Count(needed) .. ") — relance " .. tries .. ".")
		RequestMissing()
	end)
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

	SCPCloud.CL.missing = table.Count(needed)
	if next(needed) == nil then
		timer.Remove("SCPCloud_NeedRetry")
		ExecuteAll()
	end
end)

-- Bonjour au serveur, relancé tant que le manifeste n'est pas arrivé
hook.Add("InitPostEntity", "SCPCloud_Hello", function()
	timer.Simple(2, function()
		-- L'addon réel est monté chez ce client : rien à charger
		if istable(SCPArmory) and SCPArmory.Slots then
			SCPCloud.CL.state = "désactivé (addon monté localement)"
			return
		end

		local tries = 0
		local function Hello()
			if started then return end
			tries = tries + 1
			SCPCloud.CL.state = "demande au serveur (essai " .. tries .. ")"
			net.Start("SCPCloud_Hello")
			net.SendToServer()
		end

		Hello()
		timer.Create("SCPCloud_HelloRetry", HELLO_EVERY, HELLO_TRIES - 1, function()
			if started then
				timer.Remove("SCPCloud_HelloRetry")
				return
			end
			Hello()
		end)
	end)
end)

-- Diagnostic client : scp_cloud_status en console
concommand.Add("scp_cloud_status", function()
	Log("État client : " .. tostring(SCPCloud.CL.state))
	Log("Fichiers en attente : " .. tostring(SCPCloud.CL.missing or 0))
	for _, e in ipairs(SCPCloud.CL.errors or {}) do
		Log("  ERREUR " .. e)
	end
end, nil, "État du chargeur cloud de l'armurerie (côté client).")
