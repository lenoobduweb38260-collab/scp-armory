-- SCP Armory — synchronisation de la configuration + panneau de configuration en jeu
-- Panneau superadmin entièrement stylé dans le thème du menu : sliders, cases,
-- champs texte et listes déroulantes custom. Les jobs autorisés de chaque objet
-- se choisissent dans une liste déroulante multi-sélection alimentée par les
-- métiers réels du serveur.

SCPArmory = SCPArmory or {}
SCPArmory.ItemIcons = SCPArmory.ItemIcons or {}
SCPArmory.ItemJobs = SCPArmory.ItemJobs or {}

-- ------------------------------------------------------------- synchronisation

net.Receive("SCPArmory_Config", function()
	local len = net.ReadUInt(16)
	-- Décompression plafonnée (défense en profondeur, même venant du serveur)
	local data = util.JSONToTable(util.Decompress(net.ReadData(len) or "", 1048576) or "")
	if not istable(data) then return end

	if istable(data.config) then
		for k, v in pairs(data.config) do
			SCPArmory.Config[k] = v
		end
	end

	-- Remise à zéro puis application des icônes / restrictions reçues
	for _, items in pairs(SCPArmory.Items) do
		for _, item in ipairs(items) do
			item.icon = nil
			item.jobs = nil
		end
	end

	SCPArmory.ItemIcons = {}
	if istable(data.icons) then
		for key, url in pairs(data.icons) do
			if isstring(key) and isstring(url) and url ~= "" then
				SCPArmory.ItemIcons[key] = url
			end
		end
	end

	SCPArmory.ItemJobs = {}
	if istable(data.jobs) then
		for key, jobs in pairs(data.jobs) do
			if isstring(key) and istable(jobs) and #jobs > 0 then
				SCPArmory.ItemJobs[key] = jobs
			end
		end
	end

	SCPArmory.ApplyPendingItemConfig()
end)

hook.Add("InitPostEntity", "SCPArmory_RequestConfig", function()
	timer.Simple(3, function()
		net.Start("SCPArmory_RequestConfig")
		net.SendToServer()
	end)
end)

-- ------------------------------------------------------------------ panneau

surface.CreateFont("SCPArmory_Cfg_Title", { font = "Roboto", size = 24, weight = 300 })
surface.CreateFont("SCPArmory_Cfg_Label", { font = "Roboto", size = 13, weight = 700 })
surface.CreateFont("SCPArmory_Cfg_Small", { font = "Roboto", size = 12, weight = 500 })

local COL = {
	bg    = Color(8, 8, 10, 252),
	panel = Color(16, 16, 19, 255),
	field = Color(20, 20, 24, 255),
	text  = Color(235, 235, 235, 255),
	soft  = Color(205, 205, 208, 255),
	dim   = Color(125, 125, 130, 255),
	faint = Color(75, 75, 80, 255),
	red   = Color(190, 34, 28, 255),
	redHi = Color(225, 52, 44, 255),
	line  = Color(60, 60, 65, 200),
}

local POOL_LABELS = {
	{ pool = "primary",   label = "ARMES PRINCIPALES" },
	{ pool = "secondary", label = "ARMES SECONDAIRES" },
	{ pool = "tactical",  label = "ÉQUIPEMENT TACTIQUE" },
	{ pool = "grenade",   label = "GRENADES" },
	{ pool = "armor",     label = "GILETS" },
	{ pool = "helmet",    label = "CASQUES" },
}

-- Métiers réels du serveur (DarkRP crée une team par job)
local function GetAllJobNames()
	local names, seen = {}, {}
	for _, t in pairs(team.GetAllTeams()) do
		local nm = tostring(t.Name or "")
		if nm ~= "" and nm ~= "Unassigned" and nm ~= "Joining/Connecting" and not seen[nm] then
			seen[nm] = true
			table.insert(names, nm)
		end
	end
	table.sort(names)
	return names
end

local activeConfig = nil

function SCPArmory.OpenConfigMenu()
	if not LocalPlayer():IsSuperAdmin() then
		chat.AddText(COL.red, "[ARMURERIE] ", COL.text, "Réservé aux superadmins.")
		return
	end

	if IsValid(activeConfig) then activeConfig:Remove() end

	local W = math.min(1020, ScrW() - 80)
	local H = math.min(760, ScrH() - 60)

	local frame = vgui.Create("DFrame")
	activeConfig = frame
	frame:SetSize(W, H)
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(true)
	frame:MakePopup()
	frame:SetAlpha(0)
	frame:AlphaTo(255, 0.15, 0)
	frame.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, COL.bg)
		surface.SetDrawColor(COL.red)
		surface.DrawRect(0, 0, w, 2)
		draw.SimpleText("CONFIGURATION DE L'ARMURERIE", "SCPArmory_Cfg_Title", 20, 16, COL.text)
		draw.SimpleText("SUPERADMIN — SAUVEGARDÉE CÔTÉ SERVEUR ET DIFFUSÉE À TOUS", "SCPArmory_Cfg_Small", 20, 44, COL.dim)
	end

	local closeBtn = vgui.Create("DButton", frame)
	closeBtn:SetPos(W - 44, 14)
	closeBtn:SetSize(30, 30)
	closeBtn:SetText("")
	closeBtn.Paint = function(s, w, h)
		draw.RoundedBox(2, 0, 0, w, h, s:IsHovered() and COL.red or COL.panel)
		draw.SimpleText("X", "SCPArmory_Cfg_Label", w / 2, h / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	closeBtn.DoClick = function() frame:Remove() end

	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:SetPos(20, 70)
	scroll:SetSize(W - 40, H - 70 - 64)

	local vbar = scroll:GetVBar()
	vbar:SetWide(6)
	vbar.Paint = function() end
	vbar.btnUp.Paint = function() end
	vbar.btnDown.Paint = function() end
	vbar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, COL.faint) end

	-- ------------------------------------------- petits widgets stylés RoN

	local function Section(label)
		local pnl = scroll:Add("DPanel")
		pnl:Dock(TOP)
		pnl:DockMargin(0, 14, 12, 6)
		pnl:SetTall(22)
		pnl.Paint = function(_, w, h)
			draw.SimpleText(label, "SCPArmory_Cfg_Label", 0, 2, COL.red)
			surface.SetDrawColor(COL.line)
			surface.DrawRect(0, h - 1, w, 1)
		end
	end

	local function Note(text)
		local pnl = scroll:Add("DPanel")
		pnl:Dock(TOP)
		pnl:DockMargin(0, 2, 12, 2)
		pnl:SetTall(18)
		pnl.Paint = function()
			draw.SimpleText(text, "SCPArmory_Cfg_Small", 0, 2, COL.dim)
		end
	end

	-- Champ texte sombre (le DTextEntry par défaut jure avec le thème)
	local function StyleEntry(entry, placeholder)
		entry:SetFont("SCPArmory_Cfg_Small")
		entry:SetTextColor(COL.text)
		entry:SetCursorColor(COL.text)
		entry:SetHighlightColor(Color(190, 34, 28, 120))
		entry:SetPaintBackground(false)
		entry.PlaceholderTxt = placeholder
		entry.Paint = function(s, w, h)
			surface.SetDrawColor(COL.field)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(s:IsEditing() and COL.red or COL.line)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			if s:GetText() == "" and not s:IsEditing() and s.PlaceholderTxt then
				draw.SimpleText(s.PlaceholderTxt, "SCPArmory_Cfg_Small", 5, h / 2, COL.faint,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			s:DrawTextEntryText(COL.text, COL.red, COL.text)
		end
	end

	local checks, nums = {}, {}
	local lockerEntry

	local function AddCheck(key, label)
		local btn = scroll:Add("DButton")
		btn:Dock(TOP)
		btn:DockMargin(0, 6, 12, 0)
		btn:SetTall(20)
		btn:SetText("")
		btn.checked = SCPArmory.Config[key] and true or false
		btn.GetChecked = function(s) return s.checked end
		btn.Paint = function(s, _, h)
			local hov = s:IsHovered()
			surface.SetDrawColor(hov and COL.text or COL.line)
			surface.DrawOutlinedRect(0, 3, 14, 14, 1)
			if s.checked then
				surface.SetDrawColor(COL.red)
				surface.DrawRect(3, 6, 8, 8)
			end
			draw.SimpleText(label, "SCPArmory_Cfg_Small", 22, h / 2,
				hov and COL.text or COL.soft, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		btn.DoClick = function(s)
			s.checked = not s.checked
			surface.PlaySound("ui/buttonclick.wav")
		end
		checks[key] = btn
	end

	-- Slider fin façon RoN : étiquette, valeur rouge à droite, piste cliquable
	local function AddNumber(key, label, minV, maxV)
		local pnl = scroll:Add("DPanel")
		pnl:Dock(TOP)
		pnl:DockMargin(0, 6, 12, 0)
		pnl:SetTall(36)
		pnl:SetMouseInputEnabled(true)
		pnl.value = math.Clamp(tonumber(SCPArmory.Config[key]) or minV, minV, maxV)
		pnl.GetValue = function(s) return s.value end

		local function setFromX(s, x)
			local w = s:GetWide()
			if w <= 0 then return end
			s.value = math.Round(minV + math.Clamp(x / w, 0, 1) * (maxV - minV))
		end

		pnl.Paint = function(s, w, h)
			draw.SimpleText(label, "SCPArmory_Cfg_Small", 0, 2, COL.soft)
			draw.SimpleText(math.Round(s.value), "SCPArmory_Cfg_Label", w, 0, COL.red, TEXT_ALIGN_RIGHT)

			local ty = 25
			surface.SetDrawColor(COL.line)
			surface.DrawRect(0, ty, w, 2)
			local frac = (s.value - minV) / (maxV - minV)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, ty, frac * w, 2)
			draw.RoundedBox(2, math.Clamp(frac * w - 4, 0, w - 8), ty - 5, 8, 12,
				s.dragging and COL.redHi or COL.text)
		end
		pnl.OnMousePressed = function(s, mc)
			if mc ~= MOUSE_LEFT then return end
			s.dragging = true
			s:MouseCapture(true)
			setFromX(s, select(1, s:CursorPos()))
		end
		pnl.OnMouseReleased = function(s)
			s.dragging = false
			s:MouseCapture(false)
		end
		pnl.OnCursorMoved = function(s, x)
			if s.dragging then setFromX(s, x) end
		end

		nums[key] = pnl
	end

	-- ------------------------- liste déroulante multi-sélection des jobs

	local openPopup = nil

	local function ClosePopup()
		if IsValid(openPopup) then openPopup:Remove() end
		if IsValid(frame.PopupCatcher) then frame.PopupCatcher:Remove() end
		openPopup = nil
	end

	frame.OnRemove = ClosePopup

	local function JobSummary(set)
		local names = {}
		for nm in pairs(set) do table.insert(names, nm) end
		table.sort(names)
		if #names == 0 then return "TOUS LES JOBS" end
		if #names <= 2 then return SCPArmory.FrUpper(table.concat(names, ", ")) end
		return #names .. " JOBS AUTORISÉS"
	end

	local function OpenJobDropdown(btn, set)
		ClosePopup()

		-- Clic hors de la liste = fermeture
		local catcher = vgui.Create("DButton", frame)
		frame.PopupCatcher = catcher
		catcher:SetPos(0, 0)
		catcher:SetSize(W, H)
		catcher:SetText("")
		catcher.Paint = function() end
		catcher.DoClick = ClosePopup

		-- Jobs du serveur + jobs déjà configurés mais absents de la map
		local names = GetAllJobNames()
		local seen = {}
		for _, nm in ipairs(names) do seen[nm] = true end
		for nm in pairs(set) do
			if not seen[nm] then table.insert(names, nm) end
		end

		local jobColors = {}
		for id, t in pairs(team.GetAllTeams()) do
			if isstring(t.Name) then jobColors[t.Name] = team.GetColor(id) end
		end

		local rowH = 24
		local listH = math.min(#names * rowH, 10 * rowH)
		local popW = 340
		local popH = listH + 30

		local bx, by = btn:LocalToScreen(0, btn:GetTall())
		local fx, fy = frame:LocalToScreen(0, 0)
		local px = math.Clamp(bx - fx, 8, W - popW - 8)
		local py = by - fy + 2
		if py + popH > H - 8 then
			py = (by - fy) - btn:GetTall() - popH - 2
		end

		local pop = vgui.Create("DPanel", frame)
		openPopup = pop
		pop:SetPos(px, py)
		pop:SetSize(popW, popH)
		pop:MoveToFront()
		pop.Paint = function(_, w, h)
			surface.SetDrawColor(12, 12, 15, 252)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COL.red)
			surface.DrawRect(0, 0, w, 2)
			surface.SetDrawColor(COL.line)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText("JOBS AUTORISÉS — AUCUN COCHÉ = TOUS", "SCPArmory_Cfg_Small", 8, 8, COL.dim)
		end

		local list = vgui.Create("DScrollPanel", pop)
		list:SetPos(1, 26)
		list:SetSize(popW - 2, popH - 27)

		local lbar = list:GetVBar()
		lbar:SetWide(4)
		lbar.Paint = function() end
		lbar.btnUp.Paint = function() end
		lbar.btnDown.Paint = function() end
		lbar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, COL.faint) end

		for _, nm in ipairs(names) do
			local row = list:Add("DButton")
			row:Dock(TOP)
			row:SetTall(rowH)
			row:SetText("")
			row.Paint = function(s, w, h)
				if s:IsHovered() then
					surface.SetDrawColor(255, 255, 255, 8)
					surface.DrawRect(0, 0, w, h)
				end
				surface.SetDrawColor(s:IsHovered() and COL.text or COL.line)
				surface.DrawOutlinedRect(8, 5, 14, 14, 1)
				if set[nm] then
					surface.SetDrawColor(COL.red)
					surface.DrawRect(11, 8, 8, 8)
				end
				local col = set[nm] and COL.text or COL.soft
				draw.SimpleText(nm, "SCPArmory_Cfg_Small", 30, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				local teamCol = jobColors[nm]
				if teamCol then
					surface.SetDrawColor(teamCol.r, teamCol.g, teamCol.b, 255)
					surface.DrawRect(w - 14, 8, 6, 8)
				end
			end
			row.DoClick = function()
				set[nm] = (not set[nm]) or nil
				surface.PlaySound("ui/buttonclick.wav")
			end
		end
	end

	-- ------------------------------------------------------------- général

	Section("GÉNÉRAL")
	AddCheck("RequireEntity", "N'autoriser le menu et le déploiement qu'à proximité d'une armoire d'armurerie")
	AddCheck("BlockARC9Customize", "Désactiver le menu de personnalisation ARC9 (touche C) — accessoires via l'armurerie uniquement")
	AddCheck("AutoLoadWeapons", "Charger automatiquement les armes des packs installés (ARC9, M9K…) — appliqué au prochain redémarrage")
	AddCheck("MenuScene", "Décor 3D dans le menu : armoires et caisses derrière l'opérateur, caisse d'armes sous l'arme")
	AddNumber("UseDistance", "Portée autour de l'armoire (unités)", 60, 512)

	Section("JOURNAUX")
	AddCheck("LogToFile", "Écrire les logs dans data/scp_armory/logs/ (un fichier par jour)")
	AddCheck("LogToConsole", "Afficher les logs dans la console serveur")
	AddNumber("LogRetentionDays", "Conservation des fichiers de logs (jours, 0 = illimité)", 0, 365)

	Section("AFFICHAGE & GAMEPLAY")
	AddNumber("PreviewDistance", "Distance de la caméra sur l'opérateur (plus grand = plus loin)", 60, 250)
	AddNumber("BaseWalkSpeed", "Vitesse de marche de base", 80, 400)
	AddNumber("BaseRunSpeed", "Vitesse de course de base", 150, 700)
	AddNumber("MaxArmor", "Armure maximale", 50, 255)

	do
		local pnl = scroll:Add("DPanel")
		pnl:Dock(TOP)
		pnl:DockMargin(0, 8, 12, 0)
		pnl:SetTall(26)
		pnl.Paint = function(_, _, h)
			draw.SimpleText("Modèle de l'armoire", "SCPArmory_Cfg_Small", 0, h / 2, COL.soft, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		lockerEntry = vgui.Create("DTextEntry", pnl)
		lockerEntry:Dock(RIGHT)
		lockerEntry:SetWide(620)
		lockerEntry:SetText(SCPArmory.Config.LockerModel or "")
		StyleEntry(lockerEntry, "models/props_c17/FurnitureDrawer001a.mdl")
	end

	-- ----------------------------------------- objets : images + jobs

	Section("OBJETS — IMAGE IMGUR ET JOBS AUTORISÉS")
	Note("Image : lien direct i.imgur.com en .png ou .jpg (vide = rendu 3D du modèle).")
	Note("Jobs : liste déroulante multi-sélection alimentée par les métiers du serveur. Aucun job coché = visible par tous.")

	local iconEntries, jobSelections = {}, {}

	for _, group in ipairs(POOL_LABELS) do
		local items = SCPArmory.Items[group.pool] or {}
		local shown = {}
		for _, item in ipairs(items) do
			if item.id ~= "none" then table.insert(shown, item) end
		end

		if #shown > 0 then
			local head = scroll:Add("DPanel")
			head:Dock(TOP)
			head:DockMargin(0, 10, 12, 2)
			head:SetTall(18)
			head.Paint = function()
				draw.SimpleText(group.label, "SCPArmory_Cfg_Small", 0, 2, COL.faint)
			end

			for _, item in ipairs(shown) do
				local key = group.pool .. "/" .. item.id

				-- Sélection actuelle des jobs pour cet objet
				local set = {}
				for _, nm in ipairs(SCPArmory.ItemJobs[key] or {}) do set[nm] = true end
				jobSelections[key] = set

				local row = scroll:Add("DPanel")
				row:Dock(TOP)
				row:DockMargin(0, 3, 12, 0)
				row:SetTall(52)
				row.Paint = function(_, w, h)
					draw.SimpleText(item.name, "SCPArmory_Cfg_Small", 0, 4, COL.text)
					draw.SimpleText("IMAGE", "SCPArmory_Cfg_Small", 250, 8, COL.faint)
					draw.SimpleText("JOBS", "SCPArmory_Cfg_Small", 250, 32, COL.faint)
					surface.SetDrawColor(COL.line)
					surface.DrawRect(0, h - 1, w, 1)
				end

				-- Aperçu de l'image une fois chargée
				local prev = vgui.Create("DPanel", row)
				prev:SetSize(64, 44)
				prev.Paint = function(_, w, h)
					surface.SetDrawColor(COL.line)
					surface.DrawOutlinedRect(0, 0, w, h, 1)
					local url = iconEntries[key] and iconEntries[key]:GetValue() or ""
					if url ~= "" then
						SCPArmory.DrawWebIcon(url, 2, 2, w - 4, h - 4)
					end
				end

				local iconEntry = vgui.Create("DTextEntry", row)
				iconEntry:SetText(SCPArmory.ItemIcons[key] or "")
				StyleEntry(iconEntry, "https://i.imgur.com/XXXXXXX.png")
				iconEntries[key] = iconEntry

				-- Liste déroulante des jobs autorisés
				local jobBtn = vgui.Create("DButton", row)
				jobBtn:SetText("")
				jobBtn.Paint = function(s, w, h)
					surface.SetDrawColor(COL.field)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(s:IsHovered() and COL.red or COL.line)
					surface.DrawOutlinedRect(0, 0, w, h, 1)
					local summary = JobSummary(set)
					local col = next(set) and COL.text or COL.faint
					draw.SimpleText(summary, "SCPArmory_Cfg_Small", 6, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText("▼", "SCPArmory_Cfg_Small", w - 8, h / 2, COL.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				end
				jobBtn.DoClick = function(s)
					surface.PlaySound("ui/buttonclick.wav")
					OpenJobDropdown(s, set)
				end

				row.PerformLayout = function(_, w, h)
					prev:SetPos(w - 70, 4)
					iconEntry:SetPos(300, 4)
					iconEntry:SetSize(w - 380, 20)
					jobBtn:SetPos(300, 28)
					jobBtn:SetSize(w - 380, 20)
				end
			end
		end
	end

	-- ------------------------------------------------------------ boutons

	local saveBtn = vgui.Create("DButton", frame)
	saveBtn:SetPos(20, H - 52)
	saveBtn:SetSize(260, 38)
	saveBtn:SetText("")
	saveBtn.Paint = function(s, w, h)
		surface.SetDrawColor(s:IsHovered() and COL.redHi or COL.red)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("ENREGISTRER ET DIFFUSER", "SCPArmory_Cfg_Label", w / 2, h / 2,
			COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	saveBtn.DoClick = function()
		local payload = { config = {}, icons = {}, jobs = {} }

		for key, chk in pairs(checks) do
			payload.config[key] = chk:GetChecked() and true or false
		end
		for key, slider in pairs(nums) do
			payload.config[key] = slider:GetValue()
		end
		payload.config.LockerModel = lockerEntry:GetValue()

		for key, entry in pairs(iconEntries) do
			local url = string.Trim(entry:GetValue() or "")
			if url == "" or string.find(url, "^https?://") then
				payload.icons[key] = url
			end
		end

		for key, set in pairs(jobSelections) do
			local list = {}
			for nm in pairs(set) do table.insert(list, nm) end
			table.sort(list)
			payload.jobs[key] = list
		end

		local comp = util.Compress(util.TableToJSON(payload))
		if not comp or #comp > 60000 then
			chat.AddText(COL.red, "[ARMURERIE] ", COL.text, "Configuration trop volumineuse.")
			return
		end

		net.Start("SCPArmory_SaveConfig")
		net.WriteUInt(#comp, 16)
		net.WriteData(comp, #comp)
		net.SendToServer()

		surface.PlaySound("buttons/button14.wav")
		frame:Remove()
	end

	local cancelBtn = vgui.Create("DButton", frame)
	cancelBtn:SetPos(290, H - 52)
	cancelBtn:SetSize(130, 38)
	cancelBtn:SetText("")
	cancelBtn.Paint = function(s, w, h)
		surface.SetDrawColor(s:IsHovered() and COL.text or COL.line)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText("ANNULER", "SCPArmory_Cfg_Label", w / 2, h / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	cancelBtn.DoClick = function() frame:Remove() end
end

concommand.Add("scp_armory_config", SCPArmory.OpenConfigMenu, nil,
	"Ouvre le panneau de configuration de l'armurerie (superadmin).")

net.Receive("SCPArmory_OpenConfig", SCPArmory.OpenConfigMenu)
