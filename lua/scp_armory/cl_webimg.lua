-- SCP Armory — chargement d'images web (imgur) pour les icônes du menu
-- Les images sont téléchargées une fois, mises en cache dans data/scp_armory/cache/
-- puis affichées comme matériaux.

SCPArmory = SCPArmory or {}
SCPArmory.WebIconCache = SCPArmory.WebIconCache or {}

local CACHE_DIR = "scp_armory/cache"

-- Retourne le matériau d'une URL (nil tant que le téléchargement est en cours ou a échoué)
function SCPArmory.GetWebMaterial(url)
	-- Défense en profondeur : URL http(s) uniquement et longueur bornée,
	-- même si la config serveur les valide déjà
	if not isstring(url) or url == "" or #url > 300
		or not string.find(url, "^https?://") then
		return nil
	end

	local cached = SCPArmory.WebIconCache[url]
	if cached ~= nil then
		return cached or nil -- false = en cours / échec
	end

	local lower = string.lower(url)
	local ext = (string.find(lower, "%.jpe?g") ~= nil) and "jpg" or "png"
	local fname = CACHE_DIR .. "/" .. util.CRC(url) .. "." .. ext

	if file.Exists(fname, "DATA") then
		SCPArmory.WebIconCache[url] = Material("data/" .. fname, "smooth")
		return SCPArmory.WebIconCache[url]
	end

	SCPArmory.WebIconCache[url] = false
	http.Fetch(url, function(body, _, _, code)
		-- Réponse bornée : une image géante ne remplit pas le disque
		if code ~= 200 or not body or #body < 16 or #body > 8 * 1024 * 1024 then return end
		file.CreateDir(CACHE_DIR)
		file.Write(fname, body)
		SCPArmory.WebIconCache[url] = Material("data/" .. fname, "smooth")
	end, function() end)

	return nil
end

-- Dessine l'image centrée dans la zone (x, y, w, h) en gardant les proportions.
-- Retourne true si l'image a été dessinée.
function SCPArmory.DrawWebIcon(url, x, y, w, h)
	local mat = SCPArmory.GetWebMaterial(url)
	if not mat or mat:IsError() then return false end

	local mw, mh = mat:Width(), mat:Height()
	if mw <= 0 or mh <= 0 then return false end

	local scale = math.min(w / mw, h / mh)
	local dw, dh = mw * scale, mh * scale

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(mat)
	surface.DrawTexturedRect(math.floor(x + (w - dw) / 2), math.floor(y + (h - dh) / 2), math.floor(dw), math.floor(dh))
	return true
end
