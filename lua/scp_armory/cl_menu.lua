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
	amber  = Color(255, 176, 0, 255),
}

-- Couleurs mutables réutilisées dans les Paint (aucune allocation par frame)
local rowBG = Color(255, 255, 255, 8)
local btnBG = Color(190, 34, 28, 255)
local flashBG = Color(255, 255, 255, 255)
local backBG = Color(255, 255, 255, 20)

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
-- Style d'interface actif : "cartes" (panneaux arrondis), "ron" (Ready or
-- Not plat et épuré), "mw" (Modern Warfare anguleux). Choisi dans la config.
local uiStyle = "cartes"

-- Applique le style et la couleur d'accent configurés : COL.red/redHi/amber
-- sont mutées en place, donc toutes les références déjà prises restent bonnes
local function ApplyTheme()
	local s = SCPArmory.Config.UITheme
	uiStyle = (s == "ron" or s == "mw") and s or "cartes"

	local r, g, b = SCPArmory.AccentColor()
	COL.red.r, COL.red.g, COL.red.b = r, g, b
	COL.redHi.r = math.min(255, r + 35)
	COL.redHi.g = math.min(255, g + 18)
	COL.redHi.b = math.min(255, b + 16)
	COL.amber.r = math.min(255, r + 65)
	COL.amber.g = math.min(255, g + 142)
	COL.amber.b = math.max(0, b - 28)
	btnBG.r, btnBG.g, btnBG.b = r, g, b
end

-- Rayon d'arrondi des éléments selon le style (0 = angles nets)
local function UIRadius(cartes)
	if uiStyle == "cartes" then return cartes end
	if uiStyle == "holo" then return math.min(cartes, 6) end
	return 0
end

-- Thèmes « références » : lignes en boîtes bordées, pictogrammes, chevrons
local function IsBoxTheme()
	return uiStyle == "holo" or uiStyle == "cyber" or uiStyle == "sombre" or uiStyle == "legion"
end

-- Marge droite des textes alignés à droite (place du chevron)
local function RightPad()
	return (uiStyle == "holo" or uiStyle == "cyber" or uiStyle == "legion") and 28 or 12
end

-- Dessin en 9 tranches d'une texture à bords (panneaux/plaques du thème légion) :
-- coins fidèles, bords et centre étirés. b = bord en pixels texture,
-- sb = bord affiché en pixels écran.
local texCol = Color(255, 255, 255, 255)
local shadowA = Color(0, 0, 0, 95)
local shadowB = Color(0, 0, 0, 45)

local function Draw9(mat, x, y, w, h, tw, th, b, sb, col)
	if not mat or mat:IsError() then return end
	surface.SetDrawColor(col.r, col.g, col.b, col.a)
	surface.SetMaterial(mat)
	sb = math.min(sb, math.floor(w / 2), math.floor(h / 2))
	local u, v = b / tw, b / th

	surface.DrawTexturedRectUV(x, y, sb, sb, 0, 0, u, v)
	surface.DrawTexturedRectUV(x + w - sb, y, sb, sb, 1 - u, 0, 1, v)
	surface.DrawTexturedRectUV(x, y + h - sb, sb, sb, 0, 1 - v, u, 1)
	surface.DrawTexturedRectUV(x + w - sb, y + h - sb, sb, sb, 1 - u, 1 - v, 1, 1)

	surface.DrawTexturedRectUV(x + sb, y, w - sb * 2, sb, u, 0, 1 - u, v)
	surface.DrawTexturedRectUV(x + sb, y + h - sb, w - sb * 2, sb, u, 1 - v, 1 - u, 1)
	surface.DrawTexturedRectUV(x, y + sb, sb, h - sb * 2, 0, v, u, 1 - v)
	surface.DrawTexturedRectUV(x + w - sb, y + sb, sb, h - sb * 2, 1 - u, v, 1, 1 - v)

	surface.DrawTexturedRectUV(x + sb, y + sb, w - sb * 2, h - sb * 2, u, v, 1 - u, 1 - v)
end

-- Couleurs mutables des thèmes en boîtes (aucune allocation par frame)
local boxLine = Color(190, 34, 28, 90)
local boxBG = Color(10, 14, 22, 190)
local chevCol = Color(190, 34, 28, 140)
local panelBG = Color(8, 10, 14, 232)

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

-- Habillage commun des lignes de la colonne : carte arrondie (cartes),
-- ligne plate à séparateur (ron), surlignage accent anguleux (mw)
local function RowChrome(hf, w, h)
	if uiStyle == "ron" then
		if hf > 0.01 then
			surface.SetDrawColor(255, 255, 255, 6 * hf)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 255 * hf)
			surface.DrawRect(0, 0, 2, h)
		end
		surface.SetDrawColor(COL.lineF)
		surface.DrawRect(0, h - 1, w, 1)
	elseif uiStyle == "mw" then
		surface.SetDrawColor(255, 255, 255, 4)
		surface.DrawRect(0, 0, w, h)
		if hf > 0.01 then
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 36 * hf)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 255 * hf)
			surface.DrawRect(0, 0, 3, h)
		end
		surface.SetDrawColor(COL.lineF)
		surface.DrawRect(0, h - 1, w, 1)
	elseif uiStyle == "holo" then
		-- boîte arrondie à bordure lumineuse (bordure = boîte sous boîte)
		boxLine.r, boxLine.g, boxLine.b = COL.red.r, COL.red.g, COL.red.b
		boxLine.a = 70 + 150 * hf
		draw.RoundedBox(6, 0, 0, w, h, boxLine)
		boxBG.r = 4 + COL.red.r * 0.05
		boxBG.g = 6 + COL.red.g * 0.06
		boxBG.b = 8 + COL.red.b * 0.10
		boxBG.a = 216 - 26 * hf
		draw.RoundedBox(5, 1, 1, w - 2, h - 2, boxBG)
		chevCol.r, chevCol.g, chevCol.b = COL.red.r, COL.red.g, COL.red.b
		chevCol.a = 110 + 120 * hf
		draw.SimpleText("›", "SCPArmory_RoN_Name", w - 13, h / 2 - 1, chevCol,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	elseif uiStyle == "cyber" then
		surface.SetDrawColor(255, 255, 255, 8 + 10 * hf)
		surface.DrawRect(0, 0, w, h)
		if hf > 0.01 then
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 24 * hf)
			surface.DrawRect(0, 0, w, h)
		end
		surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 55 + 170 * hf)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		chevCol.r, chevCol.g, chevCol.b = COL.red.r, COL.red.g, COL.red.b
		chevCol.a = 110 + 120 * hf
		draw.SimpleText("›", "SCPArmory_RoN_Name", w - 13, h / 2 - 1, chevCol,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	elseif uiStyle == "sombre" then
		surface.SetDrawColor(255, 255, 255, 11 + 10 * hf)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 14 + 22 * hf)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		if hf > 0.01 then
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 255 * hf)
			surface.DrawRect(0, 0, 3, h)
		end
	elseif uiStyle == "legion" then
		-- plaques holographiques générées (materials/scp_armory/holo_plate*)
		texCol.r, texCol.g, texCol.b, texCol.a = 255, 255, 255, 255
		Draw9(BackdropMat("holo_plate.png"), 0, 0, w, h, 256, 64, 20, 12, texCol)
		if hf > 0.01 then
			texCol.a = 255 * hf
			Draw9(BackdropMat("holo_plate_hi.png"), 0, 0, w, h, 256, 64, 20, 12, texCol)
		end
		chevCol.r, chevCol.g, chevCol.b = COL.red.r, COL.red.g, COL.red.b
		chevCol.a = 110 + 120 * hf
		draw.SimpleText("›", "SCPArmory_RoN_Name", w - 13, h / 2 - 1, chevCol,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		rowBG.a = 8 + 14 * hf
		draw.RoundedBox(8, 0, 0, w, h, rowBG)
		if hf > 0.01 then
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 255 * hf)
			surface.DrawRect(0, 3, 3, h - 6)
		end
	end
end

local SAVE_DIR = "scp_armory"
local SAVE_FILE = SAVE_DIR .. "/loadout.txt"

-- (matériaux d'ambiance et de thème : voir BackdropMat plus haut)

local WEAPON_KEYS = { "primary", "secondary" }

local activeMenu = nil

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

-- ---------------------------------------------------------------- persistence

local function LoadSaved()
	local sel = SCPArmory.DefaultLoadout()
	local auto = true
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
			if tbl.__auto ~= nil then auto = tobool(tbl.__auto) end

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

	return sel, auto, atts
end

local function SaveSelection(sel, auto, atts)
	file.CreateDir(SAVE_DIR)
	local tbl = table.Copy(sel)
	tbl.__auto = auto
	tbl.__atts = atts
	file.Write(SAVE_FILE, util.TableToJSON(tbl, true))
end

-- ---------------------------------------------------------------------- menu

local function OpenMenu()
	if IsValid(activeMenu) then activeMenu:Remove() end

	EnsureFonts()
	ApplyTheme()

	-- Espacement des lignes selon le style : cartes/boîtes espacées, listes serrées
	local rowGap = (uiStyle == "cartes" and 5)
		or (uiStyle == "mw" and 2)
		or (IsBoxTheme() and 6)
		or 0

	local selection, autoApply, attSel = LoadSaved()
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

	-- Thème légion : la vue d'ensemble est un hub de navigation (comme la
	-- référence) ; les listes d'équipement vivent dans des écrans de section
	local legionSection = "armement"
	local LEGION_LABELS = {
		armement = "ARMEMENT",
		protection = "PROTECTION",
		apparence = "APPARENCE",
	}

	-- Écran « racine » des listes : le hub en légion, la vue d'ensemble sinon
	local function OverviewMode()
		return uiStyle == "legion" and "section" or "overview"
	end

	-- Retour de l'écran MODIFY : hub ou écran de section selon la provenance
	local modifyReturn = "overview"

	-- Panneau ÉQUIPEMENT ACTUEL du thème légion (rempli plus bas)
	local RebuildRight = function() end

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

	local function DrawBackdrop(mat, w, h, alpha)
		if not mat or mat:IsError() then return end
		local iw, ih = 1920, 1080
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

	frame.Paint = function(_, w, h)
		surface.SetDrawColor(COL.bg)
		surface.DrawRect(0, 0, w, h)

		-- Parallaxe lissé suivant la souris (le fond glisse à l'opposé)
		local tx = (gui.MouseX() / math.max(ScrW(), 1) - 0.5) * 0.02
		local ty = (gui.MouseY() / math.max(ScrH(), 1) - 0.5) * 0.012
		local fr = math.Clamp(FrameTime() * 5, 0, 1)
		parX = parX + (tx - parX) * fr
		parY = parY + (ty - parY) * fr

		-- Fondu croisé selon l'écran affiché ; le thème légion vit dans son
		-- hangar holographique généré (bg_holo)
		if SCPArmory.Config.MenuScene ~= false then
			bgBlend = Lerp(FrameTime() * 6, bgBlend, bgWeapon and 1 or 0)
			local backA = uiStyle == "legion" and "bg_holo.png" or "bg_racks.png"
			local backB = uiStyle == "legion" and "bg_holo.png" or "bg_table.png"
			if bgBlend < 0.99 then
				DrawBackdrop(BackdropMat(backA), w, h, 255 * (1 - bgBlend))
			end
			if bgBlend > 0.01 then
				DrawBackdrop(BackdropMat(backB), w, h, 255 * bgBlend)
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

		-- Barre d'accent en haut de l'écran : dégradé (cartes), trait net (mw),
		-- rien (ron, fidèle au jeu d'origine)
		if uiStyle == "cartes" then
			local bands = 40
			local bw = w / bands
			for i = 0, bands - 1 do
				local f = i / (bands - 1)
				surface.SetDrawColor(
					Lerp(f, COL.red.r, COL.amber.r),
					Lerp(f, COL.red.g, COL.amber.g),
					Lerp(f, COL.red.b, COL.amber.b), 230)
				surface.DrawRect(i * bw, 0, math.ceil(bw), 3)
			end
		elseif uiStyle == "mw" then
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
		local statusY = (uiStyle == "legion") and 66 or 50
		local bt2 = rt % 2.4
		local ledOn = bt2 < 0.08 or (bt2 > 0.24 and bt2 < 0.32)
		surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, ledOn and 255 or 60)
		surface.DrawRect(w - 26 - 4, statusY + 2, 4, 4)

		local session = math.floor(rt - openTime)
		local status = string.format("EN LIGNE  //  %s  //  SESSION %02d:%02d",
			os.date("%H:%M:%S"), math.floor(session / 60), session % 60)
		draw.SimpleText(status, "SCPArmory_RoN_Small", w - 36, statusY, COL.faint, TEXT_ALIGN_RIGHT)

		if uiStyle == "legion" then
			-- Badge d'unité façon référence : écusson + job + grade réels
			local em = BackdropMat("holo_emblem.png")
			if em and not em:IsError() then
				surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 225)
				surface.SetMaterial(em)
				surface.DrawTexturedRect(w - 66, 14, 42, 42)
			end
			draw.SimpleText(SCPArmory.FrUpper(jobName), "SCPArmory_RoN_Name", w - 78, 16, COL.text, TEXT_ALIGN_RIGHT)
			draw.SimpleText(SCPArmory.FrUpper(LocalPlayer():GetUserGroup() or ""), "SCPArmory_RoN_Small", w - 78, 38, COL.dim, TEXT_ALIGN_RIGHT)
		else
			draw.SimpleText("SCP ARMORY — SITE-19", "SCPArmory_RoN_Small", w - 26, 18, COL.dim, TEXT_ALIGN_RIGHT)
			draw.SimpleText(SCPArmory.FrUpper(jobName), "SCPArmory_RoN_Small", w - 26, 34, COL.faint, TEXT_ALIGN_RIGHT)
		end

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
			local amp = (uiStyle == "legion") and 1.6 or 1
			local target = Vector(dist, parX * 420 * amp, 55 - parY * 260 * amp)
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

		-- Scène 3D du thème légion : socle holographique sous l'opérateur,
		-- hologramme APERÇU incliné dans la pièce et armes flottantes
		if uiStyle == "legion" and not s.CurIsWeapon then
			local rt = RealTime()
			local r, g, b = COL.red.r, COL.red.g, COL.red.b
			local pulse = 150 + math.sin(rt * 1.6) * 50

			-- Socle : anneaux, graduations et écusson au sol, en rotation
			cam.Start3D2D(Vector(0, 0, 2), Angle(0, (rt * 9) % 360, 0), 0.5)
				surface.DrawCircle(0, 0, 70, r, g, b, pulse)
				surface.DrawCircle(0, 0, 56, r, g, b, pulse * 0.5)
				surface.DrawCircle(0, 0, 38, r, g, b, pulse * 0.35)
				surface.SetDrawColor(r, g, b, pulse * 0.8)
				for i = 0, 11 do
					local an = math.rad(i * 30)
					surface.DrawRect(math.cos(an) * 62 - 3, math.sin(an) * 62 - 1.5, 6, 3)
				end
				local em = BackdropMat("holo_emblem.png")
				if em and not em:IsError() then
					surface.SetDrawColor(r, g, b, pulse * 0.35)
					surface.SetMaterial(em)
					surface.DrawTexturedRectRotated(0, 0, 60, 60, -rt * 18)
				end
			cam.End3D2D()

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
	-- pour rester cliquable et visible au-dessus (en légion : onglet dédié)
	if LocalPlayer():IsSuperAdmin() and uiStyle ~= "legion" then
		local cfgBtn = vgui.Create("DButton", frame)
		cfgBtn:SetPos(ScrW() - 176, 52)
		cfgBtn:SetSize(150, 26)
		cfgBtn:SetText("")
		cfgBtn.Paint = function(s, w, h)
			rowBG.a = s:IsHovered() and 44 or 22
			draw.RoundedBox(UIRadius(6), 0, 0, w, h, rowBG)
			draw.SimpleText(T("CONFIGURATION"), "SCPArmory_RoN_Label", w / 2, h / 2,
				s:IsHovered() and COL.text or COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		cfgBtn.DoClick = function()
			if SCPArmory.OpenConfigMenu then SCPArmory.OpenConfigMenu() end
		end
	end

	-- --------------------------------------------------- colonne de gauche

	-- Largeur de colonne adaptative (petites résolutions et ultrawide)
	local colX, colY = 48, 34
	-- Thème légion : la colonne descend sous le bandeau d'onglets et laisse
	-- la place au grand DÉPLOYER central en bas, comme la référence
	if uiStyle == "legion" then colY = 104 end
	local colW = math.Clamp(math.floor(ScrW() * 0.22), 320, 420)
	local colH = (uiStyle == "legion") and (ScrH() - colY - 122) or (ScrH() - colY * 2)
	local bottomH = 184
	local titleH = 112

	local column = vgui.Create("DPanel", frame)
	column:SetPos(colX, colY)
	column:SetSize(colW, colH)
	-- Couleur réutilisée chaque frame (pas d'allocation dans le Paint)
	local redAnim = Color(COL.red.r, COL.red.g, COL.red.b, 255)

	column.Paint = function(s, w)
		-- Ombres portées décalées : le panneau flotte au-dessus de la scène
		if uiStyle ~= "ron" then
			local dc = DisableClipping(true)
			draw.RoundedBox(18, -4, 2, w + 40, s:GetTall() + 38, shadowB)
			draw.RoundedBox(14, -12, -8, w + 34, s:GetTall() + 30, shadowA)
			DisableClipping(dc)
		end

		-- Fond de colonne selon le style : carte translucide arrondie
		-- (cartes), panneau anguleux à liseré d'accent (mw), rien (ron —
		-- le dégradé sombre du fond suffit, comme dans le jeu d'origine)
		if uiStyle == "cartes" then
			local dc = DisableClipping(true)
			draw.RoundedBox(14, -18, -16, w + 34, s:GetTall() + 32, COL.card)
			draw.RoundedBoxEx(14, -18, -16, w + 34, 4, COL.red, true, true, false, false)
			DisableClipping(dc)
		elseif uiStyle == "mw" then
			local dc = DisableClipping(true)
			surface.SetDrawColor(COL.card)
			surface.DrawRect(-18, -16, w + 34, s:GetTall() + 32)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(-18, -16, w + 34, 2)
			DisableClipping(dc)
		elseif uiStyle == "holo" then
			-- panneau hologramme : fond teinté, bordure arrondie, coins marqués
			local dc = DisableClipping(true)
			local ph = s:GetTall() + 34
			boxLine.r, boxLine.g, boxLine.b, boxLine.a = COL.red.r, COL.red.g, COL.red.b, 130
			draw.RoundedBox(10, -19, -17, w + 36, ph, boxLine)
			panelBG.r = 5 + COL.red.r * 0.04
			panelBG.g = 7 + COL.red.g * 0.06
			panelBG.b = 9 + COL.red.b * 0.10
			draw.RoundedBox(9, -18, -16, w + 34, ph - 2, panelBG)
			-- coins lumineux
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 230)
			for _, c in ipairs({ { -19, -17, 1, 1 }, { w + 17, -17, -1, 1 },
				{ -19, ph - 18, 1, -1 }, { w + 17, ph - 18, -1, -1 } }) do
				local cx, cy, dx, dy = c[1], c[2], c[3], c[4]
				surface.DrawRect(dx > 0 and cx or cx - 13, cy - 1, 14, 3)
				surface.DrawRect(cx - 1, dy > 0 and cy or cy - 13, 3, 14)
			end
			DisableClipping(dc)
		elseif uiStyle == "cyber" then
			local dc = DisableClipping(true)
			panelBG.r, panelBG.g, panelBG.b = 6, 9, 15
			surface.SetDrawColor(panelBG)
			surface.DrawRect(-18, -16, w + 34, s:GetTall() + 32)
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 150)
			surface.DrawOutlinedRect(-18, -16, w + 34, s:GetTall() + 32, 1)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(-18, -16, w + 34, 2)
			DisableClipping(dc)
		elseif uiStyle == "sombre" then
			local dc = DisableClipping(true)
			panelBG.r, panelBG.g, panelBG.b = 8, 9, 11
			surface.SetDrawColor(panelBG)
			surface.DrawRect(-18, -16, w + 34, s:GetTall() + 32)
			surface.SetDrawColor(255, 255, 255, 18)
			surface.DrawOutlinedRect(-18, -16, w + 34, s:GetTall() + 32, 1)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(-18, -16, w + 34, 2)
			DisableClipping(dc)
		elseif uiStyle == "legion" then
			-- panneau hologramme généré + écusson au coin supérieur droit
			local dc = DisableClipping(true)
			texCol.r, texCol.g, texCol.b, texCol.a = 255, 255, 255, 255
			Draw9(BackdropMat("holo_panel.png"), -20, -18, w + 38, s:GetTall() + 36, 512, 512, 48, 26, texCol)
			local em = BackdropMat("holo_emblem.png")
			if em and not em:IsError() then
				surface.SetDrawColor(255, 255, 255, 235)
				surface.SetMaterial(em)
				surface.DrawTexturedRect(w - 14, -40, 46, 46)
			end
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
			DrawSpacedText(T(LEGION_LABELS[legionSection] or ""), "SCPArmory_RoN_Big", 0, 8, COL.text, 3)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 52, barW, 3)
			DrawSpacedText(T("SÉLECTION D'ÉQUIPEMENT"), "SCPArmory_RoN_Label", 28, 48, redCol, 2)
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
		if uiStyle == "cartes" then
			draw.RoundedBox(12, 0, 0, w, h, COL.panel)
			draw.RoundedBoxEx(12, 0, 0, w, 3, COL.red, true, true, false, false)
		elseif uiStyle == "holo" then
			boxLine.r, boxLine.g, boxLine.b, boxLine.a = COL.red.r, COL.red.g, COL.red.b, 130
			draw.RoundedBox(8, 0, 0, w, h, boxLine)
			panelBG.r = 5 + COL.red.r * 0.04
			panelBG.g = 7 + COL.red.g * 0.06
			panelBG.b = 9 + COL.red.b * 0.10
			draw.RoundedBox(7, 1, 1, w - 2, h - 2, panelBG)
		elseif uiStyle == "cyber" then
			surface.SetDrawColor(COL.panel)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 150)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 0, w, 2)
		elseif uiStyle == "legion" then
			texCol.r, texCol.g, texCol.b, texCol.a = 255, 255, 255, 255
			Draw9(BackdropMat("holo_panel.png"), 0, 0, w, h, 512, 512, 48, 20, texCol)
		else
			surface.SetDrawColor(COL.panel)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 0, w, 2)
		end

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
			for _, slot in ipairs(slots) do
				local installed = attSel[curWeaponKey][slot.index]
				local name = installed and SCPArmory.FrUpper(SCPArmory.ARC9Bridge.AttName(installed)) or "—"
				draw.SimpleText(name, "SCPArmory_RoN_Small", 16, y, installed and COL.text or COL.faint)
				draw.SimpleText(slot.name, "SCPArmory_RoN_Small", w - 16, y, COL.red, TEXT_ALIGN_RIGHT)
				surface.SetDrawColor(COL.lineF)
				surface.DrawRect(16, y + 17, w - 32, 1)
				y = y + 24
				if y > h - 20 then break end
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

			-- Poignée de curseur au bout de la barre (thèmes en boîtes)
			if IsBoxTheme() then
				surface.SetDrawColor(COL.text)
				surface.DrawRect(math.max(s.barAnim[i] * (w - 10) - 2, 0), y + 13, 4, 8)
			end
			y = y + 24
		end
	end

	-- Case à cocher stylée RoN (la DCheckBoxLabel de base jure avec le thème)
	local autoChk = vgui.Create("DButton", bottom)
	autoChk:SetPos(0, bottomH - 76)
	autoChk:SetSize(colW, 20)
	autoChk:SetText("")
	autoChk.checked = autoApply
	autoChk.GetChecked = function(s) return s.checked end
	autoChk.Paint = function(s, _, h)
		local hov = s:IsHovered()
		surface.SetDrawColor(hov and COL.text or COL.line)
		surface.DrawOutlinedRect(0, 3, 14, 14, 1)
		if s.checked then
			surface.SetDrawColor(COL.red)
			surface.DrawRect(3, 6, 8, 8)
		end
		draw.SimpleText(T("Réappliquer ce chargement au respawn"), "SCPArmory_RoN_Small", 22, h / 2,
			hov and COL.soft or COL.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	autoChk.DoClick = function(s)
		s.checked = not s.checked
		surface.PlaySound("ui/buttonclick.wav")
	end

	local backW = 118
	local deployBtn = vgui.Create("DButton", bottom)
	deployBtn:SetPos(0, bottomH - 46)
	deployBtn:SetSize(colW - backW - 10, 40)
	deployBtn:SetText("")
	deployBtn.Paint = function(s, w, h)
		s.hf = Lerp(FrameTime() * 10, s.hf or 0, s:IsHovered() and 1 or 0)

		-- Respiration discrète au repos
		local pulse = (1 - s.hf) * math.sin(RealTime() * 2.2) * 7

		if uiStyle == "legion" then
			-- Plaque holographique + écusson, façon référence légion
			texCol.r, texCol.g, texCol.b, texCol.a = 255, 255, 255, 255
			Draw9(BackdropMat("holo_plate_hi.png"), 0, 0, w, h, 256, 64, 20, 12, texCol)
			if s.hf > 0.02 then
				surface.SetDrawColor(255, 255, 255, 34 * s.hf)
				surface.DrawRect(6, 6, w - 12, h - 12)
			end
			local em = BackdropMat("holo_emblem.png")
			if em and not em:IsError() then
				surface.SetDrawColor(255, 255, 255, 230)
				surface.SetMaterial(em)
				surface.DrawTexturedRect(12, h / 2 - 12, 24, 24)
			end
		elseif uiStyle == "cyber" then
			-- Bouton en contour lumineux, façon référence cyber
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 42 + 70 * s.hf + pulse * 2)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 220)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 90 + 100 * s.hf)
			surface.DrawOutlinedRect(1, 1, w - 2, h - 2, 1)
		else
			btnBG.r = math.Clamp(Lerp(s.hf, COL.red.r, COL.redHi.r) + pulse, 0, 255)
			btnBG.g = math.Clamp(Lerp(s.hf, COL.red.g, COL.redHi.g) + pulse * 0.3, 0, 255)
			btnBG.b = math.Clamp(Lerp(s.hf, COL.red.b, COL.redHi.b) + pulse * 0.3, 0, 255)
			draw.RoundedBox(UIRadius(8), 0, 0, w, h, btnBG)

			-- Liseré blanc qui s'allume au survol
			if s.hf > 0.02 then
				surface.SetDrawColor(255, 255, 255, 60 * s.hf)
				surface.DrawOutlinedRect(3, 3, w - 6, h - 6, 1)
			end
		end

		if uiStyle == "legion" then
			-- Bouton à sous-titre, comme la référence (« REJOINDRE LE COMBAT »)
			draw.SimpleText(T("DÉPLOYER"), "SCPArmory_RoN_Btn", w / 2, h / 2 - 7, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(T("REJOINDRE LE COMBAT"), "SCPArmory_RoN_Small", w / 2, h / 2 + 10, COL.soft, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText(T("DÉPLOYER"), "SCPArmory_RoN_Btn", w / 2, h / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		-- Flash au clic
		if s.flashT then
			local fa = 1 - (RealTime() - s.flashT) / 0.25
			if fa > 0 then
				flashBG.a = 170 * fa
				draw.RoundedBox(UIRadius(8), 0, 0, w, h, flashBG)
			end
		end
	end
	-- Envoi du déploiement, partagé entre le bouton de colonne et le grand
	-- bouton central du thème légion
	local function DoDeploy()
		net.Start("SCPArmory_Apply")
		for _, slot in ipairs(SCPArmory.Slots) do
			net.WriteString(selection[slot.key] or "none")
		end
		net.WriteBool(autoChk:GetChecked())
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

		SaveSelection(selection, autoChk:GetChecked(), attSel)
		surface.PlaySound("items/ammo_pickup.wav")

		-- Déployer referme l'armurerie (en fondu)
		CloseMenu()
	end

	deployBtn.DoClick = function(s)
		s.flashT = RealTime()
		DoDeploy()
	end

	-- Thème légion : le déploiement passe par le grand bouton central
	if uiStyle == "legion" then
		deployBtn:SetVisible(false)
	end

	local RebuildColumn

	local function GoBack()
		if mode == "attselect" then
			mode = "modify"
			attSlot = nil
		elseif mode == "bgselect" then
			mode = OverviewMode()
			bgSlot = nil
		elseif mode == "select" then
			mode = selectReturn
			selectSlot = nil
		elseif mode == "modify" then
			mode = (uiStyle == "legion") and modifyReturn or OverviewMode()
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

		if uiStyle == "legion" then
			texCol.r, texCol.g, texCol.b, texCol.a = 255, 255, 255, 200 + 55 * s.hf
			Draw9(BackdropMat("holo_plate.png"), 0, 0, w, h, 256, 64, 20, 12, texCol)
		else
			backBG.a = 18 + 34 * s.hf
			draw.RoundedBox(UIRadius(8), 0, 0, w, h, backBG)
			if uiStyle ~= "cartes" then
				surface.SetDrawColor(
					Lerp(s.hf, COL.line.r, COL.text.r),
					Lerp(s.hf, COL.line.g, COL.text.g),
					Lerp(s.hf, COL.line.b, COL.text.b), 255)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
			end
		end
		-- Sur le hub légion, le bouton quitte le menu (comme la référence)
		local backLbl = (uiStyle == "legion" and mode == "overview") and T("QUITTER") or T("RETOUR")
		draw.SimpleText(backLbl, "SCPArmory_RoN_Btn", w / 2 - 12, h / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("ESC", "SCPArmory_RoN_Small", w - 10, h / 2, COL.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	backBtn.DoClick = GoBack

	-- --------------------------------------------- construction de la liste

	local function AddSection(label)
		label = T(label)
		local pnl = scroll:Add("DPanel")
		pnl:Dock(TOP)
		pnl:DockMargin(0, 10, 10, 4)
		pnl:SetTall(20)
		pnl.Paint = function(_, w, h)
			if uiStyle == "holo" or uiStyle == "cyber" or uiStyle == "legion" then
				-- barre verticale + libellé à la couleur d'accent (références)
				surface.SetDrawColor(COL.red)
				surface.DrawRect(0, 3, 3, 12)
				DrawSpacedText(label, "SCPArmory_RoN_Label", 10, 2, COL.red, 2)
			else
				DrawSpacedText(label, "SCPArmory_RoN_Label", 0, 2, COL.faint, 2)
			end
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

		-- Thèmes en boîtes : disposition compacte des références
		-- (icône à gauche, catégorie + nom à droite, chevron au bord)
		local boxy = IsBoxTheme()
		local tall = withImage and (boxy and 58 or 96) or (boxy and 52 or 48)

		local btn = scroll:Add("DButton")
		btn:Dock(TOP)
		btn:DockMargin(0, 0, 10, rowGap)
		btn:SetTall(tall)
		btn:SetText("")

		if withImage and item and not item.icon and HasModel(item) then
			local icon = vgui.Create("DModelPanel", btn)
			if boxy then
				icon:SetPos(10, 6)
				icon:SetSize(88, 46)
			else
				icon:SetPos(8, 4)
				icon:SetSize(170, 46)
			end
			icon:SetModel(item.model)
			icon:SetMouseInputEnabled(false)
			FitModelSide(icon)
		end

		btn.Paint = function(s, w, h)
			local hov = s:IsHovered()
			s.hf = Lerp(FrameTime() * 10, s.hf or 0, hov and 1 or 0)

			RowChrome(s.hf, w, h)

			if withImage and item and item.icon then
				if boxy then
					SCPArmory.DrawWebIcon(item.icon, 10, 6, 88, 46)
				else
					SCPArmory.DrawWebIcon(item.icon, 8, 3, 170, 46)
				end
			end

			-- Le texte glisse légèrement vers la droite au survol
			local ox = 10 + math.Round(s.hf * 6)

			if boxy and withImage then
				local tx = 104 + math.Round(s.hf * 4)
				draw.SimpleText(T(slot.label), "SCPArmory_RoN_Label", tx, 10, COL.dim)
				DrawSpacedText(SCPArmory.FrUpper(item and item.name or T("— AUCUN —")), "SCPArmory_RoN_NameSm", tx, 26,
					hov and COL.text or COL.soft, 1)
				if item and item.ammo and item.ammo[1] then
					draw.SimpleText("×" .. item.ammo[1].amount, "SCPArmory_RoN_Small", w - RightPad(), 10,
						COL.faint, TEXT_ALIGN_RIGHT)
				end
			elseif boxy then
				DrawSlotIcon(slot.key == "armor" and "armor" or "helmet",
					14, h / 2 - 12, 24, hov and COL.text or COL.dim)
				local tx = 50 + math.Round(s.hf * 4)
				draw.SimpleText(T(slot.label), "SCPArmory_RoN_Label", tx, 8, COL.dim)
				DrawSpacedText(SCPArmory.FrUpper(item and item.name or T("— AUCUN —")), "SCPArmory_RoN_NameSm", tx, 24,
					hov and COL.text or COL.soft, 1)
			elseif withImage then
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
				draw.SimpleText("×" .. item.ammo[1].amount, "SCPArmory_RoN_Small", w - RightPad(), 32,
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
				draw.RoundedBox(UIRadius(8), 0, 0, w, h, rowBG)
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
			btn:SetTall(44)
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

				local ox = 12 + math.Round(s.hf * 6)
				DrawSpacedText(att.name, "SCPArmory_RoN_NameSm", ox, 6,
					(equipped or hov) and COL.text or COL.soft, 1)
				draw.SimpleText(att.cat, "SCPArmory_RoN_Small", w - RightPad(), 26, COL.red, TEXT_ALIGN_RIGHT)
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
			if IsBoxTheme() then
				DrawSlotIcon("torso", 14, h / 2 - 12, 24, hov and COL.text or COL.dim)
				ox = ox + 38
			end
			draw.SimpleText(SCPArmory.FrUpper(opt.name), "SCPArmory_RoN_Label", ox, 6, COL.dim)
			DrawSpacedText(T("VARIANTE") .. " " .. (cur + 1) .. " / " .. opt.num, "SCPArmory_RoN_NameSm", ox, 22,
				hov and COL.text or COL.soft, 1)
		end
		btn.DoClick = function()
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

		if mode == "overview" and uiStyle == "legion" then
			-- Écran armurerie façon référence : ARSENAL (emplacements) à
			-- gauche + bloc UNITÉ (job, soldat, grade réels du joueur)
			descLabel:SetText("")
			AddSection("ARSENAL")
			for _, key in ipairs({ "primary", "secondary", "tactical1", "tactical2", "grenade" }) do
				AddOverviewEntry(SlotByKey(key), true)
			end

			AddSection("UNITÉ")
			local up = scroll:Add("DPanel")
			up:Dock(TOP)
			up:DockMargin(0, 0, 10, rowGap)
			up:SetTall(118)
			up.Paint = function(_, w, h)
				RowChrome(0, w, h)
				local em = BackdropMat("holo_emblem.png")
				if em and not em:IsError() then
					surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 40)
					surface.SetMaterial(em)
					surface.DrawTexturedRect(w - 102, h / 2 - 44, 88, 88)
				end
				DrawSpacedText(SCPArmory.FrUpper(jobName), "SCPArmory_RoN_Name", 14, 12, COL.text, 1)
				draw.SimpleText(T("SOLDAT"), "SCPArmory_RoN_Small", 14, 42, COL.dim)
				draw.SimpleText(LocalPlayer():Nick(), "SCPArmory_RoN_NameSm", 14, 56, COL.soft)
				draw.SimpleText(T("GRADE"), "SCPArmory_RoN_Small", 14, 82, COL.dim)
				draw.SimpleText(SCPArmory.FrUpper(LocalPlayer():GetUserGroup() or "?"), "SCPArmory_RoN_NameSm", 14, 96, COL.soft)
			end
		elseif mode == "overview" then
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
			-- Écran de catégorie du hub légion : mêmes lignes que la vue
			-- d'ensemble classique, avec un en-tête retour
			descLabel:SetText("")
			AddBackHeader(T(LEGION_LABELS[legionSection] or ""), GoBack)

			if legionSection == "armement" then
				for _, key in ipairs({ "primary", "secondary", "tactical1", "tactical2", "grenade" }) do
					AddOverviewEntry(SlotByKey(key), true)
				end
			elseif legionSection == "protection" then
				for _, key in ipairs({ "armor", "helmet" }) do
					AddOverviewEntry(SlotByKey(key), false)
				end
			else
				local bgOpts = CollectBGOpts()
				if #bgOpts == 0 then
					AddNote("Aucun bodygroup autorisé sur votre modèle.")
				end
				for _, opt in ipairs(bgOpts) do
					AddBGRow(opt)
				end
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
						draw.SimpleText(T("ÉQUIPÉE"), "SCPArmory_RoN_Small", w - RightPad(), 16, COL.red, TEXT_ALIGN_RIGHT)
					end
				end
				row.DoClick = function()
					selection.bg = selection.bg or {}
					selection.bg[bgSlot.name] = v
					mode = OverviewMode()
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

		-- Panneau ÉQUIPEMENT ACTUEL (légion) : reconstruit selon la sélection
		if uiStyle == "legion" then
			RebuildRight()
		end

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
	-- Écran armurerie du thème légion, façon référence : bandeau d'onglets,
	-- panneau ÉQUIPEMENT ACTUEL interactif (armes sur fond blueprint +
	-- MODIFIER, grilles cliquables), grand DÉPLOYER central et sauvegarde.
	-- Construit après RebuildColumn pour que chaque bouton puisse naviguer.
	if uiStyle == "legion" then
		-- ------------------------------------------------ bandeau d'onglets
		local TABS = {
			{ id = "loadout", label = "LOADOUT" },
			{ id = "apparence", label = T("APPARENCE") },
			{ id = "protection", label = T("PROTECTION") },
		}
		if LocalPlayer():IsSuperAdmin() then
			table.insert(TABS, { id = "config", label = T("CONFIGURATION") })
		end

		local function ActiveTab()
			if mode == "section" and legionSection == "apparence" then return "apparence" end
			if mode == "section" and legionSection == "protection" then return "protection" end
			return "loadout"
		end

		local tabW = math.min(168, math.floor((ScrW() - colX - colW - 420) / #TABS))
		local tabsPan = vgui.Create("DPanel", frame)
		tabsPan:SetSize(#TABS * tabW, 44)
		tabsPan:SetPos(colX + colW + 60, 20)
		tabsPan.Paint = function(_, w, h)
			surface.SetDrawColor(COL.lineF)
			surface.DrawRect(0, h - 1, w, 1)
		end

		for i, tb in ipairs(TABS) do
			local b = vgui.Create("DButton", tabsPan)
			b:SetPos((i - 1) * tabW, 0)
			b:SetSize(tabW, 44)
			b:SetText("")
			b.Paint = function(s, w, h)
				local on = ActiveTab() == tb.id and tb.id ~= "config"
				draw.SimpleText(tb.label, "SCPArmory_RoN_Name", w / 2, h / 2 - 2,
					on and COL.text or (s:IsHovered() and COL.soft or COL.dim),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				if on then
					surface.SetDrawColor(COL.red)
					surface.DrawRect(w * 0.2, h - 3, w * 0.6, 3)
				end
			end
			b.DoClick = function()
				surface.PlaySound("ui/buttonclick.wav")
				if tb.id == "loadout" then
					mode = "overview"
				elseif tb.id == "config" then
					if SCPArmory.OpenConfigMenu then SCPArmory.OpenConfigMenu() end
					return
				else
					mode = "section"
					legionSection = tb.id
				end
				RebuildColumn()
			end
		end

		-- ------------------------------- panneau ÉQUIPEMENT ACTUEL (droite)
		local rpW = math.Clamp(math.floor(ScrW() * 0.22), 330, 380)
		local rpH = 604
		local right = vgui.Create("DPanel", frame)
		right:SetSize(rpW, rpH)
		right:SetPos(ScrW() - rpW - 34, 92)
		right.Paint = function(_, w, h)
			texCol.r, texCol.g, texCol.b, texCol.a = 255, 255, 255, 255
			Draw9(BackdropMat("holo_panel.png"), 0, 0, w, h, 512, 512, 48, 22, texCol)
			DrawSpacedText(T("ÉQUIPEMENT ACTUEL"), "SCPArmory_RoN_Name", 24, 16, COL.text, 1)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(24, 38, 26, 2)
		end

		-- Cellule cliquable sur fond blueprint généré
		local function CellButton(x, y, cw, ch, paint, click)
			local b = vgui.Create("DButton", right)
			b:SetPos(x, y)
			b:SetSize(cw, ch)
			b:SetText("")
			b.Paint = function(s, w2, h2)
				texCol.r, texCol.g, texCol.b, texCol.a = 255, 255, 255, 255
				Draw9(BackdropMat("holo_blueprint.png"), 0, 0, w2, h2, 256, 128, 18, 10, texCol)
				if s:IsHovered() then
					surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 34)
					surface.DrawRect(2, 2, w2 - 4, h2 - 4)
				end
				paint(s, w2, h2)
			end
			b.DoClick = function()
				surface.PlaySound("ui/buttonclick.wav")
				click()
			end
			return b
		end

		RebuildRight = function()
			right:SetVisible(mode == "overview")
			if not right:IsVisible() then return end

			for _, c in ipairs(right:GetChildren()) do
				c:Remove()
			end

			local y = 50

			-- Armes : nom + modèle sur blueprint + bouton MODIFIER
			for _, wk in ipairs(WEAPON_KEYS) do
				local slot = SlotByKey(wk)
				local item = SCPArmory.GetItem(wk, selection[wk])

				local lbl = vgui.Create("DPanel", right)
				lbl:SetPos(24, y)
				lbl:SetSize(rpW - 48, 32)
				lbl:SetMouseInputEnabled(false)
				lbl.Paint = function()
					draw.SimpleText(T(slot.label), "SCPArmory_RoN_Small", 0, 0, COL.red)
					draw.SimpleText(SCPArmory.FrUpper(item and item.name or T("— AUCUNE —")),
						"SCPArmory_RoN_NameSm", 0, 13, COL.text)
				end

				local function OpenModify()
					modifyReturn = "overview"
					curWeaponKey = wk
					mode = "modify"
					RebuildColumn()
				end

				local cell = CellButton(24, y + 34, rpW - 48, 94, function(_, w2, h2)
					if item and item.icon then
						SCPArmory.DrawWebIcon(item.icon, 10, 8, w2 - 20, h2 - 16)
					elseif not HasModel(item) then
						draw.SimpleText("—", "SCPArmory_RoN_Name", w2 / 2, h2 / 2,
							COL.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end
				end, OpenModify)

				if item and not item.icon and HasModel(item) then
					local mp = vgui.Create("DModelPanel", cell)
					mp:SetPos(8, 5)
					mp:SetSize(rpW - 64, 84)
					mp:SetModel(item.model)
					mp:SetMouseInputEnabled(false)
					FitModelSide(mp)
				end

				local mod = vgui.Create("DButton", cell)
				mod:SetSize(104, 24)
				mod:SetPos(rpW - 48 - 110, 94 - 29)
				mod:SetText("")
				mod.Paint = function(s, w2, h2)
					texCol.r, texCol.g, texCol.b, texCol.a = 255, 255, 255, 255
					Draw9(BackdropMat("holo_plate_hi.png"), 0, 0, w2, h2, 256, 64, 20, 8, texCol)
					draw.SimpleText(T("MODIFIER"), "SCPArmory_RoN_Label", w2 / 2, h2 / 2,
						s:IsHovered() and COL.text or COL.soft, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				mod.DoClick = function()
					surface.PlaySound("ui/buttonclick.wav")
					OpenModify()
				end

				y = y + 138
			end

			-- Grille ÉQUIPEMENT : tactique ×2 + grenade, cellules cliquables
			local head1 = vgui.Create("DPanel", right)
			head1:SetPos(24, y)
			head1:SetSize(rpW - 48, 16)
			head1:SetMouseInputEnabled(false)
			head1.Paint = function()
				draw.SimpleText(T("ÉQUIPEMENT"), "SCPArmory_RoN_Small", 0, 0, COL.red)
			end
			y = y + 20

			local cw = math.floor((rpW - 48 - 12) / 3)
			for i, key in ipairs({ "tactical1", "tactical2", "grenade" }) do
				local slot = SlotByKey(key)
				local item = SCPArmory.GetItem(slot.pool, selection[key])
				local cell = CellButton(24 + (i - 1) * (cw + 6), y, cw, 80, function(_, w2, h2)
					if item and item.icon then
						SCPArmory.DrawWebIcon(item.icon, 6, 4, w2 - 12, h2 - 26)
					end
					draw.SimpleText(item and item.name or "—", "SCPArmory_RoN_Small", w2 / 2, h2 - 12,
						item and COL.soft or COL.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end, function()
					selectReturn = "overview"
					mode = "select"
					selectSlot = slot
					hoverItem = item
					RebuildColumn()
				end)
				if item and not item.icon and HasModel(item) then
					local mp = vgui.Create("DModelPanel", cell)
					mp:SetPos(6, 4)
					mp:SetSize(cw - 12, 52)
					mp:SetModel(item.model)
					mp:SetMouseInputEnabled(false)
					FitModelSide(mp)
				end
			end
			y = y + 86

			-- Grille PROTECTION & APPARENCE : gilet, casque, apparence
			local head2 = vgui.Create("DPanel", right)
			head2:SetPos(24, y)
			head2:SetSize(rpW - 48, 16)
			head2:SetMouseInputEnabled(false)
			head2.Paint = function()
				draw.SimpleText(T("PROTECTION & APPARENCE"), "SCPArmory_RoN_Small", 0, 0, COL.red)
			end
			y = y + 20

			local cells2 = {
				{ key = "armor", icon = "armor" },
				{ key = "helmet", icon = "helmet" },
				{ key = "apparence", icon = "torso" },
			}
			for i, c in ipairs(cells2) do
				local slot = c.key ~= "apparence" and SlotByKey(c.key) or nil
				local item = slot and SCPArmory.GetItem(slot.pool, selection[c.key]) or nil
				local label = slot and (item and item.name or "—") or T("APPARENCE")
				CellButton(24 + (i - 1) * (cw + 6), y, cw, 80, function(s, w2, h2)
					DrawSlotIcon(c.icon, w2 / 2 - 14, 14, 28, s:IsHovered() and COL.text or COL.soft)
					draw.SimpleText(label, "SCPArmory_RoN_Small", w2 / 2, h2 - 12,
						(slot and item) and COL.soft or COL.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end, function()
					if c.key == "apparence" then
						mode = "section"
						legionSection = "apparence"
					else
						selectReturn = "overview"
						mode = "select"
						selectSlot = slot
						hoverItem = item
					end
					RebuildColumn()
				end)
			end
		end

		-- --------------------- DÉPLOYER central : REJOINDRE LA BATAILLE
		local dW = math.min(460, math.floor(ScrW() * 0.3))
		local dBtn = vgui.Create("DButton", frame)
		dBtn:SetSize(dW, 64)
		dBtn:SetPos(math.floor((ScrW() - dW) / 2) + 60, ScrH() - 86)
		dBtn:SetText("")
		dBtn.Paint = function(s, w, h)
			s.hf = Lerp(FrameTime() * 10, s.hf or 0, s:IsHovered() and 1 or 0)
			texCol.r, texCol.g, texCol.b, texCol.a = 255, 255, 255, 255
			Draw9(BackdropMat("holo_plate_hi.png"), 0, 0, w, h, 256, 64, 20, 14, texCol)
			if s.hf > 0.02 then
				surface.SetDrawColor(255, 255, 255, 30 * s.hf)
				surface.DrawRect(8, 8, w - 16, h - 16)
			end
			local em = BackdropMat("holo_emblem.png")
			if em and not em:IsError() then
				surface.SetDrawColor(255, 255, 255, 235)
				surface.SetMaterial(em)
				surface.DrawTexturedRect(18, h / 2 - 15, 30, 30)
			end
			draw.SimpleText(T("DÉPLOYER"), "SCPArmory_RoN_Btn", w / 2, h / 2 - 9,
				COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(T("REJOINDRE LA BATAILLE"), "SCPArmory_RoN_Small", w / 2, h / 2 + 11,
				COL.soft, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if s.flashT then
				local fa = 1 - (RealTime() - s.flashT) / 0.25
				if fa > 0 then
					surface.SetDrawColor(255, 255, 255, 170 * fa)
					surface.DrawRect(0, 0, w, h)
				end
			end
		end
		dBtn.DoClick = function(s)
			s.flashT = RealTime()
			DoDeploy()
		end

		-- ---------------- SAUVEGARDER LE LOADOUT (sans se déployer)
		local sBtn = vgui.Create("DButton", frame)
		sBtn:SetSize(300, 48)
		sBtn:SetPos(ScrW() - 334, ScrH() - 78)
		sBtn:SetText("")
		sBtn.Paint = function(s, w, h)
			texCol.r, texCol.g, texCol.b, texCol.a = 255, 255, 255, 255
			Draw9(BackdropMat("holo_plate.png"), 0, 0, w, h, 256, 64, 20, 12, texCol)
			local saved = s.savedT and (RealTime() - s.savedT) < 1.6
			draw.SimpleText(saved and T("SAUVEGARDÉ") or T("SAUVEGARDER LE LOADOUT"),
				"SCPArmory_RoN_Label", w / 2, h / 2,
				saved and COL.red or (s:IsHovered() and COL.text or COL.soft),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		sBtn.DoClick = function(s)
			SaveSelection(selection, autoChk:GetChecked(), attSel)
			s.savedT = RealTime()
			surface.PlaySound("buttons/button14.wav")
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
