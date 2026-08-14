-- SCP Cloud Loader — serveur
--
-- À chaque démarrage : récupère le dernier commit de la branche, télécharge
-- les fichiers modifiés (cache data/scp_cloudloader/), exécute l'armurerie
-- (voir sh_runner) puis distribue les fichiers client aux joueurs par le
-- réseau. Si GitHub est injoignable, le serveur démarre sur la dernière
-- copie en cache : jamais bloqué.
--
-- Confiance et sécurité :
--  - sources épinglées : uniquement api.github.com et raw.githubusercontent.com,
--    sur le dépôt et la branche configurés ci-dessous, en HTTPS ;
--  - tailles, nombres de fichiers et réponses bornés et validés ;
--  - les fichiers serveur (sv_*) ne sont jamais envoyés aux clients ;
--  - requêtes des clients limitées en cadence et validées ;
--  - si l'addon scp-armory est présent sur le disque, le cloud se désactive.

util.AddNetworkString("SCPCloud_Hello")
util.AddNetworkString("SCPCloud_Manifest")
util.AddNetworkString("SCPCloud_Need")
util.AddNetworkString("SCPCloud_File")

-- ------------------------------------------------ configuration du dépôt
local REPO   = "lenoobduweb38260-collab/scp-armory"
local BRANCH = "claude/ready-or-not-loadout-gbii3v"
-- -----------------------------------------------------------------------

local MAX_FILES    = 400
local MAX_LUA_SIZE = 262144   -- 256 Ko par fichier lua
local MAX_MAT_SIZE = 8388608  -- 8 Mo par image de fond
local CACHE_DIR    = "scp_cloudloader"
local INDEX_FILE   = CACHE_DIR .. "/index.txt"
local CHUNK        = 40000

local Log = SCPCloud.Log

local files = nil      -- [chemin] = { sha, size } (fichiers lua)
local mats = nil       -- { { path, sha, size } } (images de fond)
local commitSha = nil
local loaded = false
local manifestComp = nil
local waiting = {}     -- joueurs connectés avant la fin du chargement

local function CachePath(sha)
	return CACHE_DIR .. "/" .. string.sub(sha, 1, 32) .. ".txt"
end

-- GET avec délai de garde : le démarrage ne reste jamais suspendu
local function Fetch(url, cb)
	local done = false
	HTTP({
		method = "GET",
		url = url,
		headers = { ["User-Agent"] = "scp-cloudloader" },
		success = function(code, body)
			if done then return end
			done = true
			cb(code == 200 and body or nil)
		end,
		failed = function()
			if done then return end
			done = true
			cb(nil)
		end,
	})
	timer.Simple(45, function()
		if not done then
			done = true
			cb(nil)
		end
	end)
end

local function ReadCode(entry)
	return file.Read(CachePath(entry.sha), "DATA")
end

-- Un fichier appartient-il au lot livré aux clients ? Les fichiers serveur
-- (sv_* et init.lua d'entité) restent sur le serveur, comme dans le jeu.
local function IsClientPath(path)
	if string.find(path, "/sv_", 1, true) then return false end
	if string.match(path, "^lua/entities/.+/init%.lua$") then return false end
	return true
end

-- Manifeste envoyé aux clients : fichiers non serveur + images de fond
local function BuildManifest()
	local list = {}
	for path, e in pairs(files) do
		if IsClientPath(path) then
			table.insert(list, { p = path, s = e.sha, z = e.size })
		end
	end
	table.sort(list, function(a, b) return a.p < b.p end)

	local m = {}
	for _, e in ipairs(mats or {}) do
		table.insert(m, {
			p = e.path, s = e.sha, z = e.size,
			u = "https://raw.githubusercontent.com/" .. REPO .. "/" .. commitSha .. "/" .. e.path,
		})
	end

	return util.Compress(util.TableToJSON({ commit = commitSha, files = list, mats = m }))
end

local function SendManifest(ply)
	if not manifestComp or not IsValid(ply) then return end
	net.Start("SCPCloud_Manifest")
	net.WriteUInt(#manifestComp, 24)
	net.WriteData(manifestComp, #manifestComp)
	net.Send(ply)
end

local function FlushWaiting()
	for _, ply in ipairs(waiting) do
		SendManifest(ply)
	end
	waiting = {}
end

local function Activate(fromCache)
	loaded = true
	manifestComp = BuildManifest()
	Log((fromCache and "GitHub injoignable — copie en cache" or "GitHub") .. " : armurerie chargée (commit "
		.. string.sub(commitSha or "?", 1, 7) .. ", " .. table.Count(files) .. " fichiers).")
	SCPCloud.Execute(files, ReadCode)
	FlushWaiting()
end

local function LoadIndex()
	local idx = util.JSONToTable(file.Read(INDEX_FILE, "DATA") or "")
	if not istable(idx) or not istable(idx.files) or not isstring(idx.commit) then return false end
	for _, e in pairs(idx.files) do
		if not istable(e) or not isstring(e.sha) or not file.Exists(CachePath(e.sha), "DATA") then
			return false
		end
	end
	files = idx.files
	mats = istable(idx.mats) and idx.mats or {}
	commitSha = idx.commit
	return true
end

local function FallbackCache(reason)
	Log(reason .. " — tentative sur la dernière copie en cache…")
	if LoadIndex() then
		Activate(true)
	else
		Log("Aucun cache utilisable : armurerie indisponible pour ce démarrage.")
	end
end

local function Boot()
	-- L'addon réel est sur le disque : le cloud s'efface complètement
	if istable(SCPArmory) and SCPArmory.Slots then
		Log("Addon scp-armory présent sur le disque : chargement cloud désactivé.")
		loaded = true
		manifestComp = util.Compress(util.TableToJSON({ disabled = true }))
		FlushWaiting()
		return
	end

	file.CreateDir(CACHE_DIR)

	Fetch("https://api.github.com/repos/" .. REPO .. "/commits/" .. BRANCH, function(body)
		local data = body and util.JSONToTable(body)
		local sha = data and isstring(data.sha) and string.match(data.sha, "^%x+$") and data.sha or nil
		if not sha or #sha > 64 then
			FallbackCache("GitHub inaccessible (commit)")
			return
		end
		commitSha = sha

		Fetch("https://api.github.com/repos/" .. REPO .. "/git/trees/" .. sha .. "?recursive=1", function(tbody)
			local tree = tbody and util.JSONToTable(tbody)
			if not (istable(tree) and istable(tree.tree)) then
				FallbackCache("GitHub inaccessible (arborescence)")
				return
			end

			local wantLua, wantMats, count = {}, {}, 0
			for _, e in ipairs(tree.tree) do
				if istable(e) and e.type == "blob" and isstring(e.path) and isstring(e.sha)
					and string.match(e.sha, "^%x+$") then
					local size = tonumber(e.size) or 0
					if string.match(e.path, "^lua/[%w_/%-]+%.lua$") and size <= MAX_LUA_SIZE then
						wantLua[e.path] = { sha = e.sha, size = size }
						count = count + 1
					elseif string.match(e.path, "^materials/scp_armory/[%w_%-]+%.png$") and size <= MAX_MAT_SIZE then
						table.insert(wantMats, { path = e.path, sha = e.sha, size = size })
						count = count + 1
					end
					if count > MAX_FILES then
						FallbackCache("Dépôt anormalement volumineux")
						return
					end
				end
			end
			if next(wantLua) == nil then
				FallbackCache("Aucun fichier lua dans le dépôt")
				return
			end

			-- Seuls les fichiers absents du cache sont téléchargés
			local missing = {}
			for path, e in pairs(wantLua) do
				if not file.Exists(CachePath(e.sha), "DATA") then
					table.insert(missing, path)
				end
			end

			local pending = #missing
			local failed = false
			local function Finish()
				if failed then
					FallbackCache("Téléchargement incomplet")
					return
				end
				files = wantLua
				mats = wantMats
				file.Write(INDEX_FILE, util.TableToJSON({ commit = commitSha, files = files, mats = mats }))
				Activate(false)
			end

			if pending == 0 then
				Finish()
				return
			end

			Log("Téléchargement de " .. pending .. " fichier(s) depuis GitHub…")
			for _, path in ipairs(missing) do
				local e = wantLua[path]
				Fetch("https://raw.githubusercontent.com/" .. REPO .. "/" .. commitSha .. "/" .. path, function(code)
					if isstring(code) and #code > 0 and #code <= MAX_LUA_SIZE then
						file.Write(CachePath(e.sha), code)
					else
						failed = true
					end
					pending = pending - 1
					if pending == 0 then Finish() end
				end)
			end
		end)
	end)
end

hook.Add("InitPostEntity", "SCPCloud_Boot", function()
	timer.Simple(1, Boot)
end)

-- ----------------------------------------- distribution aux joueurs

net.Receive("SCPCloud_Hello", function(_, ply)
	if not IsValid(ply) then return end
	if (ply.SCPCloudHelloRL or 0) > CurTime() then return end
	ply.SCPCloudHelloRL = CurTime() + 5

	if loaded then
		SendManifest(ply)
	else
		table.insert(waiting, ply)
	end
end)

net.Receive("SCPCloud_Need", function(_, ply)
	if not IsValid(ply) or not loaded or not files then return end
	if (ply.SCPCloudNeedRL or 0) > CurTime() then return end
	ply.SCPCloudNeedRL = CurTime() + 5

	-- Seuls les sha réellement servis aux clients sont acceptés
	local allowed = {}
	for path, e in pairs(files) do
		if IsClientPath(path) then
			allowed[e.sha] = true
		end
	end

	local n = math.min(net.ReadUInt(9), MAX_FILES)
	local sent = 0
	for _ = 1, n do
		local sha = net.ReadString()
		if #sha <= 64 and allowed[sha] and sent < MAX_FILES then
			local code = file.Read(CachePath(sha), "DATA")
			if isstring(code) then
				local comp = util.Compress(code)
				local total = math.ceil(#comp / CHUNK)
				for part = 1, total do
					local piece = string.sub(comp, (part - 1) * CHUNK + 1, part * CHUNK)
					net.Start("SCPCloud_File")
					net.WriteString(sha)
					net.WriteUInt(part, 8)
					net.WriteUInt(total, 8)
					net.WriteUInt(#piece, 16)
					net.WriteData(piece, #piece)
					net.Send(ply)
				end
				sent = sent + 1
			end
		end
	end
end)
