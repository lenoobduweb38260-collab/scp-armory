-- SCP Armory — synchronisation de la configuration + panneau de configuration en jeu
-- Le panneau (superadmin) règle toutes les options du menu, l'image imgur et
-- les jobs autorisés de chaque objet de l'armurerie.

SCPArmory = SCPArmory or {}
SCPArmory.ItemIcons = SCPArmory.ItemIcons or {}
SCPArmory.ItemJobs = SCPArmory.ItemJobs or {}

-- ------------------------------------------------------------- synchronisation

net.Receive("SCPArmory_Config", function()
	local len = net.ReadUInt(16)
	local data = util.JSONToTable(util.Decompress(net.ReadData(len) or "") or "")
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
	text  = Color(235, 235, 235, 255),
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

	-- ------------------------------------------------------------- général

	local checks, nums = {}, {}
	local lockerEntry

	local function AddCheck(key, label)
		local pnl = scroll:Add("DPanel")
		pnl:Dock(TOP)
		pnl:DockMargin(0, 4, 12, 0)
		pnl:SetTall(24)
		pnl.Paint = nil

		local chk = vgui.Create("DCheckBoxLabel", pnl)
		chk:Dock(FILL)
		chk:SetText(label)
		chk:SetFont("SCPArmory_Cfg_Small")
		chk:SetTextColor(COL.text)
		chk:SetValue(SCPArmory.Config[key] and true or false)
		checks[key] = chk
	end

	local function AddNumber(key, label, minV, maxV)
		local pnl = scroll:Add("DPanel")
		pnl:Dock(TOP)
		pnl:DockMargin(0, 2, 12, 0)
		pnl:SetTall(34)
		pnl.Paint = nil

		local slider = vgui.Create("DNumSlider", pnl)
		slider:Dock(FILL)
		slider:SetText(label)
		slider:SetMin(minV)
		slider:SetMax(maxV)
		slider:SetDecimals(0)
		slider:SetValue(SCPArmory.Config[key] or minV)
		slider.Label:SetTextColor(COL.text)
		slider.Label:SetFont("SCPArmory_Cfg_Small")
		nums[key] = slider
	end

	Section("GÉNÉRAL")
	AddCheck("RequireEntity", "N'autoriser le menu et le déploiement qu'à proximité d'une armoire d'armurerie")
	AddCheck("BlockARC9Customize", "Désactiver le menu de personnalisation ARC9 (touche C) — accessoires via l'armurerie uniquement")
	AddCheck("AutoLoadWeapons", "Charger automatiquement les armes des packs installés (ARC9, M9K…) — appliqué au prochain redémarrage")
	AddNumber("UseDistance", "Portée autour de l'armoire (unités)", 60, 512)
	AddNumber("BaseWalkSpeed", "Vitesse de marche de base", 80, 400)
	AddNumber("BaseRunSpeed", "Vitesse de course de base", 150, 700)
	AddNumber("MaxArmor", "Armure maximale", 50, 255)

	do
		local pnl = scroll:Add("DPanel")
		pnl:Dock(TOP)
		pnl:DockMargin(0, 6, 12, 0)
		pnl:SetTall(26)
		pnl.Paint = function(_, _, h)
			draw.SimpleText("Modèle de l'armoire :", "SCPArmory_Cfg_Small", 0, h / 2, COL.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		lockerEntry = vgui.Create("DTextEntry", pnl)
		lockerEntry:Dock(RIGHT)
		lockerEntry:SetWide(620)
		lockerEntry:SetFont("SCPArmory_Cfg_Small")
		lockerEntry:SetText(SCPArmory.Config.LockerModel or "")
	end

	-- ----------------------------------------- objets : images + jobs

	Section("OBJETS — IMAGE IMGUR ET JOBS AUTORISÉS")
	Note("Image : lien direct i.imgur.com en .png ou .jpg (vide = rendu 3D du modèle).")
	Note("Jobs : noms exacts des métiers séparés par des virgules (vide = tous les jobs voient l'objet).")

	local iconEntries, jobEntries = {}, {}

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
				iconEntry:SetFont("SCPArmory_Cfg_Small")
				iconEntry:SetPlaceholderText("https://i.imgur.com/XXXXXXX.png")
				iconEntry:SetText(SCPArmory.ItemIcons[key] or "")
				iconEntries[key] = iconEntry

				local jobEntry = vgui.Create("DTextEntry", row)
				jobEntry:SetFont("SCPArmory_Cfg_Small")
				jobEntry:SetPlaceholderText("Agent de sécurité, Chef des FGM (vide = tous)")
				jobEntry:SetText(table.concat(SCPArmory.ItemJobs[key] or {}, ", "))
				jobEntries[key] = jobEntry

				row.PerformLayout = function(_, w, h)
					prev:SetPos(w - 70, 4)
					iconEntry:SetPos(300, 4)
					iconEntry:SetSize(w - 380, 20)
					jobEntry:SetPos(300, 28)
					jobEntry:SetSize(w - 380, 20)
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

		for key, entry in pairs(jobEntries) do
			payload.jobs[key] = string.Trim(entry:GetValue() or "")
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
