-- SCP Armory — menu de loadout client (Derma)
-- Réplique des écrans LOADOUT et MODIFY WEAPON de Ready or Not :
-- plein écran sur fond noir, colonne d'équipement à gauche, aperçu en grand,
-- accessoires ARC9 choisis uniquement via ce menu.

surface.CreateFont("SCPArmory_RoN_Huge", { font = "Roboto", size = 46, weight = 200 })
surface.CreateFont("SCPArmory_RoN_Big", { font = "Roboto", size = 30, weight = 300 })
surface.CreateFont("SCPArmory_RoN_Name", { font = "Roboto", size = 21, weight = 500 })
surface.CreateFont("SCPArmory_RoN_NameSm", { font = "Roboto", size = 17, weight = 500 })
surface.CreateFont("SCPArmory_RoN_Label", { font = "Roboto", size = 12, weight = 700 })
surface.CreateFont("SCPArmory_RoN_Small", { font = "Roboto", size = 12, weight = 500 })
surface.CreateFont("SCPArmory_RoN_Btn", { font = "Roboto", size = 15, weight = 800 })

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
	panel  = Color(10, 10, 13, 200),
}

local SAVE_DIR = "scp_armory"
local SAVE_FILE = SAVE_DIR .. "/loadout.txt"

local WEAPON_KEYS = { "primary", "secondary" }

local activeMenu = nil

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

	local selection, autoApply, attSel = LoadSaved()
	local plyModel = LocalPlayer():GetModel()

	local jobName = team.GetName(LocalPlayer():Team()) or ""
	if jobName == "" then jobName = "Opérateur" end

	-- Modes : "overview" (LOADOUT), "modify" (MODIFY WEAPON),
	-- "select" (choix d'un objet), "attselect" (choix d'un accessoire)
	local mode = "overview"
	local curWeaponKey = "primary"
	local selectSlot = nil
	local selectReturn = "overview"
	local attSlot = nil
	local hoverItem = nil
	local hoverAtt = nil

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

	frame.Paint = function(_, w, h)
		surface.SetDrawColor(COL.bg)
		surface.DrawRect(0, 0, w, h)

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
		draw.SimpleText("SCP ARMORY — SITE-19", "SCPArmory_RoN_Small", w - 26, 18, COL.dim, TEXT_ALIGN_RIGHT)
		draw.SimpleText(SCPArmory.FrUpper(jobName), "SCPArmory_RoN_Small", w - 26, 34, COL.faint, TEXT_ALIGN_RIGHT)
	end

	-- ------------------------------------------------------ aperçu central

	local preview = vgui.Create("DModelPanel", frame)
	preview:SetPos(math.floor(ScrW() * 0.28), 0)
	preview:SetSize(math.ceil(ScrW() * 0.72), ScrH())
	preview:SetAnimated(true)
	preview:SetMouseInputEnabled(false)
	preview.LayoutEntity = function(pnl, ent)
		if pnl.CurIsWeapon then
			ent:SetAngles(Angle(0, 30, 0))
		else
			pnl:RunAnimation()
			ent:SetAngles(Angle(0, math.sin(RealTime() * 0.3) * 6 - 8, 0))
		end
	end

	local function SetPreview(mdl, isWeapon)
		if preview.CurModel == mdl and preview.CurIsWeapon == isWeapon then return end
		preview.CurModel = mdl
		preview.CurIsWeapon = isWeapon
		preview:SetModel(mdl)

		local ent = preview:GetEntity()
		if not IsValid(ent) then return end

		if isWeapon then
			local mn, mx = ent:GetRenderBounds()
			local center = (mn + mx) * 0.5
			local size = math.max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z, 8)
			preview:SetFOV(30)
			preview:SetCamPos(center + Vector(-size * 0.55, size * 1.5, size * 0.45))
			preview:SetLookAt(center)
		else
			preview:SetFOV(28)
			preview:SetCamPos(Vector(58, 0, 60))
			preview:SetLookAt(Vector(0, 0, 50))
			local seq = ent:LookupSequence("idle_all_01")
			if seq and seq > 0 then ent:ResetSequence(seq) end
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
		imagePanel.URL = url
		imagePanel:SetVisible(true)
		preview:SetVisible(false)
	end

	local function ShowPreview()
		imagePanel:SetVisible(false)
		preview:SetVisible(true)
	end

	local function RefreshPreview()
		if mode == "modify" or mode == "attselect" then
			local item = CurWeaponItem()
			if item and item.icon then
				ShowImage(item.icon)
				return
			end
			ShowPreview()
			if HasModel(item) then
				SetPreview(item.model, true)
				return
			end
		elseif mode == "select" and hoverItem then
			if hoverItem.icon then
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
			surface.SetDrawColor(s:IsHovered() and COL.text or COL.line)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText("CONFIGURATION", "SCPArmory_RoN_Label", w / 2, h / 2,
				s:IsHovered() and COL.text or COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		cfgBtn.DoClick = function()
			if SCPArmory.OpenConfigMenu then SCPArmory.OpenConfigMenu() end
		end
	end

	-- --------------------------------------------------- colonne de gauche

	local colX, colY = 48, 34
	local colW = 350
	local colH = ScrH() - colY * 2
	local bottomH = 184
	local titleH = 112

	local column = vgui.Create("DPanel", frame)
	column:SetPos(colX, colY)
	column:SetSize(colW, colH)
	column.Paint = function(_, w)
		if mode == "overview" then
			DrawSpacedText("LOADOUT", "SCPArmory_RoN_Huge", 0, 0, COL.text, 8)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 62, 20, 3)
			DrawSpacedText("PRÉPARATION AU DÉPLOIEMENT", "SCPArmory_RoN_Label", 28, 58, COL.red, 2)
			draw.SimpleText(SCPArmory.FrUpper(jobName) .. " — " .. LocalPlayer():Nick(), "SCPArmory_RoN_NameSm", 0, 82, COL.text)
		elseif mode == "modify" or mode == "attselect" then
			local item = CurWeaponItem()
			DrawSpacedText(SCPArmory.FrUpper(item and item.name or "— AUCUNE —"), "SCPArmory_RoN_Big", 0, 8, COL.text, 3)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 52, 20, 3)
			DrawSpacedText(mode == "modify" and "MODIFIER L'ARME" or "CHOIX D'ACCESSOIRE",
				"SCPArmory_RoN_Label", 28, 48, COL.red, 2)
			draw.SimpleText(SlotByKey(curWeaponKey).label, "SCPArmory_RoN_Label", 0, 82, COL.dim)
		else
			DrawSpacedText(selectSlot and selectSlot.label or "", "SCPArmory_RoN_Big", 0, 8, COL.text, 3)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 52, 20, 3)
			DrawSpacedText("SÉLECTION D'ÉQUIPEMENT", "SCPArmory_RoN_Label", 28, 48, COL.red, 2)
		end

		surface.SetDrawColor(COL.line)
		surface.DrawRect(0, titleH - 6, w, 1)
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
			draw.SimpleText("AUCUNE ARME SÉLECTIONNÉE", "SCPArmory_RoN_Label", 16, 16, COL.faint)
			return
		end

		draw.SimpleText(SlotByKey(curWeaponKey).label, "SCPArmory_RoN_Label", 16, 14, COL.red)
		DrawSpacedText(SCPArmory.FrUpper(item.name), "SCPArmory_RoN_Name", 16, 30, COL.text, 1)

		DrawSpacedText("ACCESSOIRES", "SCPArmory_RoN_Label", 16, 148, COL.dim, 2)
		surface.SetDrawColor(COL.line)
		surface.DrawRect(16, 166, w - 32, 1)

		local y = 176
		if item.class and SCPArmory.ARC9Bridge.IsARC9Class(item.class) then
			local slots = SCPArmory.ARC9Bridge.GetSlots(item.class)
			if #slots == 0 then
				draw.SimpleText("AUCUN EMPLACEMENT D'ACCESSOIRE", "SCPArmory_RoN_Small", 16, y, COL.faint)
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
			draw.SimpleText("ARME NON ARC9 — PAS DE RAIL", "SCPArmory_RoN_Small", 16, y, COL.faint)
		end
	end

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
					if item.stats.degats then table.insert(infos, "DÉGÂTS " .. item.stats.degats) end
					if item.stats.cadence then table.insert(infos, "CADENCE " .. item.stats.cadence) end
					if item.stats.controle then table.insert(infos, "CONTRÔLE " .. item.stats.controle) end
					if item.stats.precision then table.insert(infos, "PRÉCISION " .. item.stats.precision) end
				end
				if item.armor then table.insert(infos, "ARMURE +" .. item.armor) end
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
		local stats = SCPArmory.ComputeStats(selection)

		draw.SimpleText("CHARGEMENT", "SCPArmory_RoN_Label", 0, 8, COL.dim)
		draw.SimpleText(stats.class, "SCPArmory_RoN_Label", w - 10, 8, COL.red, TEXT_ALIGN_RIGHT)

		local rows = {
			{ "POIDS", string.format("%.1f KG", stats.weight), stats.weight / 30 },
			{ "MOBILITÉ", stats.mobility .. " %", stats.mobility / 110 },
			{ "ARMURE", stats.armor .. " PTS", stats.armor / SCPArmory.Config.MaxArmor },
		}

		local y = 30
		for _, row in ipairs(rows) do
			draw.SimpleText(row[1], "SCPArmory_RoN_Small", 0, y, COL.dim)
			draw.SimpleText(row[2], "SCPArmory_RoN_Small", w - 10, y, COL.text, TEXT_ALIGN_RIGHT)
			surface.SetDrawColor(COL.lineF)
			surface.DrawRect(0, y + 16, w - 10, 2)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, y + 16, math.Clamp(row[3], 0, 1) * (w - 10), 2)
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
		draw.SimpleText("Réappliquer ce chargement au respawn", "SCPArmory_RoN_Small", 22, h / 2,
			hov and COL.soft or COL.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	autoChk.DoClick = function(s)
		s.checked = not s.checked
		surface.PlaySound("ui/buttonclick.wav")
	end

	local deployBtn = vgui.Create("DButton", bottom)
	deployBtn:SetPos(0, bottomH - 46)
	deployBtn:SetSize(212, 40)
	deployBtn:SetText("")
	deployBtn.Paint = function(s, w, h)
		surface.SetDrawColor(s:IsHovered() and COL.redHi or COL.red)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("DÉPLOYER", "SCPArmory_RoN_Btn", w / 2, h / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	deployBtn.DoClick = function()
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
		net.SendToServer()

		SaveSelection(selection, autoChk:GetChecked(), attSel)
		surface.PlaySound("items/ammo_pickup.wav")

		-- Déployer referme l'armurerie
		frame:Remove()
	end

	local RebuildColumn

	local function GoBack()
		if mode == "attselect" then
			mode = "modify"
			attSlot = nil
		elseif mode == "select" then
			mode = selectReturn
			selectSlot = nil
		elseif mode == "modify" then
			mode = "overview"
		else
			frame:Remove()
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
	end

	local backBtn = vgui.Create("DButton", bottom)
	backBtn:SetPos(222, bottomH - 46)
	backBtn:SetSize(118, 40)
	backBtn:SetText("")
	backBtn.Paint = function(s, w, h)
		surface.SetDrawColor(s:IsHovered() and COL.text or COL.line)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText("RETOUR", "SCPArmory_RoN_Btn", w / 2 - 12, h / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("ESC", "SCPArmory_RoN_Small", w - 10, h / 2, COL.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	backBtn.DoClick = GoBack

	-- --------------------------------------------- construction de la liste

	local function AddSection(label)
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
		btn:DockMargin(0, 0, 10, 0)
		btn:SetTall(tall)
		btn:SetText("")

		if withImage and item and not item.icon and HasModel(item) then
			local icon = vgui.Create("DModelPanel", btn)
			icon:SetPos(0, 4)
			icon:SetSize(170, 46)
			icon:SetModel(item.model)
			icon:SetMouseInputEnabled(false)
			FitModelSide(icon)
		end

		btn.Paint = function(s, w, h)
			local hov = s:IsHovered()
			s.hf = Lerp(FrameTime() * 10, s.hf or 0, hov and 1 or 0)

			if s.hf > 0.01 then
				surface.SetDrawColor(255, 255, 255, 6 * s.hf)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 255 * s.hf)
				surface.DrawRect(-8, 0, 2, h)
			end

			if withImage and item and item.icon then
				SCPArmory.DrawWebIcon(item.icon, 0, 3, 170, 46)
			end

			if withImage then
				draw.SimpleText(slot.label, "SCPArmory_RoN_Label", 0, 52, COL.dim)
				DrawSpacedText(SCPArmory.FrUpper(item and item.name or "— AUCUN —"), "SCPArmory_RoN_Name", 0, 66,
					hov and COL.text or COL.soft, 1)
				if item and item.ammo and item.ammo[1] then
					draw.SimpleText("×" .. item.ammo[1].amount, "SCPArmory_RoN_Small", w - 10, 70,
						COL.faint, TEXT_ALIGN_RIGHT)
				end
			else
				draw.SimpleText(slot.label, "SCPArmory_RoN_Label", 0, 6, COL.dim)
				DrawSpacedText(SCPArmory.FrUpper(item and item.name or "— AUCUN —"), "SCPArmory_RoN_NameSm", 0, 22,
					hov and COL.text or COL.soft, 1)
			end

			surface.SetDrawColor(COL.lineF)
			surface.DrawRect(0, h - 1, w, 1)
		end

		btn.DoClick = function()
			surface.PlaySound("ui/buttonclick.wav")
			if slot.key == "primary" or slot.key == "secondary" then
				-- Comme dans RoN : l'arme principale/secondaire ouvre MODIFY WEAPON
				mode = "modify"
				curWeaponKey = slot.key
			else
				mode = "select"
				selectSlot = slot
				selectReturn = "overview"
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
		btn:DockMargin(0, 0, 10, 0)
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

			if s.hf > 0.01 then
				surface.SetDrawColor(255, 255, 255, 6 * s.hf)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(COL.red.r, COL.red.g, COL.red.b, 255 * s.hf)
				surface.DrawRect(-8, 0, 2, h)
			end
			if equipped then
				surface.SetDrawColor(COL.red)
				surface.DrawRect(-8, 0, 2, h)
			end

			if item.icon then
				SCPArmory.DrawWebIcon(item.icon, 6, 9, 96, 40)
			end

			local nameCol = (equipped or hov) and COL.text or COL.soft
			DrawSpacedText(SCPArmory.FrUpper(item.name), "SCPArmory_RoN_NameSm", 112, 10, nameCol, 1)

			draw.SimpleText(string.format("%.1f KG", item.weight or 0), "SCPArmory_RoN_Small", 112, 32, COL.faint)
			if item.ammo and item.ammo[1] then
				draw.SimpleText("×" .. item.ammo[1].amount, "SCPArmory_RoN_Small", w - 10, 32,
					COL.faint, TEXT_ALIGN_RIGHT)
			end

			surface.SetDrawColor(COL.lineF)
			surface.DrawRect(0, h - 1, w, 1)
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
			draw.SimpleText("‹  RETOUR", "SCPArmory_RoN_Label", 0, 4,
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

		for i, wkey in ipairs(WEAPON_KEYS) do
			local tab = vgui.Create("DButton", tabs)
			tab:SetPos((i - 1) * 170, 0)
			tab:SetSize(164, 33)
			tab:SetText("")
			tab.Paint = function(s, w, h)
				local active = (curWeaponKey == wkey)
				DrawSpacedText(wkey == "primary" and "PRINCIPALE" or "SECONDAIRE", "SCPArmory_RoN_Label",
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
		wbtn:DockMargin(0, 0, 10, 0)
		wbtn:SetTall(62)
		wbtn:SetText("")
		wbtn.Paint = function(s, w, h)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(-8, 0, 2, h)
			draw.SimpleText(slotDef.label .. "  —  CHANGER D'ARME", "SCPArmory_RoN_Label", 0, 8,
				s:IsHovered() and COL.soft or COL.dim)
			DrawSpacedText(SCPArmory.FrUpper(item and item.name or "— AUCUNE —"), "SCPArmory_RoN_Name", 0, 26,
				s:IsHovered() and COL.text or COL.soft, 1)
			surface.SetDrawColor(COL.lineF)
			surface.DrawRect(0, h - 1, w, 1)
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
			btn:DockMargin(0, 0, 10, 0)
			btn:SetTall(52)
			btn:SetText("")
			btn.Paint = function(s, w, h)
				local hov = s:IsHovered()
				local installed = attSel[curWeaponKey][aslot.index]
				local name = installed and SCPArmory.FrUpper(SCPArmory.ARC9Bridge.AttName(installed)) or "—  VIDE  —"

				draw.SimpleText(aslot.name, "SCPArmory_RoN_Label", 0, 6, COL.dim)
				DrawSpacedText(name, "SCPArmory_RoN_NameSm", 0, 24,
					installed and (hov and COL.text or COL.soft) or COL.faint, 1)

				if hov then
					surface.SetDrawColor(COL.red)
					surface.DrawRect(-8, 0, 2, h)
				end
				surface.SetDrawColor(COL.lineF)
				surface.DrawRect(0, h - 1, w, 1)
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
				surface.SetDrawColor(s:IsHovered() and COL.text or COL.line)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText("RETIRER TOUS LES ACCESSOIRES", "SCPArmory_RoN_Label", w / 2, h / 2,
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
		noneBtn:DockMargin(0, 0, 10, 0)
		noneBtn:SetTall(40)
		noneBtn:SetText("")
		noneBtn.Paint = function(s, w, h)
			local equipped = attSel[curWeaponKey][attSlot.index] == nil
			if equipped then
				surface.SetDrawColor(COL.red)
				surface.DrawRect(-8, 0, 2, h)
			end
			DrawSpacedText("—  AUCUN  —", "SCPArmory_RoN_NameSm", 0, 10,
				s:IsHovered() and COL.text or COL.soft, 1)
			surface.SetDrawColor(COL.lineF)
			surface.DrawRect(0, h - 1, w, 1)
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
			btn:DockMargin(0, 0, 10, 0)
			btn:SetTall(44)
			btn:SetText("")
			btn.Paint = function(s, w, h)
				local equipped = attSel[curWeaponKey][attSlot.index] == att.id
				local hov = s:IsHovered()

				if equipped then
					surface.SetDrawColor(COL.red)
					surface.DrawRect(-8, 0, 2, h)
				end
				if hov then
					surface.SetDrawColor(255, 255, 255, 4)
					surface.DrawRect(0, 0, w, h)
				end

				DrawSpacedText(att.name, "SCPArmory_RoN_NameSm", 0, 6,
					(equipped or hov) and COL.text or COL.soft, 1)
				draw.SimpleText(att.cat, "SCPArmory_RoN_Small", w - 10, 26, COL.red, TEXT_ALIGN_RIGHT)
				surface.SetDrawColor(COL.lineF)
				surface.DrawRect(0, h - 1, w, 1)
			end
			btn.OnCursorEntered = function() hoverAtt = att end
			btn.DoClick = function() pick(att.id) end
		end
	end

	RebuildColumn = function()
		scroll:Clear()
		hoverAtt = nil

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
		elseif mode == "modify" then
			descLabel:SetText("")
			BuildModify()
		elseif mode == "attselect" then
			BuildAttSelect()
		else
			AddBackHeader(selectSlot.label, GoBack)
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

		RefreshPreview()
	end

	frame.RebuildColumn = RebuildColumn

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
