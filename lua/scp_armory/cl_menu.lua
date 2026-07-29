-- SCP Armory — menu de loadout client (Derma), inspiré de l'écran de préparation de Ready or Not

surface.CreateFont("SCPArmory_Title", { font = "Roboto", size = 26, weight = 800 })
surface.CreateFont("SCPArmory_Sub", { font = "Roboto", size = 14, weight = 500 })
surface.CreateFont("SCPArmory_Label", { font = "Roboto", size = 16, weight = 700 })
surface.CreateFont("SCPArmory_Item", { font = "Roboto", size = 15, weight = 600 })
surface.CreateFont("SCPArmory_Small", { font = "Roboto", size = 13, weight = 500 })
surface.CreateFont("SCPArmory_Big", { font = "Roboto", size = 20, weight = 800 })

local COL = {
	bg     = Color(13, 15, 18, 251),
	panel  = Color(21, 24, 29, 255),
	panel2 = Color(28, 32, 38, 255),
	line   = Color(45, 50, 58, 255),
	text   = Color(232, 233, 235, 255),
	dim    = Color(140, 147, 155, 255),
	accent = Color(255, 176, 0, 255),
	danger = Color(205, 70, 58, 255),
	ok     = Color(120, 200, 130, 255),
	shade  = Color(8, 9, 11, 210),
}

local SAVE_DIR = "scp_armory"
local SAVE_FILE = SAVE_DIR .. "/loadout.txt"

local activeMenu = nil

-- ---------------------------------------------------------------- persistence

local function LoadSaved()
	local sel = SCPArmory.DefaultLoadout()
	local auto = true

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
		end
	end

	return sel, auto
end

local function SaveSelection(sel, auto)
	file.CreateDir(SAVE_DIR)
	local tbl = table.Copy(sel)
	tbl.__auto = auto
	file.Write(SAVE_FILE, util.TableToJSON(tbl, true))
end

-- ------------------------------------------------------------------- helpers

local function FitModel(panel)
	local ent = panel:GetEntity()
	if not IsValid(ent) then return end

	local mn, mx = ent:GetRenderBounds()
	local size = 6
	size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
	size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
	size = math.max(size, math.abs(mn.z) + math.abs(mx.z))

	panel:SetFOV(45)
	panel:SetCamPos(Vector(size, size, size * 0.55))
	panel:SetLookAt((mn + mx) * 0.5)
end

local function DrawBar(x, y, w, h, frac, col)
	surface.SetDrawColor(COL.line)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, math.Clamp(frac, 0, 1) * w, h)
end

local function IsLocked(item, clearance)
	return (item.clearance or 1) > clearance
end

-- ---------------------------------------------------------------------- menu

local function OpenMenu()
	if IsValid(activeMenu) then activeMenu:Remove() end

	local selection, autoApply = LoadSaved()
	local clearance = SCPArmory.GetClearance(LocalPlayer())
	local activeSlot = SCPArmory.Slots[1]
	local inspectItem = SCPArmory.GetItem(activeSlot.pool, selection[activeSlot.key])

	local W = math.min(1180, ScrW() - 60)
	local H = math.min(700, ScrH() - 60)

	local frame = vgui.Create("DFrame")
	activeMenu = frame
	frame:SetSize(W, H)
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(true)
	frame:MakePopup()
	frame.Paint = function(_, w, h)
		draw.RoundedBox(6, 0, 0, w, h, COL.bg)
		surface.SetDrawColor(COL.accent)
		surface.DrawRect(0, 0, w, 3)
	end

	-- ------------------------------------------------------------- header

	local header = vgui.Create("DPanel", frame)
	header:Dock(TOP)
	header:SetTall(62)
	header:DockMargin(16, 10, 16, 0)
	header.Paint = function(_, w, h)
		draw.SimpleText("ARMURERIE — FONDATION SCP", "SCPArmory_Title", 0, 4, COL.text)
		draw.SimpleText("FGM EPSILON-11 « NINE-TAILED FOX »  //  SITE-19  //  PRÉPARATION AU DÉPLOIEMENT", "SCPArmory_Sub", 0, 36, COL.dim)

		local badge = "ACCRÉDITATION NIVEAU " .. clearance
		surface.SetFont("SCPArmory_Label")
		local bw = surface.GetTextSize(badge) + 24
		draw.RoundedBox(4, w - bw - 44, 14, bw, 30, COL.panel2)
		draw.SimpleText(badge, "SCPArmory_Label", w - bw - 44 + 12, 29, COL.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local closeBtn = vgui.Create("DButton", header)
	closeBtn:SetSize(30, 30)
	closeBtn:SetText("")
	closeBtn.Paint = function(s, w, h)
		draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and COL.danger or COL.panel2)
		draw.SimpleText("X", "SCPArmory_Label", w / 2, h / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	closeBtn.DoClick = function() frame:Remove() end
	header.PerformLayout = function(_, w)
		closeBtn:SetPos(w - 30, 14)
	end

	-- ----------------------------------------------------------- footer

	local footer = vgui.Create("DPanel", frame)
	footer:Dock(BOTTOM)
	footer:SetTall(58)
	footer:DockMargin(16, 8, 16, 12)
	footer.Paint = nil

	local deployBtn = vgui.Create("DButton", footer)
	deployBtn:Dock(RIGHT)
	deployBtn:SetWide(230)
	deployBtn:SetText("")
	deployBtn.Paint = function(s, w, h)
		draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(255, 196, 60) or COL.accent)
		draw.SimpleText("DÉPLOYER", "SCPArmory_Big", w / 2, h / 2, Color(20, 18, 10), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local autoChk = vgui.Create("DCheckBoxLabel", footer)
	autoChk:Dock(LEFT)
	autoChk:DockMargin(0, 20, 0, 18)
	autoChk:SetWide(340)
	autoChk:SetText("Réappliquer ce chargement au respawn")
	autoChk:SetFont("SCPArmory_Sub")
	autoChk:SetTextColor(COL.dim)
	autoChk:SetValue(autoApply)

	deployBtn.DoClick = function()
		net.Start("SCPArmory_Apply")
		for _, slot in ipairs(SCPArmory.Slots) do
			net.WriteString(selection[slot.key] or "none")
		end
		net.WriteBool(autoChk:GetChecked())
		net.SendToServer()

		SaveSelection(selection, autoChk:GetChecked())
		surface.PlaySound("items/ammo_pickup.wav")
	end

	-- ------------------------------------------------------------- corps

	local body = vgui.Create("DPanel", frame)
	body:Dock(FILL)
	body:DockMargin(16, 12, 16, 0)
	body.Paint = nil

	-- Colonne gauche : emplacements
	local slotCol = vgui.Create("DPanel", body)
	slotCol:Dock(LEFT)
	slotCol:SetWide(240)
	slotCol.Paint = nil

	-- Colonne droite : navigateur d'objets
	local browser = vgui.Create("DPanel", body)
	browser:Dock(RIGHT)
	browser:SetWide(380)
	browser:DockMargin(12, 0, 0, 0)
	browser.Paint = function(_, w, h)
		draw.RoundedBox(6, 0, 0, w, h, COL.panel)
	end

	-- Centre : aperçu opérateur + jauges
	local center = vgui.Create("DPanel", body)
	center:Dock(FILL)
	center:DockMargin(12, 0, 0, 0)
	center.Paint = function(_, w, h)
		draw.RoundedBox(6, 0, 0, w, h, COL.panel)
	end

	-- ------------------------------------------------- centre : opérateur

	local statsPanel = vgui.Create("DPanel", center)
	statsPanel:Dock(BOTTOM)
	statsPanel:SetTall(150)
	statsPanel:DockMargin(14, 0, 14, 12)
	statsPanel.Paint = function(_, w, h)
		local stats = SCPArmory.ComputeStats(selection)

		draw.RoundedBox(4, 0, 0, w, h, COL.panel2)

		draw.SimpleText("CHARGEMENT : " .. stats.class, "SCPArmory_Label", 12, 10, COL.accent)

		local rows = {
			{ "POIDS", string.format("%.1f kg", stats.weight), stats.weight / 30, COL.text },
			{ "MOBILITÉ", stats.mobility .. " %", stats.mobility / 110, stats.mobility >= 65 and COL.ok or COL.danger },
			{ "ARMURE", stats.armor .. " pts", stats.armor / SCPArmory.Config.MaxArmor, COL.text },
			{ "RÉSISTANCE ANORMALE", math.Round(stats.resist * 100) .. " %", stats.resist / 0.5, COL.accent },
		}

		local y = 38
		for _, row in ipairs(rows) do
			draw.SimpleText(row[1], "SCPArmory_Small", 12, y, COL.dim)
			draw.SimpleText(row[2], "SCPArmory_Small", w - 12, y, row[4], TEXT_ALIGN_RIGHT)
			DrawBar(12, y + 16, w - 24, 5, row[3], row[4])
			y = y + 27
		end
	end

	local preview = vgui.Create("DModelPanel", center)
	preview:Dock(FILL)
	preview:DockMargin(14, 34, 14, 8)
	preview:SetModel(LocalPlayer():GetModel())
	preview:SetAnimated(true)
	preview:SetFOV(38)
	preview:SetCamPos(Vector(95, 0, 58))
	preview:SetLookAt(Vector(0, 0, 36))
	preview.LayoutEntity = function(pnl, ent)
		pnl:RunAnimation()
		ent:SetAngles(Angle(0, math.sin(RealTime() * 0.5) * 20 + 30, 0))
	end

	local pent = preview:GetEntity()
	if IsValid(pent) then
		local seq = pent:LookupSequence("idle_all_01")
		if seq and seq > 0 then pent:ResetSequence(seq) end
	end

	center.PaintOver = function(_, w)
		draw.SimpleText("OPÉRATEUR", "SCPArmory_Label", 14, 10, COL.dim)
		draw.SimpleText(LocalPlayer():Nick(), "SCPArmory_Label", w - 14, 10, COL.text, TEXT_ALIGN_RIGHT)
	end

	-- ------------------------------------------- droite : grille + détails

	local poolTitle = vgui.Create("DPanel", browser)
	poolTitle:Dock(TOP)
	poolTitle:SetTall(34)
	poolTitle.Paint = function(_, w, h)
		draw.SimpleText(activeSlot.label, "SCPArmory_Label", 14, h / 2, COL.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(COL.line)
		surface.DrawRect(14, h - 1, w - 28, 1)
	end

	local detail = vgui.Create("DPanel", browser)
	detail:Dock(BOTTOM)
	detail:SetTall(190)
	detail:DockMargin(10, 6, 10, 10)

	local descLabel = vgui.Create("DLabel", detail)
	descLabel:SetFont("SCPArmory_Small")
	descLabel:SetTextColor(COL.dim)
	descLabel:SetWrap(true)
	descLabel:SetContentAlignment(7)
	descLabel:SetMouseInputEnabled(false)

	detail.PerformLayout = function(_, w)
		descLabel:SetPos(12, 32)
		descLabel:SetSize(w - 24, 62)
	end

	detail.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, COL.panel2)
		if not inspectItem then return end

		draw.SimpleText(inspectItem.name, "SCPArmory_Item", 12, 8, COL.text)

		local locked = IsLocked(inspectItem, clearance)
		if (inspectItem.clearance or 1) > 1 then
			local tag = "NIVEAU " .. inspectItem.clearance
			draw.SimpleText(tag, "SCPArmory_Small", w - 12, 10, locked and COL.danger or COL.accent, TEXT_ALIGN_RIGHT)
		end

		local y = 100
		if inspectItem.stats then
			local bars = {
				{ "DÉGÂTS", inspectItem.stats.degats },
				{ "CADENCE", inspectItem.stats.cadence },
				{ "CONTRÔLE", inspectItem.stats.controle },
				{ "PRÉCISION", inspectItem.stats.precision },
			}
			for _, bar in ipairs(bars) do
				if bar[2] then
					draw.SimpleText(bar[1], "SCPArmory_Small", 12, y - 3, COL.dim)
					DrawBar(100, y + 3, w - 152, 5, bar[2] / 100, COL.accent)
					draw.SimpleText(bar[2], "SCPArmory_Small", w - 12, y - 3, COL.text, TEXT_ALIGN_RIGHT)
					y = y + 17
				end
			end
		else
			local infos = {}
			if inspectItem.armor then table.insert(infos, "Armure +" .. inspectItem.armor) end
			if inspectItem.resist then table.insert(infos, "Résistance " .. math.Round(inspectItem.resist * 100) .. " %") end
			if inspectItem.mobilityMod and inspectItem.mobilityMod ~= 0 then table.insert(infos, "Mobilité " .. inspectItem.mobilityMod) end
			table.insert(infos, string.format("%.1f kg", inspectItem.weight or 0))
			draw.SimpleText(table.concat(infos, "   •   "), "SCPArmory_Small", 12, y, COL.text)
			y = y + 17
		end

		if locked then
			draw.SimpleText("ACCRÉDITATION INSUFFISANTE — OBJET VERROUILLÉ", "SCPArmory_Small", 12, h - 20, COL.danger)
		end
	end

	local scroll = vgui.Create("DScrollPanel", browser)
	scroll:Dock(FILL)
	scroll:DockMargin(10, 6, 10, 0)

	local grid = vgui.Create("DIconLayout", scroll)
	grid:Dock(FILL)
	grid:SetSpaceX(8)
	grid:SetSpaceY(8)

	-- --------------------------------------------- gauche : emplacements

	local slotButtons = {}
	local RefreshGrid -- déclarée plus bas

	for _, slot in ipairs(SCPArmory.Slots) do
		local btn = vgui.Create("DButton", slotCol)
		btn:Dock(TOP)
		btn:SetTall(54)
		btn:DockMargin(0, 0, 0, 6)
		btn:SetText("")
		btn.Paint = function(s, w, h)
			local active = (activeSlot == slot)
			draw.RoundedBox(4, 0, 0, w, h, active and COL.panel2 or COL.panel)
			if active then
				surface.SetDrawColor(COL.accent)
				surface.DrawRect(0, 0, 3, h)
			end

			local item = SCPArmory.GetItem(slot.pool, selection[slot.key])
			draw.SimpleText(slot.label, "SCPArmory_Small", 14, 9, active and COL.accent or COL.dim)
			draw.SimpleText(item and item.name or "—", "SCPArmory_Item", 14, 28, COL.text)

			if s:IsHovered() and not active then
				surface.SetDrawColor(255, 255, 255, 8)
				surface.DrawRect(0, 0, w, h)
			end
		end
		btn.DoClick = function()
			activeSlot = slot
			inspectItem = SCPArmory.GetItem(slot.pool, selection[slot.key])
			surface.PlaySound("ui/buttonclick.wav")
			RefreshGrid()
		end
		table.insert(slotButtons, btn)
	end

	-- --------------------------------------------------- grille d'objets

	local function BuildTile(item)
		local tile = grid:Add("DPanel")
		tile:SetSize(104, 130)

		local locked = IsLocked(item, clearance)

		tile.Paint = function(_, w, h)
			draw.RoundedBox(4, 0, 0, w, h, COL.panel2)
			if selection[activeSlot.key] == item.id then
				surface.SetDrawColor(COL.accent)
				surface.DrawOutlinedRect(0, 0, w, h, 2)
			end
		end

		if item.model and file.Exists(item.model, "GAME") then
			local icon = vgui.Create("DModelPanel", tile)
			icon:SetPos(3, 3)
			icon:SetSize(98, 70)
			icon:SetModel(item.model)
			icon:SetMouseInputEnabled(false)
			icon.LayoutEntity = function(_, ent)
				ent:SetAngles(Angle(0, RealTime() * 30 % 360, 0))
			end
			FitModel(icon)
		else
			local glyph = vgui.Create("DPanel", tile)
			glyph:SetPos(3, 3)
			glyph:SetSize(98, 70)
			glyph:SetMouseInputEnabled(false)
			glyph.Paint = function(_, w, h)
				draw.SimpleText("SCP", "SCPArmory_Title", w / 2, h / 2, COL.line, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		local name = vgui.Create("DLabel", tile)
		name:SetPos(8, 76)
		name:SetSize(88, 32)
		name:SetFont("SCPArmory_Small")
		name:SetTextColor(COL.text)
		name:SetWrap(true)
		name:SetContentAlignment(7)
		name:SetText(item.name)
		name:SetMouseInputEnabled(false)

		tile.PaintOver = function(_, w, h)
			draw.SimpleText(string.format("%.1f kg", item.weight or 0), "SCPArmory_Small", 8, h - 16, COL.dim)
			if (item.clearance or 1) > 1 then
				draw.SimpleText("NIV " .. item.clearance, "SCPArmory_Small", w - 8, h - 16, locked and COL.danger or COL.dim, TEXT_ALIGN_RIGHT)
			end
			if locked then
				draw.RoundedBox(4, 0, 0, w, h, COL.shade)
				draw.SimpleText("NIVEAU " .. item.clearance, "SCPArmory_Label", w / 2, h / 2 - 8, COL.danger, TEXT_ALIGN_CENTER)
				draw.SimpleText("REQUIS", "SCPArmory_Small", w / 2, h / 2 + 10, COL.danger, TEXT_ALIGN_CENTER)
			end
		end

		local clickZone = vgui.Create("DButton", tile)
		clickZone:Dock(FILL)
		clickZone:SetText("")
		clickZone.Paint = function() end
		clickZone.DoClick = function()
			inspectItem = item
			if locked then
				surface.PlaySound("buttons/button10.wav")
				return
			end
			selection[activeSlot.key] = item.id
			surface.PlaySound("ui/buttonclick.wav")
		end
	end

	RefreshGrid = function()
		grid:Clear()
		for _, item in ipairs(SCPArmory.Items[activeSlot.pool]) do
			BuildTile(item)
		end
	end

	RefreshGrid()

	-- Mise à jour du texte de description quand l'objet inspecté change
	local lastInspect = nil
	detail.Think = function()
		if inspectItem ~= lastInspect then
			lastInspect = inspectItem
			descLabel:SetText(inspectItem and inspectItem.desc or "")
		end
	end
end

concommand.Add("scp_armory", OpenMenu, nil, "Ouvre l'armurerie de la Fondation SCP.")

net.Receive("SCPArmory_Open", OpenMenu)
