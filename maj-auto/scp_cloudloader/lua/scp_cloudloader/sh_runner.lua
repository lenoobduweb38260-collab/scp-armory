-- SCP Cloud Loader — moteur d'exécution partagé (serveur et client)
--
-- Exécute un ensemble de fichiers lua téléchargés (cache data/) comme le jeu
-- l'aurait fait depuis addons/ : fichiers lua/autorun/ dans l'ordre
-- alphabétique, puis enregistrement des entités lua/entities/<classe>/.
-- Pendant l'exécution, include() et AddCSLuaFile() sont détournés vers les
-- fichiers du cloud (chemins relatifs au fichier courant ou à lua/), et les
-- hooks InitPostEntity ajoutés par les fichiers chargés sont rejoués, car
-- le chargement a lieu après ce moment du démarrage.

SCPCloud = SCPCloud or {}

local COL_TAG = Color(190, 34, 28)
local COL_TXT = Color(235, 235, 235)

function SCPCloud.Log(msg)
	MsgC(COL_TAG, "[ARMURERIE CLOUD] ", COL_TXT, msg .. "\n")
end

-- files   : { [chemin] = { sha = ..., size = ... } } (chemins depuis la racine du dépôt)
-- readCode: function(entry, chemin) -> contenu du fichier ou nil
-- Retourne { ran = nombre de fichiers exécutés, errors = { "chemin — erreur", ... } }
function SCPCloud.Execute(files, readCode)
	local stats = { ran = 0, errors = {} }
	local currentDir = ""
	local realInclude, realAddCS = include, AddCSLuaFile
	local RunFile

	local function Fail(path, err)
		local line = path .. " — " .. tostring(err)
		table.insert(stats.errors, line)
		SCPCloud.Log("ERREUR : " .. line)
	end

	local function Resolve(inc)
		if not isstring(inc) or inc == "" or #inc > 128 then return nil end
		if files[currentDir .. inc] then return currentDir .. inc end
		if files["lua/" .. inc] then return "lua/" .. inc end
		return nil
	end

	local function ShimInclude(inc)
		local p = Resolve(inc)
		if p then return RunFile(p) end
		return realInclude(inc)
	end

	local function ShimAddCS(inc)
		-- les fichiers cloud sont livrés aux clients par le réseau : rien à faire
		if inc == nil or Resolve(inc) then return end
		pcall(realAddCS, inc)
	end

	RunFile = function(path)
		local entry = files[path]
		if not entry then return end

		local code = readCode(entry, path)
		if not isstring(code) then
			Fail(path, "fichier manquant en cache")
			return
		end

		local fn = CompileString(code, "scp_cloud/" .. path, false)
		if not isfunction(fn) then
			Fail(path, fn)
			return
		end

		local prevDir = currentDir
		currentDir = string.match(path, "^(.*/)") or ""
		local ok, err = pcall(fn)
		currentDir = prevDir

		if ok then
			stats.ran = stats.ran + 1
		else
			Fail(path, err)
		end
	end

	-- Instantané des hooks InitPostEntity pour rejouer ceux ajoutés au chargement
	local beforeIPE = {}
	for name in pairs(hook.GetTable()["InitPostEntity"] or {}) do
		beforeIPE[name] = true
	end

	include = ShimInclude
	AddCSLuaFile = ShimAddCS

	-- 1) lua/autorun/ dans l'ordre alphabétique, comme le jeu
	local auto = {}
	for path in pairs(files) do
		if string.match(path, "^lua/autorun/[^/]+%.lua$") then
			table.insert(auto, path)
		end
	end
	table.sort(auto)
	for _, p in ipairs(auto) do
		RunFile(p)
	end

	-- 2) entités lua/entities/<classe>/ (init côté serveur, cl_init côté client)
	local classes = {}
	for path in pairs(files) do
		local cls = string.match(path, "^lua/entities/([%w_]+)/")
		if cls then classes[cls] = true end
	end
	for cls in SortedPairs(classes) do
		local base = "lua/entities/" .. cls .. "/"
		local entry
		if SERVER then
			entry = files[base .. "init.lua"] and (base .. "init.lua") or (base .. "shared.lua")
		else
			entry = files[base .. "cl_init.lua"] and (base .. "cl_init.lua") or (base .. "shared.lua")
		end
		if files[entry] then
			ENT = { ClassName = cls, Folder = "entities/" .. cls }
			RunFile(entry)
			local ok, err = pcall(scripted_ents.Register, ENT, cls)
			if not ok then Fail("entities/" .. cls, err) end
			ENT = nil
		end
	end

	include = realInclude
	AddCSLuaFile = realAddCS

	-- 3) rejoue les hooks InitPostEntity ajoutés par les fichiers chargés
	for name, fn in pairs(hook.GetTable()["InitPostEntity"] or {}) do
		if not beforeIPE[name] and isfunction(fn) then
			local ok, err = pcall(fn)
			if not ok then Fail("InitPostEntity/" .. tostring(name), err) end
		end
	end

	return stats
end
