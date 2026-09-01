-- SCP Armory — menu de loadout client (Derma)
-- Réplique des écrans LOADOUT et MODIFY WEAPON de Ready or Not :
-- plein écran sur fond noir, colonne d'équipement à gauche, aperçu en grand,
-- accessoires ARC9 choisis uniquement via ce menu.

-- Polices à l'échelle de la résolution (recréées si elle change en jeu)
local fontScale = 0
local function EnsureFonts()
	local scale = math.Clamp(ScrH() / 1080, 0.85, 1.25)
	if math.abs(scale - fontScale) < 0.01 then return end
	fontScale = scale

	local function F(name, size, weight)
		surface.CreateFont(name, { font = "Roboto", size = math.Round(size * scale), weight = weight })
	end

	F("SCPArmory_RoN_Huge", 46, 200)
	F("SCPArmory_RoN_Big", 30, 300)
	F("SCPArmory_RoN_Name", 21, 500)
	F("SCPArmory_RoN_NameSm", 17, 500)
	F("SCPArmory_RoN_Label", 12, 700)
	F("SCPArmory_RoN_Small", 12, 500)
	F("SCPArmory_RoN_Btn", 15, 800)
end

EnsureFonts()

local COL = {
	bg     = Color(5, 5, 7, 253),
	text   = Color(235, 235, 235, 255),
	soft   = Color(205, 205, 208, 255),
	dim    = Color(125, 125, 130, 255),
	faint  = Color(75, 75, 80, 255),
	red    = Color(190, 34, 28, 255),
	redHi  = Color(225, 52, 44, 255),
	line   = Color(70, 70, 75, 180),
	lineF  = Color(42, 42, 46, 160),
	panel  = Color(10, 10, 13, 216),
	card   = Color(13, 13, 17, 216),
}

-- Couleurs mutables réutilisées dans les Paint (aucune allocation par frame)
local rowBG = Color(255, 255, 255, 8)
local btnBG = Color(190, 34, 28, 255)
local flashBG = Color(255, 255, 255, 255)
local backBG = Color(255, 255, 255, 20)
local mwCell = Color(255, 255, 255, 5)
local mwFill = Color(190, 34, 28, 0)
local mwEdge = Color(190, 34, 28, 90)
local mwDark = Color(12, 12, 15, 235)
local mwGloss = Color(255, 255, 255, 0)
local btnPress = Color(0, 0, 0, 70)
local chevCol = Color(255, 255, 255, 0)

-- Matériaux (fonds et habillage du thème légion) : depuis materials/ (addon
-- sur le disque) ou, en mode chargeur cloud, depuis data/scp_armory/ où le
-- loader les télécharge. Résolution paresseuse et re-tentée : l'image peut
-- arriver après le chargement de ce fichier.
local bgMats = {}
local bgRetry = 0
local function BackdropMat(name)
	local m = bgMats[name]
	if m and not m:IsError() then return m end
	if RealTime() < bgRetry then return m end
	bgRetry = RealTime() + 2

	m = Material("scp_armory/" .. name, "smooth")
	if m:IsError() and file.Exists("scp_armory/" .. name, "DATA") then
		m = Material("data/scp_armory/" .. name, "smooth")
	end
	bgMats[name] = m
	return m
end

-- ------------------------------------------------------------------ thèmes
-- Style d'interface actif : "ron" (Ready or Not plat et épuré) ou
-- "mw" (Modern Warfare, sélection en cartes façon killstreaks)
local uiStyle = "ron"

-- Applique le style et la couleur d'accent configurés : COL.red/redHi
-- sont mutées en place, donc toutes les références déjà prises restent bonnes
local function ApplyTheme()
	uiStyle = (SCPArmory.Config.UITheme == "mw") and "mw" or "ron"

	local r, g, b = SCPArmory.AccentColor()
	COL.red.r, COL.red.g, COL.red.b = r, g, b
	COL.redHi.r = math.min(255, r + 35)
	COL.redHi.g = math.min(255, g + 18)
	COL.redHi.b = math.min(255, b + 16)
	btnBG.r, btnBG.g, btnBG.b = r, g, b
end

local shadowA = Color(0, 0, 0, 95)
local shadowB = Color(0, 0, 0, 45)

-- Pictogrammes vectoriels des emplacements sans modèle 3D (gilet, casque,
-- apparence) pour les thèmes en boîtes, dessinés en rectangles
local function DrawSlotIcon(kind, x, y, s, col)
	surface.SetDrawColor(col.r, col.g, col.b, 210)
	local u = s / 22
	if kind == "armor" then
		-- gilet : bretelles, plastron, ceinture
		surface.DrawRect(x + 4 * u, y + 1 * u, 4 * u, 6 * u)
		surface.DrawRect(x + 14 * u, y + 1 * u, 4 * u, 6 * u)
		surface.DrawRect(x + 3 * u, y + 7 * u, 16 * u, 10 * u)
		surface.DrawRect(x + 5 * u, y + 17 * u, 12 * u, 3 * u)
	elseif kind == "helmet" then
		-- casque : dôme en escalier, visière, jugulaire
		surface.DrawRect(x + 7 * u, y + 2 * u, 8 * u, 3 * u)
		surface.DrawRect(x + 4 * u, y + 5 * u, 14 * u, 8 * u)
		surface.DrawRect(x + 3 * u, y + 13 * u, 16 * u, 3 * u)
		surface.DrawRect(x + 15 * u, y + 16 * u, 3 * u, 5 * u)
	elseif kind == "rifle" then
		-- fusil : crosse, corps, canon, chargeur, poignée
		surface.DrawRect(x + 1 * u, y + 12 * u, 4 * u, 5 * u)
		surface.DrawRect(x + 4 * u, y + 9 * u, 13 * u, 4 * u)
		surface.DrawRect(x + 17 * u, y + 10 * u, 4 * u, 2 * u)
		surface.DrawRect(x + 5 * u, y + 6 * u, 3 * u, 3 * u)
		surface.DrawRect(x + 10 * u, y + 13 * u, 3 * u, 6 * u)
		surface.DrawRect(x + 15 * u, y + 13 * u, 3 * u, 4 * u)
	elseif kind == "shield" then
		-- bouclier : écusson en escalier
		surface.DrawRect(x + 4 * u, y + 2 * u, 14 * u, 5 * u)
		surface.DrawRect(x + 5 * u, y + 7 * u, 12 * u, 5 * u)
		surface.DrawRect(x + 7 * u, y + 12 * u, 8 * u, 5 * u)
		surface.DrawRect(x + 9 * u, y + 17 * u, 4 * u, 3 * u)
	elseif kind == "gear" then
		-- engrenage : bloc central, quatre dents, axe évidé
		surface.DrawRect(x + 6 * u, y + 6 * u, 10 * u, 10 * u)
		surface.DrawRect(x + 9 * u, y + 2 * u, 4 * u, 4 * u)
		surface.DrawRect(x + 9 * u, y + 16 * u, 4 * u, 4 * u)
		surface.DrawRect(x + 2 * u, y + 9 * u, 4 * u, 4 * u)
		surface.DrawRect(x + 16 * u, y + 9 * u, 4 * u, 4 * u)
		surface.SetDrawColor(10, 13, 18, 255)
		surface.DrawRect(x + 9 * u, y + 9 * u, 4 * u, 4 * u)
	else
		-- silhouette (apparence) : tête, torse, bras
		surface.DrawRect(x + 8 * u, y + 1 * u, 6 * u, 6 * u)
		surface.DrawRect(x + 5 * u, y + 8 * u, 12 * u, 9 * u)
		surface.DrawRect(x + 2 * u, y + 8 * u, 3 * u, 7 * u)
		surface.DrawRect(x + 17 * u, y + 8 * u, 3 * u, 7 * u)
		surface.DrawRect(x + 6 * u, y + 17 * u, 4 * u, 4 * u)
		surface.DrawRect(x + 12 * u, y + 17 * u, 4 * u, 4 * u)
	end
end

-- Habillage commun des lignes de la colonne : ligne plate à séparateur
-- (ron), cellule sombre arrondie à surlignage d'accent (mw)
local function RowChrome(hf, w, h)
	if uiStyle == "mw" then
		draw.RoundedBox(8, 0, 0, w, h, mwCell)
		if hf > 0.01 then
			mwFill.r, mwFill.g, mwFill.b, mwFill.a = COL.red.r, COL.red.g, COL.red.b, 36 * hf
			draw.RoundedBox(8, 0, 0, w, h, mwFill)
			mwFill.a = 255 * hf
			draw.RoundedBox(2, 0, 5, 3, h - 10, mwFill)
		end
	else
		if hf > 0.01 then
			surface.SetDrawColor(255, 255, 255, 6 * hf)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 255 * hf)
			surface.DrawRect(0, 0, 2, h)
		end
		surface.SetDrawColor(COL.lineF)
		surface.DrawRect(0, h - 1, w, 1)
	end
end

local SAVE_DIR = "scp_armory"
local SAVE_FILE = SAVE_DIR .. "/loadout.txt"

-- (matériaux d'ambiance et de thème : voir BackdropMat plus haut)

local WEAPON_KEYS = { "primary", "secondary" }

local activeMenu = nil

-- Fermeture en fondu du menu d'armurerie ouvert, de n'importe où :
-- utilisée par le bouton CONFIGURATION et à la réception d'une nouvelle
-- configuration (le menu ouvert ne peut pas rester sur des objets périmés)
function SCPArmory.CloseLoadoutMenu()
	local f = activeMenu
	if not IsValid(f) or f.closing then return end
	f.closing = true
	f:AlphaTo(0, 0.14, 0, function()
		if IsValid(f) then f:Remove() end
	end)
end

-- Traduction (français par défaut, allemand/polonais selon la config serveur)
local function T(s) return SCPArmory.T(s) end

-- ------------------------------------------------------------------- helpers

local function SlotByKey(key)
	for _, slot in ipairs(SCPArmory.Slots) do
		if slot.key == key then return slot end
	end
end

-- Texte à lettres espacées, façon typographie Ready or Not
local function DrawSpacedText(text, font, x, y, col, tracking)
	if not utf8 then
		draw.SimpleText(text, font, x, y, col)
		return
	end

	surface.SetFont(font)
	surface.SetTextColor(col.r, col.g, col.b, col.a)
	local cx = x
	for _, code in utf8.codes(text) do
		local ch = utf8.char(code)
		surface.SetTextPos(cx, y)
		surface.DrawText(ch)
		local w = surface.GetTextSize(ch)
		cx = cx + w + tracking
	end
	return cx - x - tracking
end

-- Vue de profil fixe d'un modèle d'arme (comme les silhouettes RoN)
local function FitModelSide(panel)
	local ent = panel:GetEntity()
	if not IsValid(ent) then return end

	local mn, mx = ent:GetRenderBounds()
	local center = (mn + mx) * 0.5
	local size = math.max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z, 4)

	panel:SetFOV(26)
	panel:SetCamPos(center + Vector(0, size * 2.4, 0))
	panel:SetLookAt(center)
	panel.LayoutEntity = function() end
end

local function HasModel(item)
	return item and item.model and file.Exists(item.model, "GAME")
end

-- Interpolation douce (smoothstep) pour les animations de l'interface
local function Ease(t)
	t = math.Clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Petit « tic » sonore au survol des boutons, façon menu de jeu
local function HoverCue(btn)
	btn.OnCursorEntered = function()
		surface.PlaySound("ui/buttonrollover.wav")
	end
end

-- Silhouette d'un accessoire ARC9 (la même icône que dans le menu spawn,
-- comme dans Ready or Not), ajustée à la zone en gardant les proportions.
-- Retourne true si une icône a été dessinée.
local function DrawAttIcon(attId, x, y, w, h, col)
	local mat = SCPArmory.ARC9Bridge.AttIcon(attId)
	if not mat then return false end

	local mw, mh = mat:Width(), mat:Height()
	if mw <= 0 or mh <= 0 then mw, mh = 1, 1 end
	local scale = math.min(w / mw, h / mh)
	local dw, dh = mw * scale, mh * scale

	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	surface.SetMaterial(mat)
	surface.DrawTexturedRect(math.floor(x + (w - dw) / 2), math.floor(y + (h - dh) / 2),
		math.floor(dw), math.floor(dh))
	return true
end

-- ---------------------------------------------------------------- persistence

local function LoadSaved()
	local sel = SCPArmory.DefaultLoadout()
	local atts = { primary = {}, secondary = {} }

	if file.Exists(SAVE_FILE, "DATA") then
		local tbl = util.JSONToTable(file.Read(SAVE_FILE, "DATA") or "")
		if tbl then
			for _, slot in ipairs(SCPArmory.Slots) do
				local id = tbl[slot.key]
				if id and SCPArmory.GetItem(slot.pool, id) then
					sel[slot.key] = id
				end
			end

			-- Les clés JSON redeviennent des chaînes : re-typer les index
			if istable(tbl.__atts) then
				for _, wkey in ipairs(WEAPON_KEYS) do
					for k, v in pairs(tbl.__atts[wkey] or {}) do
						local idx = tonumber(k)
						if idx and isstring(v) then atts[wkey][idx] = v end
					end
				end
			end

			-- Bodygroups personnalisés (apparence)
			if istable(tbl.bg) then
				sel.bg = {}
				for k, v in pairs(tbl.bg) do
					if isstring(k) and #k <= 48 and isnumber(v) then
						sel.bg[string.lower(k)] = math.Clamp(math.floor(v), 0, 31)
					end
				end
			end
		end
	end

	-- Retire les objets invisibles pour le job actuel (changement de métier, etc.)
	for _, slot in ipairs(SCPArmory.Slots) do
		local item = SCPArmory.GetItem(slot.pool, sel[slot.key])
		if item and not SCPArmory.IsItemAvailable(LocalPlayer(), item) then
			sel[slot.key] = "none"
		end
	end

	-- Ne garde que les accessoires encore valides pour l'arme sauvegardée
	for _, wkey in ipairs(WEAPON_KEYS) do
		local item = SCPArmory.GetItem(wkey, sel[wkey])
		local clean = {}
		if item and item.class and SCPArmory.ARC9Bridge.IsARC9Class(item.class) then
			for idx, attId in pairs(atts[wkey]) do
				if SCPArmory.ARC9Bridge.IsCompatible(item.class, idx, attId) then
					clean[idx] = attId
				end
			end
		end
		atts[wkey] = clean
	end

	return sel, atts
end

local function SaveSelection(sel, atts)
	file.CreateDir(SAVE_DIR)
	local tbl = table.Copy(sel)
	tbl.__atts = atts
	file.Write(SAVE_FILE, util.TableToJSON(tbl, true))
end

-- ---------------------------------------------------------------------- menu

local function OpenMenu()
	if IsValid(activeMenu) then activeMenu:Remove() end

	EnsureFonts()
	ApplyTheme()

	-- Espacement des lignes selon le style
	local rowGap = (uiStyle == "mw") and 4 or 0

	local selection, attSel = LoadSaved()
	local plyModel = LocalPlayer():GetModel()

	local jobName = team.GetName(LocalPlayer():Team()) or ""
	if jobName == "" then jobName = "Opérateur" end

	-- Modes : "overview" (LOADOUT), "modify" (MODIFY WEAPON),
	-- "select" (choix d'un objet), "attselect" (choix d'un accessoire),
	-- "bgselect" (variante d'apparence), "section" (catégorie du hub légion)
	local mode = "overview"
	local curWeaponKey = "primary"
	local selectSlot = nil
	local selectReturn = "overview"
	local attSlot = nil
	local bgSlot = nil
	local hoverItem = nil
	local hoverAtt = nil

	-- Le mode "section" n'est utilisé que par la carte APPARENCE du thème MW

	-- Écrans de retour selon la provenance (vue d'ensemble ou section)
	local modifyReturn = "overview"
	local bgReturn = "overview"

	-- Écran killstreak du thème MW (rempli plus bas)
	local RebuildMW = function() end

	local function CurWeaponItem()
		return SCPArmory.GetItem(curWeaponKey, selection[curWeaponKey])
	end

	local frame = vgui.Create("DFrame")
	activeMenu = frame
	frame:SetSize(ScrW(), ScrH())
	frame:SetPos(0, 0)
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(false)
	frame:MakePopup()

	-- Fondu d'ouverture
	frame:SetAlpha(0)
	frame:AlphaTo(255, 0.18, 0)

	local openTime = RealTime()

	-- Fonds d'ambiance générés, livrés dans materials/scp_armory :
	-- râteliers d'armurerie derrière l'opérateur, établi sous l'arme
	local bgWeapon = false -- écran arme (établi) ou opérateur (râteliers)
	local bgBlend = 0

	-- Parallaxe lissé : le fond glisse à l'opposé de la souris, la caméra de
	-- l'opérateur dans le même sens — le menu prend une vraie profondeur
	local parX, parY = 0, 0

	local function DrawBackdrop(mat, iw, ih, w, h, alpha)
		if not mat or mat:IsError() or iw <= 0 or ih <= 0 then return end
		local scale = math.max(w / iw, h / ih)
		local dw, dh = iw * scale, ih * scale
		-- L'image est très légèrement zoomée pour offrir la marge de parallaxe
		local inset = 0.015
		local u = (dw - w) / dw * 0.5 + inset
		local v = (dh - h) / dh * 0.5 + inset
		surface.SetDrawColor(255, 255, 255, alpha)
		surface.SetMaterial(mat)
		surface.DrawTexturedRectUV(0, 0, w, h, u + parX, v + parY, 1 - u + parX, 1 - v + parY)
	end

	-- Fond d'un écran : l'image personnalisée de la config (URL, affichée
	-- telle quelle) si elle est définie et chargée, sinon le fond livré
	local function ResolveBackdrop(shipped, urlKey)
		local url = SCPArmory.Config[urlKey]
		if isstring(url) and url ~= "" then
			local m = SCPArmory.GetWebMaterial(url)
			if m and not m:IsError() then
				return m, m:Width(), m:Height()
			end
		end
		return BackdropMat(shipped), 1920, 1080
	end

	frame.Paint = function(_, w, h)
		surface.SetDrawColor(COL.bg)
		surface.DrawRect(0, 0, w, h)

		-- Parallaxe lissé suivant la souris (le fond glisse à l'opposé)
		local tx = (gui.MouseX() / math.max(ScrW(), 1) - 0.5) * 0.02
		local ty = (gui.MouseY() / math.max(ScrH(), 1) - 0.5) * 0.012
		local fr = math.Clamp(FrameTime() * 5, 0, 1)
		parX = parX + (tx - parX) * fr
		parY = parY + (ty - parY) * fr

		-- Fondu croisé selon l'écran affiché (opérateur / établi d'arme) ;
		-- chaque lieu ET chaque style d'interface a son URL de fond configurable
		if SCPArmory.Config.MenuScene ~= false then
			bgBlend = Lerp(FrameTime() * 6, bgBlend, bgWeapon and 1 or 0)
			local mw = (uiStyle == "mw")
			if bgBlend < 0.99 then
				local m, iw, ih = ResolveBackdrop("bg_racks.png", mw and "MenuBGMwURL" or "MenuBGRonURL")
				DrawBackdrop(m, iw, ih, w, h, 255 * (1 - bgBlend))
			end
			if bgBlend > 0.01 then
				local m, iw, ih = ResolveBackdrop("bg_table.png", mw and "MenuBGMwWeaponURL" or "MenuBGRonWeaponURL")
				DrawBackdrop(m, iw, ih, w, h, 255 * bgBlend)
			end
		end

		-- Dégradé sombre derrière la colonne pour la lisibilité, façon RoN
		local gw = 560
		local steps = 28
		local band = gw / steps
		for i = 0, steps - 1 do
			surface.SetDrawColor(0, 0, 0, 190 * (1 - i / steps))
			surface.DrawRect(i * band, 0, math.ceil(band), h)
		end
	end
	frame.PaintOver = function(_, w, h)
		local rt = RealTime()

		-- Trait d'accent net en haut de l'écran (mw uniquement)
		if uiStyle == "mw" then
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 0, w, 2)
		end

		-- Vignette cinématique haut/bas
		local vh = 80
		for i = 0, 7 do
			local a = 64 * (1 - i / 8)
			surface.SetDrawColor(0, 0, 0, a)
			surface.DrawRect(0, i * (vh / 8), w, math.ceil(vh / 8))
			surface.DrawRect(0, h - (i + 1) * (vh / 8), w, math.ceil(vh / 8))
		end

		-- Fine ligne de balayage, très discrète (ambiance moniteur)
		local sy = (rt * 26) % (h + 120) - 60
		surface.SetDrawColor(255, 255, 255, 3)
		surface.DrawRect(0, sy, w, 2)

		-- Coins de cadre tactique, pulsation lente
		local ca = 90 + math.sin(rt * 1.3) * 25
		surface.SetDrawColor(COL.line.r, COL.line.g, COL.line.b, ca)
		local bl, bt = 26, 2
		for _, c in ipairs({ { 16, 12, 1, 1 }, { w - 16, 12, -1, 1 }, { 16, h - 12, 1, -1 }, { w - 16, h - 12, -1, -1 } }) do
			local cx, cy, dx, dy = c[1], c[2], c[3], c[4]
			surface.DrawRect(dx > 0 and cx or cx - bl, dy > 0 and cy or cy - bt, bl, bt)
			surface.DrawRect(dx > 0 and cx or cx - bt, dy > 0 and cy or cy - bl, bt, bl)
		end

		-- Bloc d'état : LED en double-flash militaire + horloge + session
		local bt2 = rt % 2.4
		local ledOn = bt2 < 0.08 or (bt2 > 0.24 and bt2 < 0.32)
		surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, ledOn and 255 or 60)
		surface.DrawRect(w - 26 - 4, 52, 4, 4)

		local session = math.floor(rt - openTime)
		local status = string.format("EN LIGNE  //  %s  //  SESSION %02d:%02d",
			os.date("%H:%M:%S"), math.floor(session / 60), session % 60)
		draw.SimpleText(status, "SCPArmory_RoN_Small", w - 36, 50, COL.faint, TEXT_ALIGN_RIGHT)

		draw.SimpleText("SCP ARMORY — SITE-19", "SCPArmory_RoN_Small", w - 26, 18, COL.dim, TEXT_ALIGN_RIGHT)
		draw.SimpleText(SCPArmory.FrUpper(jobName), "SCPArmory_RoN_Small", w - 26, 34, COL.faint, TEXT_ALIGN_RIGHT)

		-- Aide caméra sur l'écran de l'arme
		if mode == "modify" or mode == "attselect" then
			draw.SimpleText(T("GLISSER : PIVOTER   ·   MOLETTE : ZOOM   ·   CLIC MOLETTE : DÉPLACER"),
				"SCPArmory_RoN_Small", w * 0.63, h - 40, COL.faint, TEXT_ALIGN_CENTER)
		end

		-- Petit radar de surveillance, balayage continu (bas droite)
		local rx, ry, rr = w - 92, h - 96, 54
		surface.DrawCircle(rx, ry, rr, COL.red.r, COL.red.g, COL.red.b, 34)
		surface.DrawCircle(rx, ry, rr * 0.55, COL.red.r, COL.red.g, COL.red.b, 22)
		surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 26)
		surface.DrawRect(rx - rr, ry, rr * 2, 1)
		surface.DrawRect(rx, ry - rr, 1, rr * 2)

		-- Aiguille avec traînée
		local sweep = rt * 1.4
		for i = 0, 5 do
			local a = sweep - i * 0.07
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 70 - i * 11)
			surface.DrawLine(rx, ry, rx + math.cos(a) * rr, ry + math.sin(a) * rr)
		end
		surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 120)
		surface.DrawRect(rx - 1, ry - 1, 3, 3)
		draw.SimpleText("SURVEILLANCE // S-19", "SCPArmory_RoN_Small", rx, ry + rr + 8, COL.faint, TEXT_ALIGN_CENTER)
	end

	-- Fermeture en fondu (déploiement, ÉCHAP, bouton retour)
	local function CloseMenu()
		if frame.closing then return end
		frame.closing = true
		frame:AlphaTo(0, 0.14, 0, function()
			if IsValid(frame) then frame:Remove() end
		end)
	end

	-- ------------------------------------------------------ aperçu central

	local preview = vgui.Create("DModelPanel", frame)
	preview:SetPos(math.floor(ScrW() * 0.28), 0)
	preview:SetSize(math.ceil(ScrW() * 0.72), ScrH())
	preview:SetAnimated(true)
	preview:SetCursor("sizeall")

	-- Éclairage d'armurerie : ambiance sombre, lumière plongeante chaude,
	-- très léger rappel rouge sur un flanc
	preview:SetAmbientLight(Color(52, 54, 60))
	preview:SetDirectionalLight(BOX_TOP, Color(255, 244, 228))
	preview:SetDirectionalLight(BOX_FRONT, Color(92, 94, 102))
	preview:SetDirectionalLight(BOX_RIGHT, Color(70, 26, 22))

	-- Rotation du modèle à la souris (clic gauche ou droit maintenu),
	-- déplacement latéral au clic molette maintenu
	preview.OnMousePressed = function(s, mc)
		if mc == MOUSE_MIDDLE then
			s.panning = true
			s.lastPX, s.lastPY = input.GetCursorPos()
			s:MouseCapture(true)
			return
		end
		if mc ~= MOUSE_LEFT and mc ~= MOUSE_RIGHT then return end
		s.dragging = true
		s.lastX, s.lastY = input.GetCursorPos()
		s:MouseCapture(true)
	end
	preview.OnMouseReleased = function(s)
		s.dragging = false
		s.panning = false
		s:MouseCapture(false)
	end

	-- Cible caméra façon Gunsmith : vue plongeante d'établi + zoom + pan
	local function WeaponCamTarget()
		local c, size = preview.WepCenter, preview.WepSize
		if not c then return end
		local d = size * 1.0 * (preview.zoomCur or 1)
		local pos = c + Vector(-d * 0.30, d * 0.85, d * 0.55)
		local aim = c
		if preview.panOfs then
			pos = pos + preview.panOfs
			aim = aim + preview.panOfs
		end
		return pos, aim
	end

	preview.OnMouseWheeled = function(s, delta)
		if not s.CurIsWeapon then return end
		s.zoom = math.Clamp((s.zoom or 1) * (1 - delta * 0.12), 0.4, 2.2)
		return true
	end

	preview.Think = function(s)
		-- Rotation (clic gauche/droit maintenu)
		if s.dragging then
			local x, y = input.GetCursorPos()
			s.userYaw = (s.userYaw or 0) + (x - (s.lastX or x)) * 0.45
			s.userPitch = math.Clamp((s.userPitch or 0) + (y - (s.lastY or y)) * 0.25, -35, 35)
			s.lastX, s.lastY = x, y
		end

		-- Déplacement latéral au clic molette (écran arme)
		if s.panning and s.CurIsWeapon and s.WepCenter then
			local x, y = input.GetCursorPos()
			local dx = x - (s.lastPX or x)
			local dy = y - (s.lastPY or y)
			s.lastPX, s.lastPY = x, y

			local pos, aim = WeaponCamTarget()
			if pos then
				local ang = (aim - pos):Angle()
				local k = (s.WepSize or 40) * 0.0026 * (s.zoomCur or 1)
				local ofs = (s.panOfs or Vector(0, 0, 0)) - ang:Right() * (dx * k) + ang:Up() * (dy * k)
				local maxLen = (s.WepSize or 40) * 0.8
				if ofs:Length() > maxLen then ofs = ofs:GetNormalized() * maxLen end
				s.panOfs = ofs
			end
		end

		-- Caméra amortie façon Gunsmith : zoom lissé, glissement, flottement
		if s.CurIsWeapon and s.WepCenter then
			s.zoomCur = Lerp(math.Clamp(FrameTime() * 8, 0, 1), s.zoomCur or 1, s.zoom or 1)

			local pos, aim = WeaponCamTarget()
			if pos then
				local t = RealTime()
				local sz = s.WepSize or 40
				local drift = Vector(0, math.sin(t * 0.31) * sz * 0.012, math.sin(t * 0.23) * sz * 0.008)
				local fr = math.Clamp(FrameTime() * 6, 0, 1)
				s.camPos = LerpVector(fr, s.camPos or pos, pos + drift)
				s.camAim = LerpVector(fr, s.camAim or aim, aim)
				s:SetFOV(32)
				s:SetCamPos(s.camPos)
				s:SetLookAt(s.camAim)
			end
		end

		-- Profondeur : la caméra de l'opérateur suit légèrement la souris,
		-- la scène 3D (opérateur, socle, hologrammes) prend du relief
		if not s.CurIsWeapon then
			local dist = SCPArmory.Config.PreviewDistance or 120
			local target = Vector(dist, parX * 420, 55 - parY * 260)
			s.plyCam = LerpVector(math.Clamp(FrameTime() * 4, 0, 1), s.plyCam or target, target)
			s:SetCamPos(s.plyCam)
		end
	end

	preview.LayoutEntity = function(pnl, ent)
		if pnl.CurIsWeapon then
			ent:SetAngles(Angle(pnl.userPitch or 0, 30 + (pnl.userYaw or 0), 0))
		else
			pnl:RunAnimation()
			ent:SetAngles(Angle(0, math.sin(RealTime() * 0.3) * 6 - 8 + (pnl.userYaw or 0), 0))
		end
	end

	-- Arme principale bone-mergée dans les mains de l'aperçu
	local function ClearHeldWeapon()
		if IsValid(preview.HeldWep) then preview.HeldWep:Remove() end
		preview.HeldWep = nil
	end

	-- Modèles d'accessoires ARC9 posés sur l'arme de l'aperçu
	local function ClearPreviewAtts()
		for _, a in ipairs(preview.AttModels or {}) do
			if IsValid(a.mdl) then a.mdl:Remove() end
		end
		preview.AttModels = nil
	end

	frame.OnRemove = function()
		ClearHeldWeapon()
		ClearPreviewAtts()
		for _, hw in ipairs(preview.HoloWeps or {}) do
			if IsValid(hw.mdl) then hw.mdl:Remove() end
		end
	end

	preview.PostDrawModel = function(s, ent)
		if IsValid(s.HeldWep) then
			s.HeldWep:DrawModel()
		end

		if not s.AttModels then return end

		-- Placement des accessoires : même calcul qu'ARC9
		-- (os de l'emplacement + Pos/Ang du slot + offsets du modèle)
		ent:SetupBones()
		for _, a in ipairs(s.AttModels) do
			if IsValid(a.mdl) then
				-- Os mémorisé après la première recherche
				if a.boneId == nil then
					a.boneId = ent:LookupBone(a.slot.Bone or "") or false
				end
				local m = a.boneId and ent:GetBoneMatrix(a.boneId) or nil
				if m then
					local bpos, bang = m:GetTranslation(), m:GetAngles()
					local op = a.slot.Pos or vector_origin
					local oa = a.slot.Ang or angle_zero

					local apos = LocalToWorld(Vector(op[1], -op[2], op[3]), bang, bpos, bang)
					local aang = Angle(bang)

					local maoff = a.att.ModelAngleOffset
					aang:RotateAroundAxis(aang:Forward(), oa.r + (maoff and maoff.r or 0))
					aang:RotateAroundAxis(aang:Right(), oa.p + (maoff and maoff.p or 0))
					aang:RotateAroundAxis(aang:Up(), oa.y + (maoff and maoff.y or 0))

					if a.att.ModelOffset then
						local mo = a.att.ModelOffset * (a.slot.Scale or 1)
						apos = apos + aang:Forward() * mo.x + aang:Right() * mo.y + aang:Up() * mo.z
					end

					a.mdl:SetPos(apos)
					a.mdl:SetAngles(aang)
					a.mdl:SetupBones()
					a.mdl:DrawModel()
				end
			end
		end
	end

	local function SetPreview(mdl, isWeapon)
		bgWeapon = isWeapon
		if preview.CurModel == mdl and preview.CurIsWeapon == isWeapon then return end
		preview.CurModel = mdl
		preview.CurIsWeapon = isWeapon
		preview.userYaw, preview.userPitch = 0, 0
		ClearHeldWeapon()
		ClearPreviewAtts()
		preview:SetModel(mdl)

		local ent = preview:GetEntity()
		if not IsValid(ent) then return end

		if isWeapon then
			local mn, mx = ent:GetRenderBounds()
			preview.WepCenter = (mn + mx) * 0.5
			preview.WepSize = math.max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z, 8)
			preview.zoom = 1
			preview.zoomCur = 1.35 -- la caméra glisse en se rapprochant
			preview.panOfs = nil
			preview.camPos = nil
			preview.camAim = nil
		else
			preview.WepCenter = nil
			local dist = SCPArmory.Config.PreviewDistance or 120
			preview:SetFOV(30)
			preview:SetCamPos(Vector(dist, 0, 55))
			preview:SetLookAt(Vector(0, 0, 42))

			-- Belle posture d'accueil (bras croisés si le modèle la possède)
			preview.Posed = false
			for _, sq in ipairs({ SCPArmory.Config.PreviewPose or "pose_standing_02",
				"pose_standing_02", "pose_standing_01", "idle_all_01" }) do
				local seq = ent:LookupSequence(sq)
				if seq and seq > 0 then
					ent:ResetSequence(seq)
					preview.Posed = (sq ~= "idle_all_01")
					break
				end
			end
		end
	end

	-- Grand plan via image imgur quand l'objet en a une (sinon rendu 3D)
	local imagePanel = vgui.Create("DPanel", frame)
	imagePanel:SetPos(math.floor(ScrW() * 0.28), 0)
	imagePanel:SetSize(math.ceil(ScrW() * 0.72), ScrH())
	imagePanel:SetMouseInputEnabled(false)
	imagePanel:SetVisible(false)
	imagePanel.Paint = function(s, w, h)
		if s.URL then
			SCPArmory.DrawWebIcon(s.URL, w * 0.08, h * 0.16, w * 0.76, h * 0.56)
		end
	end

	local function ShowImage(url)
		if not imagePanel:IsVisible() or imagePanel.URL ~= url then
			imagePanel:SetAlpha(0)
			imagePanel:AlphaTo(255, 0.15, 0)
		end
		imagePanel.URL = url
		imagePanel:SetVisible(true)
		preview:SetVisible(false)
	end

	local function ShowPreview()
		imagePanel:SetVisible(false)
		preview:SetVisible(true)
	end

	-- Reflète l'équipement choisi sur l'aperçu de l'opérateur :
	-- bodygroups gilet/casque + arme principale bone-mergée dans les mains
	local function DecorateOperator()
		local ent = preview:GetEntity()
		if not IsValid(ent) or preview.CurIsWeapon then return end

		SCPArmory.ApplyBodygroups(ent, selection)

		ClearHeldWeapon()

		-- Bras croisés : pas d'arme en main sur la pose d'accueil
		if preview.Posed then return end

		local item = SCPArmory.GetItem("primary", selection.primary)
		if not HasModel(item) then return end

		local prop = ClientsideModel(item.model, RENDERGROUP_OPAQUE)
		if not IsValid(prop) then return end

		-- Sans os de main compatible, le bonemerge collerait l'arme aux pieds
		if not prop:LookupBone("ValveBiped.Bip01_R_Hand") then
			prop:Remove()
			return
		end

		prop:SetParent(ent)
		prop:AddEffects(EF_BONEMERGE)
		prop:SetNoDraw(true)
		preview.HeldWep = prop
	end

	-- Pose les modèles des accessoires équipés sur l'arme de l'aperçu.
	-- Les Pos/Ang des emplacements ARC9 sont exprimés dans le repère du
	-- viewmodel : l'aperçu ARC9 affiche donc le viewmodel de l'arme.
	local function BuildPreviewAtts(item)
		ClearPreviewAtts()
		if not (item and item.class and SCPArmory.ARC9Bridge.IsARC9Class(item.class)) then return end
		if not (ARC9 and istable(ARC9.Attachments)) then return end

		local ent = preview:GetEntity()
		local swep = weapons.Get(item.class)
		if not (IsValid(ent) and swep and istable(swep.Attachments)) then return end

		local list = {}
		for idx, attId in pairs(attSel[curWeaponKey] or {}) do
			local slottbl = swep.Attachments[idx]
			local atttbl = ARC9.Attachments[attId]
			if istable(slottbl) and istable(atttbl) and isstring(atttbl.Model)
				and isstring(slottbl.Bone) and ent:LookupBone(slottbl.Bone) then
				local mdl = ClientsideModel(atttbl.Model, RENDERGROUP_OPAQUE)
				if IsValid(mdl) then
					mdl:SetNoDraw(true)
					if slottbl.Scale then mdl:SetModelScale(slottbl.Scale, 0) end
					if atttbl.ModelSkin then mdl:SetSkin(atttbl.ModelSkin) end
					if isstring(atttbl.ModelBodygroups) then mdl:SetBodyGroups(atttbl.ModelBodygroups) end
					table.insert(list, { mdl = mdl, slot = slottbl, att = atttbl })
				end
			end
		end

		if #list > 0 then preview.AttModels = list end
	end

	-- Meilleur modèle pour l'aperçu d'une arme ARC9 : son viewmodel
	-- (les accessoires s'y posent), sinon le world model
	local function BestWeaponModel(item)
		if item and item.class and SCPArmory.ARC9Bridge.IsARC9Class(item.class) then
			local swep = weapons.Get(item.class)
			local vm = swep and swep.ViewModel
			if isstring(vm) and vm ~= "" and file.Exists(vm, "GAME") then
				return vm
			end
		end
		return HasModel(item) and item.model or nil
	end

	local function RefreshPreview()
		if mode == "modify" or mode == "attselect" then
			local item = CurWeaponItem()
			local mdl = BestWeaponModel(item)
			if mdl then
				-- Priorité au 3D avec accessoires posés (rotation à la souris) ;
				-- l'image imgur ne sert que si aucun modèle n'est disponible
				ShowPreview()
				SetPreview(mdl, true)
				BuildPreviewAtts(item)
				return
			end
			if item and item.icon then
				bgWeapon = true
				ShowImage(item.icon)
				return
			end
			ShowPreview()
		elseif mode == "select" and hoverItem then
			if hoverItem.icon then
				bgWeapon = true
				ShowImage(hoverItem.icon)
				return
			end
			if HasModel(hoverItem) then
				ShowPreview()
				SetPreview(hoverItem.model, true)
				return
			end
		end
		ShowPreview()
		SetPreview(plyModel, false)
		DecorateOperator()
	end

	SetPreview(plyModel, false)

	-- Accès au panneau de configuration (superadmin) — créé après l'aperçu
	-- pour rester cliquable et visible au-dessus
	if LocalPlayer():IsSuperAdmin() then
		local cfgBtn = vgui.Create("DButton", frame)
		cfgBtn:SetPos(ScrW() - 176, 52)
		cfgBtn:SetSize(150, 26)
		cfgBtn:SetText("")
		cfgBtn.Paint = function(s, w, h)
			rowBG.a = s:IsHovered() and 44 or 22
			draw.RoundedBox(0, 0, 0, w, h, rowBG)
			draw.SimpleText(T("CONFIGURATION"), "SCPArmory_RoN_Label", w / 2, h / 2,
				s:IsHovered() and COL.text or COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		cfgBtn.DoClick = function()
			-- L'armurerie se ferme d'abord : le panneau de configuration ne
			-- peut pas modifier des objets affichés par un menu encore ouvert
			SCPArmory.CloseLoadoutMenu()
			if SCPArmory.OpenConfigMenu then SCPArmory.OpenConfigMenu() end
		end
	end

	-- --------------------------------------------------- colonne de gauche

	-- Largeur de colonne adaptative (petites résolutions et ultrawide)
	local colX, colY = 48, 34
	local colW = math.Clamp(math.floor(ScrW() * 0.22), 320, 420)
	local colH = ScrH() - colY * 2
	local bottomH = 158
	local titleH = 112

	local column = vgui.Create("DPanel", frame)
	column:SetPos(colX, colY)
	column:SetSize(colW, colH)
	-- Couleur réutilisée chaque frame (pas d'allocation dans le Paint)
	local redAnim = Color(COL.red.r, COL.red.g, COL.red.b, 255)

	column.Paint = function(s, w)
		-- MW : panneau sombre anguleux à liseré, avec ombres portées ;
		-- RON : rien (le dégradé sombre du fond suffit, fidèle au jeu)
		if uiStyle == "mw" then
			local dc = DisableClipping(true)
			draw.RoundedBox(18, -4, 2, w + 40, s:GetTall() + 38, shadowB)
			draw.RoundedBox(14, -12, -8, w + 34, s:GetTall() + 30, shadowA)
			surface.SetDrawColor(COL.card)
			surface.DrawRect(-18, -16, w + 34, s:GetTall() + 32)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(-18, -16, w + 34, 2)
			DisableClipping(dc)
		end

		-- Balayage animé du titre à chaque changement d'écran
		local tf = Ease((RealTime() - (s.animT or 0)) / 0.35)
		redAnim.a = 255 * tf
		local redCol = redAnim
		local barW = math.Round(20 * tf)

		if mode == "overview" then
			DrawSpacedText("LOADOUT", "SCPArmory_RoN_Huge", 0, 0, COL.text, 8)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 62, barW, 3)
			DrawSpacedText(T("PRÉPARATION AU DÉPLOIEMENT"), "SCPArmory_RoN_Label", 28, 58, redCol, 2)
			draw.SimpleText(SCPArmory.FrUpper(jobName) .. " — " .. LocalPlayer():Nick(), "SCPArmory_RoN_NameSm", 0, 82, COL.text)
		elseif mode == "modify" or mode == "attselect" then
			local item = CurWeaponItem()
			DrawSpacedText(SCPArmory.FrUpper(item and item.name or T("— AUCUNE —")), "SCPArmory_RoN_Big", 0, 8, COL.text, 3)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 52, barW, 3)
			DrawSpacedText(mode == "modify" and T("MODIFIER L'ARME") or T("CHOIX D'ACCESSOIRE"),
				"SCPArmory_RoN_Label", 28, 48, redCol, 2)
			draw.SimpleText(T(SlotByKey(curWeaponKey).label), "SCPArmory_RoN_Label", 0, 82, COL.dim)
		elseif mode == "section" then
			DrawSpacedText(T("APPARENCE"), "SCPArmory_RoN_Big", 0, 8, COL.text, 3)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 52, barW, 3)
			DrawSpacedText(T("APPARENCE DE L'OPÉRATEUR"), "SCPArmory_RoN_Label", 28, 48, redCol, 2)
		else
			local title = (mode == "bgselect") and SCPArmory.FrUpper(bgSlot and bgSlot.name or "")
				or (selectSlot and T(selectSlot.label) or "")
			DrawSpacedText(title, "SCPArmory_RoN_Big", 0, 8, COL.text, 3)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 52, barW, 3)
			DrawSpacedText(mode == "bgselect" and T("APPARENCE DE L'OPÉRATEUR") or T("SÉLECTION D'ÉQUIPEMENT"),
				"SCPArmory_RoN_Label", 28, 48, redCol, 2)
		end

		-- La ligne de séparation se déploie de gauche à droite
		surface.SetDrawColor(COL.line)
		surface.DrawRect(0, titleH - 6, w * tf, 1)
	end

	-- Balayage lumineux unique qui parcourt la colonne au changement d'écran
	column.PaintOver = function(s, w, h)
		local t = (RealTime() - (s.animT or 0)) / 0.4
		if t >= 1 then return end
		local y = Ease(t) * h
		for i = 0, 5 do
			surface.SetDrawColor(255, 255, 255, 9 - i * 1.4)
			surface.DrawRect(0, y - i * 6, w, 4)
		end
	end

	local scroll = vgui.Create("DScrollPanel", column)
	scroll:SetPos(0, titleH)
	scroll:SetSize(colW, colH - titleH - bottomH)

	local vbar = scroll:GetVBar()
	vbar:SetWide(4)
	vbar.Paint = function() end
	vbar.btnUp.Paint = function() end
	vbar.btnDown.Paint = function() end
	vbar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, COL.faint) end

	local bottom = vgui.Create("DPanel", column)
	bottom:SetPos(0, colH - bottomH)
	bottom:SetSize(colW, bottomH)

	-- ------------------------------------- panneau d'information à droite

	local infoW = 330
	local infoPanel = vgui.Create("DPanel", frame)
	infoPanel:SetPos(ScrW() - infoW - 26, 64)
	infoPanel:SetSize(infoW, 430)
	infoPanel:SetVisible(false)

	local infoDesc = vgui.Create("DLabel", infoPanel)
	infoDesc:SetPos(16, 66)
	infoDesc:SetSize(infoW - 32, 70)
	infoDesc:SetFont("SCPArmory_RoN_Small")
	infoDesc:SetTextColor(COL.dim)
	infoDesc:SetWrap(true)
	infoDesc:SetContentAlignment(7)
	infoDesc:SetText("")
	infoDesc:SetMouseInputEnabled(false)

	infoPanel.Paint = function(_, w, h)
		surface.SetDrawColor(COL.panel)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(COL.red)
		surface.DrawRect(0, 0, w, 2)

		local item = CurWeaponItem()
		if not item then
			draw.SimpleText(T("AUCUNE ARME SÉLECTIONNÉE"), "SCPArmory_RoN_Label", 16, 16, COL.faint)
			return
		end

		draw.SimpleText(T(SlotByKey(curWeaponKey).label), "SCPArmory_RoN_Label", 16, 14, COL.red)
		DrawSpacedText(SCPArmory.FrUpper(item.name), "SCPArmory_RoN_Name", 16, 30, COL.text, 1)

		DrawSpacedText(T("ACCESSOIRES"), "SCPArmory_RoN_Label", 16, 148, COL.dim, 2)
		surface.SetDrawColor(COL.line)
		surface.DrawRect(16, 166, w - 32, 1)

		local y = 176
		if item.class and SCPArmory.ARC9Bridge.IsARC9Class(item.class) then
			local slots = SCPArmory.ARC9Bridge.GetSlots(item.class)
			if #slots == 0 then
				draw.SimpleText(T("AUCUN EMPLACEMENT D'ACCESSOIRE"), "SCPArmory_RoN_Small", 16, y, COL.faint)
			end
			-- Lignes façon Ready or Not : silhouette de l'accessoire à
			-- gauche, emplacement en petit au-dessus du nom
			for _, slot in ipairs(slots) do
				local installed = attSel[curWeaponKey][slot.index]
				local name = installed and SCPArmory.FrUpper(SCPArmory.ARC9Bridge.AttName(installed)) or "—"

				if installed and DrawAttIcon(installed, 16, y, 44, 28, COL.soft) then
					-- icône dessinée
				else
					draw.SimpleText("—", "SCPArmory_RoN_Small", 38, y + 8,
						COL.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				draw.SimpleText(slot.name, "SCPArmory_RoN_Small", 70, y, COL.red)
				draw.SimpleText(name, "SCPArmory_RoN_Small", 70, y + 14, installed and COL.text or COL.faint)
				surface.SetDrawColor(COL.lineF)
				surface.DrawRect(16, y + 30, w - 32, 1)
				y = y + 36
				if y > h - 32 then break end
			end
		else
			draw.SimpleText(T("ARME NON ARC9 — PAS DE RAIL"), "SCPArmory_RoN_Small", 16, y, COL.faint)
		end
	end

	-- Le panneau ÉQUIPEMENT ACTUEL du thème légion (façon référence) est
	-- construit plus bas, après RebuildColumn, pour pouvoir naviguer.

	-- ------------------------------------------------------ bas de colonne

	local descLabel = vgui.Create("DLabel", bottom)
	descLabel:SetPos(0, 22)
	descLabel:SetSize(colW - 10, 66)
	descLabel:SetFont("SCPArmory_RoN_Small")
	descLabel:SetTextColor(COL.dim)
	descLabel:SetWrap(true)
	descLabel:SetContentAlignment(7)
	descLabel:SetText("")
	descLabel:SetMouseInputEnabled(false)

	bottom.Paint = function(_, w, h)
		surface.SetDrawColor(COL.line)
		surface.DrawRect(0, 0, w, 1)

		if mode == "select" then
			local item = hoverItem
			if item then
				draw.SimpleText(SCPArmory.FrUpper(item.name), "SCPArmory_RoN_Label", 0, 8, COL.text)

				local infos = {}
				if item.stats then
					if item.stats.degats then table.insert(infos, T("DÉGÂTS") .. " " .. item.stats.degats) end
					if item.stats.cadence then table.insert(infos, T("CADENCE") .. " " .. item.stats.cadence) end
					if item.stats.controle then table.insert(infos, T("CONTRÔLE") .. " " .. item.stats.controle) end
					if item.stats.precision then table.insert(infos, T("PRÉCISION") .. " " .. item.stats.precision) end
				end
				if item.armor then table.insert(infos, T("ARMURE") .. " +" .. item.armor) end
				table.insert(infos, string.format("%.1f KG", item.weight or 0))
				draw.SimpleText(table.concat(infos, "   ·   "), "SCPArmory_RoN_Small", 0, 92, COL.faint)
			end
			return
		end

		if mode == "attselect" then
			if hoverAtt then
				draw.SimpleText(hoverAtt.name, "SCPArmory_RoN_Label", 0, 8, COL.text)
				draw.SimpleText(hoverAtt.cat, "SCPArmory_RoN_Label", w - 10, 8, COL.red, TEXT_ALIGN_RIGHT)
			end
			return
		end

		-- Vues LOADOUT et MODIFY : le résumé du chargement
		-- (recalculé au plus toutes les 0.15 s, pas à chaque frame)
		local s = bottom
		if not s.statsNext or RealTime() > s.statsNext then
			s.statsCache = SCPArmory.ComputeStats(selection)
			s.statsNext = RealTime() + 0.15
		end
		local stats = s.statsCache

		draw.SimpleText(T("CHARGEMENT"), "SCPArmory_RoN_Label", 0, 8, COL.dim)
		draw.SimpleText(T(stats.class), "SCPArmory_RoN_Label", w - 10, 8, COL.red, TEXT_ALIGN_RIGHT)

		local rows = {
			{ T("POIDS"), string.format("%.1f KG", stats.weight), stats.weight / 30 },
			{ T("MOBILITÉ"), stats.mobility .. " %", stats.mobility / 110 },
			{ T("ARMURE"), stats.armor .. " PTS", stats.armor / SCPArmory.Config.MaxArmor },
		}

		-- Les barres glissent en douceur vers leur nouvelle valeur
		s.barAnim = s.barAnim or {}

		local y = 30
		for i, row in ipairs(rows) do
			local target = math.Clamp(row[3], 0, 1)
			s.barAnim[i] = Lerp(FrameTime() * 9, s.barAnim[i] or 0, target)

			draw.SimpleText(row[1], "SCPArmory_RoN_Small", 0, y, COL.dim)
			draw.SimpleText(row[2], "SCPArmory_RoN_Small", w - 10, y, COL.text, TEXT_ALIGN_RIGHT)
			surface.SetDrawColor(COL.lineF)
			surface.DrawRect(0, y + 16, w - 10, 2)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, y + 16, s.barAnim[i] * (w - 10), 2)

			y = y + 24
		end
	end

	local backW = 118
	local deployBtn = vgui.Create("DButton", bottom)
	deployBtn:SetPos(0, bottomH - 46)
	deployBtn:SetSize(colW - backW - 10, 40)
	deployBtn:SetText("")
	deployBtn.Paint = function(s, w, h)
		s.hf = Lerp(FrameTime() * 10, s.hf or 0, s:IsHovered() and 1 or 0)
		local down = s:IsDown()

		-- Respiration discrète au repos
		local pulse = (1 - s.hf) * math.sin(RealTime() * 2.2) * 7

		btnBG.r = math.Clamp(Lerp(s.hf, COL.red.r, COL.redHi.r) + pulse, 0, 255)
		btnBG.g = math.Clamp(Lerp(s.hf, COL.red.g, COL.redHi.g) + pulse * 0.3, 0, 255)
		btnBG.b = math.Clamp(Lerp(s.hf, COL.red.b, COL.redHi.b) + pulse * 0.3, 0, 255)

		-- Angles arrondis en thème MW, coupe droite RoN
		local br = (uiStyle == "mw") and 8 or 0
		draw.RoundedBox(br, 0, 0, w, h, btnBG)

		-- Relief : reflet permanent en tête, renforcé au survol
		mwGloss.a = 12 + 22 * s.hf
		draw.RoundedBox(br, 0, 0, w, math.floor(h / 2), mwGloss)

		-- Éclat qui balaie le bouton par intervalles
		local sweep = (RealTime() * 0.35) % 1
		if sweep < 0.2 then
			surface.SetDrawColor(255, 255, 255, 24)
			surface.DrawRect((w + 60) * (sweep / 0.2) - 30, 2, 24, h - 4)
		end

		-- Liseré blanc qui s'allume au survol (style plat RoN)
		if br == 0 and s.hf > 0.02 then
			surface.SetDrawColor(255, 255, 255, 60 * s.hf)
			surface.DrawOutlinedRect(3, 3, w - 6, h - 6, 1)
		end

		-- Enfoncé : le bouton s'assombrit et le texte descend d'un pixel
		if down then
			btnPress.a = 60
			draw.RoundedBox(br, 0, 0, w, h, btnPress)
		end

		-- Le libellé glisse vers la gauche au survol, chevrons à droite
		local label = T("DÉPLOYER")
		surface.SetFont("SCPArmory_RoN_Btn")
		local tw = surface.GetTextSize(label)
		local ty = h / 2 + (down and 1 or 0)
		draw.SimpleText(label, "SCPArmory_RoN_Btn", w / 2 - 9 * s.hf, ty, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		if s.hf > 0.05 then
			chevCol.a = 255 * s.hf
			local cx = w / 2 - 9 * s.hf + tw / 2 + 8 + math.sin(RealTime() * 6) * 2
			draw.SimpleText("»", "SCPArmory_RoN_Btn", cx, ty - 1, chevCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		-- Flash au clic
		if s.flashT then
			local fa = 1 - (RealTime() - s.flashT) / 0.25
			if fa > 0 then
				flashBG.a = 170 * fa
				draw.RoundedBox(br, 0, 0, w, h, flashBG)
			end
		end
	end
	-- Envoi du déploiement, partagé entre le bouton de colonne et le grand
	-- bouton de l'écran killstreak MW
	local function DoDeploy()
		net.Start("SCPArmory_Apply")
		for _, slot in ipairs(SCPArmory.Slots) do
			net.WriteString(selection[slot.key] or "none")
		end
		for _, wkey in ipairs(WEAPON_KEYS) do
			local map = attSel[wkey] or {}
			net.WriteUInt(math.min(table.Count(map), 63), 6)
			for idx, attId in pairs(map) do
				net.WriteUInt(idx, 6)
				net.WriteString(attId)
			end
		end

		-- Apparence : bodygroups personnalisés
		local bgMap = selection.bg or {}
		net.WriteUInt(math.min(table.Count(bgMap), 24), 5)
		local sent = 0
		for name, val in pairs(bgMap) do
			if sent >= 24 then break end
			net.WriteString(name)
			net.WriteUInt(math.Clamp(val, 0, 31), 5)
			sent = sent + 1
		end

		net.SendToServer()

		SaveSelection(selection, attSel)
		surface.PlaySound("items/ammo_pickup.wav")

		-- Déployer referme l'armurerie (en fondu)
		CloseMenu()
	end

	deployBtn.DoClick = function(s)
		s.flashT = RealTime()
		DoDeploy()
	end
	HoverCue(deployBtn)

	local RebuildColumn

	local function GoBack()
		if mode == "attselect" then
			mode = "modify"
			attSlot = nil
		elseif mode == "bgselect" then
			mode = bgReturn
			bgSlot = nil
		elseif mode == "select" then
			mode = selectReturn
			selectSlot = nil
		elseif mode == "modify" then
			mode = modifyReturn
		elseif mode == "section" then
			mode = "overview"
		else
			CloseMenu()
			return
		end
		RebuildColumn()
	end

	frame.Think = function()
		-- Fermeture / retour via ÉCHAP, comme le "BACK ESC" de RoN
		if gui.IsGameUIVisible() then
			gui.HideGameUI()
			GoBack()
		end

		-- La colonne flotte en couche intermédiaire (parallaxe positionnel :
		-- la souris suit la vraie position, les clics restent exacts)
		column:SetPos(colX - math.Round(parX * 520), colY - math.Round(parY * 380))
	end

	local backBtn = vgui.Create("DButton", bottom)
	backBtn:SetPos(colW - backW, bottomH - 46)
	backBtn:SetSize(backW, 40)
	backBtn:SetText("")
	backBtn.Paint = function(s, w, h)
		s.hf = Lerp(FrameTime() * 10, s.hf or 0, s:IsHovered() and 1 or 0)
		local down = s:IsDown()

		local br = (uiStyle == "mw") and 8 or 0
		if br > 0 then
			-- MW : liseré arrondi (boîte claire puis fond sombre en creux)
			mwEdge.r = Lerp(s.hf, COL.line.r, COL.text.r)
			mwEdge.g = Lerp(s.hf, COL.line.g, COL.text.g)
			mwEdge.b = Lerp(s.hf, COL.line.b, COL.text.b)
			mwEdge.a = 255
			draw.RoundedBox(br, 0, 0, w, h, mwEdge)
			draw.RoundedBox(br - 1, 1, 1, w - 2, h - 2, mwDark)
			backBG.a = 12 + 30 * s.hf
			draw.RoundedBox(br - 1, 1, 1, w - 2, h - 2, backBG)
		else
			backBG.a = 18 + 34 * s.hf
			draw.RoundedBox(0, 0, 0, w, h, backBG)
			surface.SetDrawColor(
				Lerp(s.hf, COL.line.r, COL.text.r),
				Lerp(s.hf, COL.line.g, COL.text.g),
				Lerp(s.hf, COL.line.b, COL.text.b), 255)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		if down then
			btnPress.a = 50
			draw.RoundedBox(br, 0, 0, w, h, btnPress)
		end

		-- Chevron qui glisse vers la gauche au survol
		local ty = h / 2 + (down and 1 or 0)
		if s.hf > 0.05 then
			chevCol.a = 255 * s.hf
			draw.SimpleText("«", "SCPArmory_RoN_Btn", 10 - 3 * s.hf, ty - 1, chevCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		draw.SimpleText(T("RETOUR"), "SCPArmory_RoN_Btn", w / 2 - 12 + 3 * s.hf, ty, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("ESC", "SCPArmory_RoN_Small", w - 10, ty, COL.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	backBtn.DoClick = GoBack
	HoverCue(backBtn)

	-- --------------------------------------------- construction de la liste

	local function AddSection(label)
		label = T(label)
		local pnl = scroll:Add("DPanel")
		pnl:Dock(TOP)
		pnl:DockMargin(0, 10, 10, 4)
		pnl:SetTall(20)
		pnl.Paint = function(_, w, h)
			DrawSpacedText(label, "SCPArmory_RoN_Label", 0, 2, COL.faint, 2)
			surface.SetDrawColor(COL.lineF)
			surface.DrawRect(0, h - 1, w, 1)
		end
	end

	local function AddNote(text)
		text = T(text)
		local pnl = scroll:Add("DPanel")
		pnl:Dock(TOP)
		pnl:DockMargin(0, 4, 10, 0)
		pnl:SetTall(30)
		pnl.Paint = function()
			draw.SimpleText(text, "SCPArmory_RoN_Small", 0, 8, COL.faint)
		end
	end

	-- Entrée de la vue d'ensemble : image de profil + catégorie + nom
	local function AddOverviewEntry(slot, withImage)
		local item = SCPArmory.GetItem(slot.pool, selection[slot.key])
		local tall = withImage and 96 or 48

		local btn = scroll:Add("DButton")
		btn:Dock(TOP)
		btn:DockMargin(0, 0, 10, rowGap)
		btn:SetTall(tall)
		btn:SetText("")

		if withImage and item and not item.icon and HasModel(item) then
			local icon = vgui.Create("DModelPanel", btn)
			icon:SetPos(8, 4)
			icon:SetSize(170, 46)
			icon:SetModel(item.model)
			icon:SetMouseInputEnabled(false)
			FitModelSide(icon)
		end

		btn.Paint = function(s, w, h)
			local hov = s:IsHovered()
			s.hf = Lerp(FrameTime() * 10, s.hf or 0, hov and 1 or 0)

			RowChrome(s.hf, w, h)

			if withImage and item and item.icon then
				SCPArmory.DrawWebIcon(item.icon, 8, 3, 170, 46)
			end

			-- Le texte glisse légèrement vers la droite au survol
			local ox = 10 + math.Round(s.hf * 6)

			if withImage then
				draw.SimpleText(T(slot.label), "SCPArmory_RoN_Label", ox, 52, COL.dim)
				DrawSpacedText(SCPArmory.FrUpper(item and item.name or T("— AUCUN —")), "SCPArmory_RoN_Name", ox, 66,
					hov and COL.text or COL.soft, 1)
				if item and item.ammo and item.ammo[1] then
					draw.SimpleText("×" .. item.ammo[1].amount, "SCPArmory_RoN_Small", w - 12, 70,
						COL.faint, TEXT_ALIGN_RIGHT)
				end
			else
				draw.SimpleText(T(slot.label), "SCPArmory_RoN_Label", ox, 6, COL.dim)
				DrawSpacedText(SCPArmory.FrUpper(item and item.name or T("— AUCUN —")), "SCPArmory_RoN_NameSm", ox, 22,
					hov and COL.text or COL.soft, 1)
			end
		end

		btn.DoClick = function()
			surface.PlaySound("ui/buttonclick.wav")
			if slot.key == "primary" or slot.key == "secondary" then
				-- Comme dans RoN : l'arme principale/secondaire ouvre MODIFY WEAPON
				modifyReturn = (mode == "section") and "section" or mode
				mode = "modify"
				curWeaponKey = slot.key
			else
				selectReturn = (mode == "section") and "section" or "overview"
				mode = "select"
				selectSlot = slot
				hoverItem = item
			end
			RebuildColumn()
		end
	end

	-- Ligne de la vue de sélection d'objet
	local function AddSelectRow(item)
		local equipped = selection[selectSlot.key] == item.id

		local btn = scroll:Add("DButton")
		btn:Dock(TOP)
		btn:DockMargin(0, 0, 10, rowGap)
		btn:SetTall(58)
		btn:SetText("")

		if not item.icon and HasModel(item) then
			local icon = vgui.Create("DModelPanel", btn)
			icon:SetPos(6, 9)
			icon:SetSize(96, 40)
			icon:SetModel(item.model)
			icon:SetMouseInputEnabled(false)
			FitModelSide(icon)
		end

		btn.Paint = function(s, w, h)
			local hov = s:IsHovered()
			s.hf = Lerp(FrameTime() * 10, s.hf or 0, hov and 1 or 0)

			RowChrome(s.hf, w, h)
			if equipped then
				surface.SetDrawColor(COL.red)
				surface.DrawRect(0, 3, 3, h - 6)
			end

			if item.icon then
				SCPArmory.DrawWebIcon(item.icon, 6, 9, 96, 40)
			end

			local nameCol = (equipped or hov) and COL.text or COL.soft
			local ox = 112 + math.Round(s.hf * 6)
			DrawSpacedText(SCPArmory.FrUpper(item.name), "SCPArmory_RoN_NameSm", ox, 10, nameCol, 1)

			draw.SimpleText(string.format("%.1f KG", item.weight or 0), "SCPArmory_RoN_Small", ox, 32, COL.faint)
			if item.ammo and item.ammo[1] then
				draw.SimpleText("×" .. item.ammo[1].amount, "SCPArmory_RoN_Small", w - 12, 32,
					COL.faint, TEXT_ALIGN_RIGHT)
			end
		end

		btn.OnCursorEntered = function()
			hoverItem = item
			RefreshPreview()
		end

		btn.DoClick = function()
			hoverItem = item

			if selection[selectSlot.key] ~= item.id then
				selection[selectSlot.key] = item.id
				-- Changer d'arme remet ses accessoires à zéro
				if attSel[selectSlot.key] then attSel[selectSlot.key] = {} end
			end

			mode = selectReturn
			selectSlot = nil
			surface.PlaySound("ui/buttonclick.wav")
			RebuildColumn()
		end
	end

	-- En-tête « retour » des vues de sélection
	local function AddBackHeader(label, onClick)
		local head = scroll:Add("DButton")
		head:Dock(TOP)
		head:DockMargin(0, 0, 10, 6)
		head:SetTall(54)
		head:SetText("")
		head.Paint = function(s, _, h)
			draw.SimpleText(T("‹  RETOUR"), "SCPArmory_RoN_Label", 0, 4,
				s:IsHovered() and COL.text or COL.dim)
			DrawSpacedText(label, "SCPArmory_RoN_Name", 0, 22, COL.text, 2)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, h - 2, 20, 2)
		end
		head.DoClick = function()
			surface.PlaySound("ui/buttonclick.wav")
			onClick()
		end
	end

	-- Vue MODIFY WEAPON : onglets, arme, emplacements d'accessoires
	local function BuildModify()
		-- Onglets PRIMAIRE / SECONDAIRE, comme les tabs PRIMARY / SIDEARM
		local tabs = scroll:Add("DPanel")
		tabs:Dock(TOP)
		tabs:DockMargin(0, 0, 10, 8)
		tabs:SetTall(34)
		tabs.Paint = function(_, w, h)
			surface.SetDrawColor(COL.lineF)
			surface.DrawRect(0, h - 1, w, 1)
		end

		local tabW = math.floor(colW / 2)
		for i, wkey in ipairs(WEAPON_KEYS) do
			local tab = vgui.Create("DButton", tabs)
			tab:SetPos((i - 1) * tabW, 0)
			tab:SetSize(tabW - 6, 33)
			tab:SetText("")
			tab.Paint = function(s, w, h)
				local active = (curWeaponKey == wkey)
				DrawSpacedText(wkey == "primary" and T("PRINCIPALE") or T("SECONDAIRE"), "SCPArmory_RoN_Label",
					10, 9, active and COL.text or (s:IsHovered() and COL.soft or COL.dim), 2)
				if active then
					surface.SetDrawColor(COL.red)
					surface.DrawRect(0, h - 2, w, 2)
				end
			end
			tab.DoClick = function()
				if curWeaponKey ~= wkey then
					curWeaponKey = wkey
					surface.PlaySound("ui/buttonclick.wav")
					RebuildColumn()
				end
			end
		end

		local slotDef = SlotByKey(curWeaponKey)
		local item = CurWeaponItem()

		-- Ligne de l'arme : cliquer pour la remplacer
		local wbtn = scroll:Add("DButton")
		wbtn:Dock(TOP)
		wbtn:DockMargin(0, 0, 10, rowGap)
		wbtn:SetTall(62)
		wbtn:SetText("")
		wbtn.Paint = function(s, w, h)
			RowChrome(s:IsHovered() and 1 or 0, w, h)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 3, 3, h - 6)
			draw.SimpleText(T(slotDef.label) .. "  —  " .. T("CHANGER D'ARME"), "SCPArmory_RoN_Label", 12, 8,
				s:IsHovered() and COL.soft or COL.dim)
			DrawSpacedText(SCPArmory.FrUpper(item and item.name or T("— AUCUNE —")), "SCPArmory_RoN_Name", 12, 26,
				s:IsHovered() and COL.text or COL.soft, 1)
		end
		wbtn.DoClick = function()
			mode = "select"
			selectSlot = slotDef
			selectReturn = "modify"
			hoverItem = item
			surface.PlaySound("ui/buttonclick.wav")
			RebuildColumn()
		end

		if not item then
			AddNote("SÉLECTIONNEZ D'ABORD UNE ARME")
			return
		end

		if not (item.class and SCPArmory.ARC9Bridge.IsARC9Class(item.class)) then
			AddNote("ARME NON ARC9 — AUCUN ACCESSOIRE DISPONIBLE")
			return
		end

		local slots = SCPArmory.ARC9Bridge.GetSlots(item.class)
		if #slots == 0 then
			AddNote("CETTE ARME N'A AUCUN EMPLACEMENT D'ACCESSOIRE")
			return
		end

		for _, aslot in ipairs(slots) do
			local btn = scroll:Add("DButton")
			btn:Dock(TOP)
			btn:DockMargin(0, 0, 10, rowGap)
			btn:SetTall(52)
			btn:SetText("")
			btn.Paint = function(s, w, h)
				local hov = s:IsHovered()
				s.hf = Lerp(FrameTime() * 10, s.hf or 0, hov and 1 or 0)
				local installed = attSel[curWeaponKey][aslot.index]
				local name = installed and SCPArmory.FrUpper(SCPArmory.ARC9Bridge.AttName(installed)) or T("—  VIDE  —")

				RowChrome(s.hf, w, h)

				local ox = 12 + math.Round(s.hf * 6)
				draw.SimpleText(aslot.name, "SCPArmory_RoN_Label", ox, 6, COL.dim)
				DrawSpacedText(name, "SCPArmory_RoN_NameSm", ox, 24,
					installed and (hov and COL.text or COL.soft) or COL.faint, 1)

				-- Silhouette de l'accessoire posé (icône du menu spawn)
				if installed then
					DrawAttIcon(installed, w - 76, 8, 62, 36, hov and COL.text or COL.soft)
				end
			end
			btn.DoClick = function()
				mode = "attselect"
				attSlot = aslot
				hoverAtt = nil
				surface.PlaySound("ui/buttonclick.wav")
				RebuildColumn()
			end
		end

		if next(attSel[curWeaponKey]) ~= nil then
			local clean = scroll:Add("DButton")
			clean:Dock(TOP)
			clean:DockMargin(0, 10, 10, 0)
			clean:SetTall(32)
			clean:SetText("")
			clean.Paint = function(s, w, h)
				rowBG.a = s:IsHovered() and 34 or 14
				draw.RoundedBox(0, 0, 0, w, h, rowBG)
				draw.SimpleText(T("RETIRER TOUS LES ACCESSOIRES"), "SCPArmory_RoN_Label", w / 2, h / 2,
					COL.soft, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			clean.DoClick = function()
				attSel[curWeaponKey] = {}
				surface.PlaySound("ui/buttonclick.wav")
				RebuildColumn()
			end
		end
	end

	-- Vue de choix d'un accessoire pour un emplacement
	local function BuildAttSelect()
		AddBackHeader(attSlot.name, function()
			mode = "modify"
			attSlot = nil
			RebuildColumn()
		end)

		local function pick(attId)
			attSel[curWeaponKey][attSlot.index] = attId
			mode = "modify"
			attSlot = nil
			surface.PlaySound("ui/buttonclick.wav")
			RebuildColumn()
		end

		-- Ligne « aucun »
		local noneBtn = scroll:Add("DButton")
		noneBtn:Dock(TOP)
		noneBtn:DockMargin(0, 0, 10, rowGap)
		noneBtn:SetTall(40)
		noneBtn:SetText("")
		noneBtn.Paint = function(s, w, h)
			local equipped = attSel[curWeaponKey][attSlot.index] == nil
			RowChrome(s:IsHovered() and 1 or 0, w, h)
			if equipped then
				surface.SetDrawColor(COL.red)
				surface.DrawRect(0, 3, 3, h - 6)
			end
			DrawSpacedText(T("—  AUCUN  —"), "SCPArmory_RoN_NameSm", 12, 10,
				s:IsHovered() and COL.text or COL.soft, 1)
		end
		noneBtn.DoClick = function() pick(nil) end

		local list = SCPArmory.ARC9Bridge.GetCompatible(attSlot.cats)
		if #list == 0 then
			AddNote("AUCUN ACCESSOIRE ARC9 COMPATIBLE INSTALLÉ")
			return
		end

		for _, att in ipairs(list) do
			local btn = scroll:Add("DButton")
			btn:Dock(TOP)
			btn:DockMargin(0, 0, 10, rowGap)
			btn:SetTall(48)
			btn:SetText("")
			btn.Paint = function(s, w, h)
				local equipped = attSel[curWeaponKey][attSlot.index] == att.id
				local hov = s:IsHovered()
				s.hf = Lerp(FrameTime() * 10, s.hf or 0, hov and 1 or 0)

				RowChrome(s.hf, w, h)
				if equipped then
					surface.SetDrawColor(COL.red)
					surface.DrawRect(0, 3, 3, h - 6)
				end

				-- Disposition façon Ready or Not : silhouette à gauche
				-- (icône du menu spawn), catégorie en petit au-dessus du nom
				local ox = 12 + math.Round(s.hf * 6)
				if not DrawAttIcon(att.id, ox, 7, 56, 34, (equipped or hov) and COL.text or COL.soft) then
					draw.SimpleText("—", "SCPArmory_RoN_Small", ox + 28, h / 2,
						COL.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				draw.SimpleText(att.cat, "SCPArmory_RoN_Small", ox + 68, 7, COL.red)
				DrawSpacedText(att.name, "SCPArmory_RoN_NameSm", ox + 68, 21,
					(equipped or hov) and COL.text or COL.soft, 1)
			end
			btn.OnCursorEntered = function() hoverAtt = att end
			btn.DoClick = function() pick(att.id) end
		end
	end

	-- Bodygroups autorisés du playermodel (vue d'ensemble + écran APPARENCE)
	local function CollectBGOpts()
		local bgOpts = {}
		for _, bg in ipairs(LocalPlayer():GetBodyGroups() or {}) do
			local nm = string.lower(tostring(bg.name or ""))
			if (bg.num or 0) > 1 and SCPArmory.AllowedBodygroups and SCPArmory.AllowedBodygroups[nm] then
				table.insert(bgOpts, { name = nm, id = bg.id, num = bg.num })
			end
		end
		return bgOpts
	end

	local function AddBGRow(opt)
		local cur = (selection.bg and selection.bg[opt.name])
			or LocalPlayer():GetBodygroup(opt.id) or 0

		local btn = scroll:Add("DButton")
		btn:Dock(TOP)
		btn:DockMargin(0, 0, 10, rowGap)
		btn:SetTall(48)
		btn:SetText("")
		btn.Paint = function(s, w, h)
			local hov = s:IsHovered()
			s.hf = Lerp(FrameTime() * 10, s.hf or 0, hov and 1 or 0)
			RowChrome(s.hf, w, h)
			local ox = 12 + math.Round(s.hf * 6)
			draw.SimpleText(SCPArmory.FrUpper(opt.name), "SCPArmory_RoN_Label", ox, 6, COL.dim)
			DrawSpacedText(T("VARIANTE") .. " " .. (cur + 1) .. " / " .. opt.num, "SCPArmory_RoN_NameSm", ox, 22,
				hov and COL.text or COL.soft, 1)
		end
		btn.DoClick = function()
			bgReturn = (mode == "section") and "section" or "overview"
			mode = "bgselect"
			bgSlot = opt
			surface.PlaySound("ui/buttonclick.wav")
			RebuildColumn()
		end
	end

	RebuildColumn = function()
		scroll:Clear()
		hoverAtt = nil
		column.animT = RealTime()

		if mode == "overview" then
			descLabel:SetText("")
			AddSection("ARMEMENT")
			for _, key in ipairs({ "primary", "secondary", "tactical1", "tactical2", "grenade" }) do
				AddOverviewEntry(SlotByKey(key), true)
			end

			AddSection("PROTECTION")
			for _, key in ipairs({ "armor", "helmet" }) do
				AddOverviewEntry(SlotByKey(key), false)
			end

			-- Apparence : bodygroups autorisés par la config, style RoN
			local bgOpts = CollectBGOpts()
			if #bgOpts > 0 then
				AddSection("APPARENCE")
				for _, opt in ipairs(bgOpts) do
					AddBGRow(opt)
				end
			end
		elseif mode == "section" then
			-- Écran APPARENCE de la carte MW : mêmes lignes de bodygroups
			-- que la vue d'ensemble classique, avec un en-tête retour
			descLabel:SetText("")
			AddBackHeader(T("APPARENCE"), GoBack)

			local bgOpts = CollectBGOpts()
			if #bgOpts == 0 then
				AddNote("Aucun bodygroup autorisé sur votre modèle.")
			end
			for _, opt in ipairs(bgOpts) do
				AddBGRow(opt)
			end
		elseif mode == "modify" then
			descLabel:SetText("")
			BuildModify()
		elseif mode == "attselect" then
			BuildAttSelect()
		elseif mode == "bgselect" then
			-- Choix d'une variante d'apparence, style RoN
			AddBackHeader(SCPArmory.FrUpper(bgSlot.name), GoBack)

			local curVal = (selection.bg and selection.bg[bgSlot.name])
				or LocalPlayer():GetBodygroup(bgSlot.id) or 0

			for v = 0, bgSlot.num - 1 do
				local row = scroll:Add("DButton")
				row:Dock(TOP)
				row:DockMargin(0, 0, 10, rowGap)
				row:SetTall(44)
				row:SetText("")
				row.Paint = function(s, w, h)
					local equipped = (curVal == v)
					local hov = s:IsHovered()
					s.hf = Lerp(FrameTime() * 10, s.hf or 0, hov and 1 or 0)

					RowChrome(s.hf, w, h)
					if equipped then
						surface.SetDrawColor(COL.red)
						surface.DrawRect(0, 3, 3, h - 6)
					end

					local ox = 12 + math.Round(s.hf * 6)
					DrawSpacedText(T("VARIANTE") .. " " .. (v + 1), "SCPArmory_RoN_NameSm", ox, 12,
						(equipped or hov) and COL.text or COL.soft, 1)
					if equipped then
						draw.SimpleText(T("ÉQUIPÉE"), "SCPArmory_RoN_Small", w - 12, 16, COL.red, TEXT_ALIGN_RIGHT)
					end
				end
				row.DoClick = function()
					selection.bg = selection.bg or {}
					selection.bg[bgSlot.name] = v
					mode = bgReturn
					bgSlot = nil
					surface.PlaySound("ui/buttonclick.wav")
					RebuildColumn()
				end
			end
		else
			AddBackHeader(T(selectSlot.label), GoBack)
			for _, item in ipairs(SCPArmory.Items[selectSlot.pool]) do
				-- Un objet réservé à un autre job n'apparaît pas du tout
				if SCPArmory.IsItemAvailable(LocalPlayer(), item) then
					AddSelectRow(item)
				end
			end
		end

		infoPanel:SetVisible(mode == "modify" or mode == "attselect")
		if infoPanel:IsVisible() then
			local item = CurWeaponItem()
			infoDesc:SetText(item and item.desc or "")
		end

		-- Écran killstreak (MW) : cartes reconstruites, colonne masquée sur
		-- la vue d'ensemble (les sous-écrans gardent la colonne classique)
		if uiStyle == "mw" then
			RebuildMW()
		end
		column:SetVisible(not (uiStyle == "mw" and mode == "overview"))

		-- Apparition en cascade des lignes de la colonne
		local i = 0
		for _, child in ipairs(scroll:GetCanvas():GetChildren()) do
			child:SetAlpha(0)
			child:AlphaTo(255, 0.16, 0.025 * i)
			i = i + 1
		end

		RefreshPreview()
	end

	frame.RebuildColumn = RebuildColumn

	-- ---------------------------------------------------------------------
	-- Écran MW façon sélection de killstreaks : grandes cartes anguleuses
	-- en bas de l'écran, opérateur au centre, barre DÉPLOYER à droite.
	-- Construit après RebuildColumn pour que chaque carte puisse naviguer.
	if uiStyle == "mw" then
		-- Titre + stats (la colonne classique est masquée sur cet écran)
		local header = vgui.Create("DPanel", frame)
		header:SetSize(640, 132)
		header:SetPos(48, 34)
		header:SetMouseInputEnabled(false)
		header.Paint = function(s, w, h)
			DrawSpacedText("LOADOUT", "SCPArmory_RoN_Huge", 0, 0, COL.text, 8)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 62, 26, 3)
			DrawSpacedText(T("PRÉPARATION AU DÉPLOIEMENT"), "SCPArmory_RoN_Label", 34, 58, COL.red, 2)
			draw.SimpleText(SCPArmory.FrUpper(jobName) .. " — " .. LocalPlayer():Nick(),
				"SCPArmory_RoN_NameSm", 0, 82, COL.soft)

			if not s.statsNext or RealTime() > s.statsNext then
				s.stats = SCPArmory.ComputeStats(selection)
				s.statsNext = RealTime() + 0.2
			end
			draw.SimpleText(string.format("%s %.1f KG   ·   %s %d %%   ·   %s %d",
				T("POIDS"), s.stats.weight, T("MOBILITÉ"), s.stats.mobility, T("ARMURE"), s.stats.armor),
				"SCPArmory_RoN_Small", 0, 108, COL.dim)
		end

		-- Bande de cartes (une par emplacement, + apparence si autorisée)
		local strip = vgui.Create("DPanel", frame)
		strip.Paint = function() end

		-- Barre d'action : RETOUR et grand DÉPLOYER
		local bar = vgui.Create("DPanel", frame)
		bar:SetSize(414, 60)
		bar:SetPos(ScrW() - 414 - 48, ScrH() - 86)
		bar.Paint = function() end

		local mwBack = vgui.Create("DButton", bar)
		mwBack:SetPos(0, 0)
		mwBack:SetSize(140, 60)
		mwBack:SetText("")
		mwBack.Paint = function(s, w, h)
			s.hf = Lerp(FrameTime() * 10, s.hf or 0, s:IsHovered() and 1 or 0)
			local down = s:IsDown()

			-- Bouton arrondi à liseré : boîte claire, puis fond sombre en creux
			mwEdge.r = Lerp(s.hf, COL.line.r, COL.text.r)
			mwEdge.g = Lerp(s.hf, COL.line.g, COL.text.g)
			mwEdge.b = Lerp(s.hf, COL.line.b, COL.text.b)
			mwEdge.a = 255
			draw.RoundedBox(12, 0, 0, w, h, mwEdge)
			draw.RoundedBox(11, 1, 1, w - 2, h - 2, mwDark)
			backBG.a = 14 + 30 * s.hf
			draw.RoundedBox(11, 1, 1, w - 2, h - 2, backBG)
			if down then
				btnPress.a = 50
				draw.RoundedBox(12, 0, 0, w, h, btnPress)
			end

			-- Chevron qui glisse vers la gauche au survol
			local ty = h / 2 + (down and 1 or 0)
			if s.hf > 0.05 then
				chevCol.a = 255 * s.hf
				draw.SimpleText("«", "SCPArmory_RoN_Btn", 12 - 3 * s.hf, ty - 1, chevCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			draw.SimpleText(T("RETOUR"), "SCPArmory_RoN_Btn", w / 2 - 10 + 3 * s.hf, ty, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("ESC", "SCPArmory_RoN_Small", w - 12, ty, COL.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
		mwBack.DoClick = GoBack
		HoverCue(mwBack)

		local mwDeploy = vgui.Create("DButton", bar)
		mwDeploy:SetPos(160, 0)
		mwDeploy:SetSize(254, 60)
		mwDeploy:SetText("")
		mwDeploy.Paint = function(s, w, h)
			s.hf = Lerp(FrameTime() * 10, s.hf or 0, s:IsHovered() and 1 or 0)
			local down = s:IsDown()
			local pulse = (1 - s.hf) * math.sin(RealTime() * 2.2) * 7

			-- Halo d'accent qui respire autour du bouton
			mwFill.r, mwFill.g, mwFill.b = COL.red.r, COL.red.g, COL.red.b
			mwFill.a = 70 + 26 * math.sin(RealTime() * 2.2) + 90 * s.hf
			draw.RoundedBox(14, 0, 0, w, h, mwFill)

			btnBG.r = math.Clamp(Lerp(s.hf, COL.red.r, COL.redHi.r) + pulse, 0, 255)
			btnBG.g = math.Clamp(Lerp(s.hf, COL.red.g, COL.redHi.g) + pulse * 0.3, 0, 255)
			btnBG.b = math.Clamp(Lerp(s.hf, COL.red.b, COL.redHi.b) + pulse * 0.3, 0, 255)
			draw.RoundedBox(12, 2, 2, w - 4, h - 4, btnBG)

			-- Relief : reflet permanent en tête, renforcé au survol
			mwGloss.a = 14 + 26 * s.hf
			draw.RoundedBox(12, 2, 2, w - 4, math.floor(h / 2) - 2, mwGloss)

			-- Éclat qui balaie le bouton par intervalles
			local sweep = (RealTime() * 0.35) % 1
			if sweep < 0.2 then
				surface.SetDrawColor(255, 255, 255, 24)
				surface.DrawRect((w + 60) * (sweep / 0.2) - 30, 4, 24, h - 8)
			end

			if down then
				btnPress.a = 60
				draw.RoundedBox(12, 2, 2, w - 4, h - 4, btnPress)
			end

			-- Libellé + chevrons animés, sous-titre façon MW
			local label = T("DÉPLOYER")
			surface.SetFont("SCPArmory_RoN_Btn")
			local tw = surface.GetTextSize(label)
			local ty = h / 2 - 8 + (down and 1 or 0)
			draw.SimpleText(label, "SCPArmory_RoN_Btn", w / 2 - 9 * s.hf, ty, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if s.hf > 0.05 then
				chevCol.a = 255 * s.hf
				local cx = w / 2 - 9 * s.hf + tw / 2 + 8 + math.sin(RealTime() * 6) * 2
				draw.SimpleText("»", "SCPArmory_RoN_Btn", cx, ty - 1, chevCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			draw.SimpleText(T("REJOINDRE LA BATAILLE"), "SCPArmory_RoN_Small", w / 2, ty + 19, COL.soft, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			if s.flashT then
				local fa = 1 - (RealTime() - s.flashT) / 0.25
				if fa > 0 then
					flashBG.a = 170 * fa
					draw.RoundedBox(12, 2, 2, w - 4, h - 4, flashBG)
				end
			end
		end
		mwDeploy.DoClick = function(s)
			s.flashT = RealTime()
			DoDeploy()
		end
		HoverCue(mwDeploy)

		local CARD_KEYS = { "primary", "secondary", "tactical1", "tactical2", "grenade", "armor", "helmet" }

		RebuildMW = function()
			local over = (mode == "overview")
			header:SetVisible(over)
			strip:SetVisible(over)
			bar:SetVisible(over)
			if not over then return end

			for _, c in ipairs(strip:GetChildren()) do
				c:Remove()
			end

			-- Apparence en dernière carte si la config l'autorise
			local keys = {}
			for _, k in ipairs(CARD_KEYS) do
				table.insert(keys, k)
			end
			if #CollectBGOpts() > 0 then
				table.insert(keys, "apparence")
			end

			local ch = 208
			local gap = 10
			local cw = math.Clamp(math.floor((ScrW() - 160) / #keys) - gap, 116, 152)
			local total = #keys * (cw + gap) - gap
			-- Marge de tête (lévitation au survol) et de pied (course de
			-- l'animation d'entrée) pour que rien ne soit rogné
			strip:SetSize(total, ch + 42)
			strip:SetPos(math.floor((ScrW() - total) / 2) + 20, ScrH() - ch - 118)

			for i, key in ipairs(keys) do
				local isApp = (key == "apparence")
				local slot = not isApp and SlotByKey(key) or nil
				local item = slot and SCPArmory.GetItem(slot.pool, selection[key]) or nil
				local picto = (isApp and "torso")
					or (key == "armor" and "armor")
					or (key == "helmet" and "helmet")
					or nil

				local card = vgui.Create("DButton", strip)
				local cx = (i - 1) * (cw + gap)
				card:SetSize(cw, ch)
				card:SetText("")

				-- Entrée en cascade : la carte monte en fondu depuis le bas
				card:SetPos(cx, 38)
				card:SetAlpha(0)
				card:AlphaTo(255, 0.22, 0.045 * i)
				card:MoveTo(cx, 10, 0.3, 0.045 * i, 0.6)
				card.introUntil = SysTime() + 0.045 * i + 0.34

				-- Lévitation au survol (les enfants — modèle 3D — suivent)
				card.Think = function(s)
					if SysTime() < s.introUntil then return end
					s:SetPos(cx, 10 - math.Round(6 * (s.hf or 0)))
				end
				HoverCue(card)

				card.Paint = function(s, w, h)
					s.hf = Lerp(FrameTime() * 10, s.hf or 0, s:IsHovered() and 1 or 0)

					-- Carte arrondie sombre à liseré d'accent (boîte claire
					-- puis fond en creux : bordure arrondie sans allocation)
					mwEdge.r, mwEdge.g, mwEdge.b = COL.red.r, COL.red.g, COL.red.b
					mwEdge.a = 90 + 165 * s.hf
					draw.RoundedBox(12, 0, 0, w, h, mwEdge)
					draw.RoundedBox(11, 1, 1, w - 2, h - 2, mwDark)
					if s.hf > 0.01 then
						mwFill.r, mwFill.g, mwFill.b, mwFill.a = COL.red.r, COL.red.g, COL.red.b, 30 * s.hf
						draw.RoundedBox(11, 1, 1, w - 2, h - 2, mwFill)
					end

					-- Pastille d'accent en tête, qui s'étire au survol
					local nw = math.floor(w * (0.34 + 0.16 * s.hf))
					draw.RoundedBox(2, math.floor((w - nw) / 2), 4, nw, 4, COL.red)

					-- Numéro d'emplacement, façon sélection de killstreaks
					draw.SimpleText(string.format("%02d", i), "SCPArmory_RoN_Small", 10, 7,
						s.hf > 0.3 and COL.dim or COL.faint)

					draw.SimpleText(isApp and T("APPARENCE") or T(slot.label), "SCPArmory_RoN_Label",
						w / 2, 16, s.hf > 0.3 and COL.soft or COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

					if picto then
						DrawSlotIcon(picto, w / 2 - 17, h / 2 - 30, 34, s:IsHovered() and COL.text or COL.soft)
					elseif item and item.icon then
						SCPArmory.DrawWebIcon(item.icon, 8, 34, w - 16, h - 92)
					elseif not HasModel(item) then
						draw.SimpleText("—", "SCPArmory_RoN_Big", w / 2, h / 2 - 12, COL.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end

					if not isApp then
						draw.SimpleText(SCPArmory.FrUpper(item and item.name or "—"), "SCPArmory_RoN_Small",
							w / 2, h - 26, item and COL.soft or COL.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end
				end
				card.DoClick = function()
					surface.PlaySound("ui/buttonclick.wav")
					if isApp then
						mode = "section"
					elseif key == "primary" or key == "secondary" then
						modifyReturn = "overview"
						curWeaponKey = key
						mode = "modify"
					else
						selectReturn = "overview"
						selectSlot = slot
						hoverItem = item
						mode = "select"
					end
					RebuildColumn()
				end

				-- Silhouette 3D de l'objet équipé au centre de la carte
				if not picto and item and not item.icon and HasModel(item) then
					local mp = vgui.Create("DModelPanel", card)
					mp:SetPos(6, 40)
					mp:SetSize(cw - 12, ch - 104)
					mp:SetModel(item.model)
					mp:SetMouseInputEnabled(false)
					FitModelSide(mp)
				end
			end
		end
	end

	-- Description de l'objet / accessoire survolé
	local lastDesc = nil
	bottom.Think = function()
		local want = ""
		if mode == "select" and hoverItem then
			want = hoverItem.desc or ""
		elseif mode == "attselect" and hoverAtt then
			want = hoverAtt.desc or ""
		end
		if want ~= lastDesc then
			lastDesc = want
			descLabel:SetText(want)
		end
	end

	RebuildColumn()
end

concommand.Add("scp_armory", OpenMenu, nil, "Ouvre l'armurerie de la Fondation SCP.")

net.Receive("SCPArmory_Open", OpenMenu)
