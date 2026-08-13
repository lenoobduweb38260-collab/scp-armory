-- SCP Armory — menu d'apparence autonome (bodygroups)
-- Petit panneau style RoN : une ligne par bodygroup autorisé en config,
-- flèches ‹ › pour changer de variante, application immédiate côté serveur.
-- Ouverture : !apparence en chat, ou console scp_armory_apparence.

surface.CreateFont("SCPArmory_BG_Title", { font = "Roboto", size = 24, weight = 300 })
surface.CreateFont("SCPArmory_BG_Label", { font = "Roboto", size = 12, weight = 700 })
surface.CreateFont("SCPArmory_BG_Name", { font = "Roboto", size = 16, weight = 500 })
surface.CreateFont("SCPArmory_BG_Small", { font = "Roboto", size = 12, weight = 500 })

local COL = {
	bg    = Color(8, 8, 10, 252),
	text  = Color(235, 235, 235, 255),
	soft  = Color(205, 205, 208, 255),
	dim   = Color(125, 125, 130, 255),
	faint = Color(75, 75, 80, 255),
	red   = Color(190, 34, 28, 255),
	redHi = Color(225, 52, 44, 255),
	line  = Color(60, 60, 65, 200),
}

local activeBG = nil

local function T(s) return SCPArmory.T(s) end

local function OpenBGMenu()
	if IsValid(activeBG) then activeBG:Remove() end

	-- Bodygroups du playermodel autorisés par la configuration
	local opts = {}
	for _, bg in ipairs(LocalPlayer():GetBodyGroups() or {}) do
		local nm = string.lower(tostring(bg.name or ""))
		if (bg.num or 0) > 1 and SCPArmory.AllowedBodygroups[nm] then
			table.insert(opts, {
				name = nm,
				id = bg.id,
				num = bg.num,
				val = LocalPlayer():GetBodygroup(bg.id) or 0,
			})
		end
	end

	local W = 420
	local H = 148 + #opts * 44

	local frame = vgui.Create("DFrame")
	activeBG = frame
	frame:SetSize(W, H)
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(true)
	frame:MakePopup()
	frame:SetAlpha(0)
	frame:AlphaTo(255, 0.15, 0)
	frame.Paint = function(_, w, h)
		draw.RoundedBox(10, 0, 0, w, h, COL.bg)
		draw.RoundedBoxEx(10, 0, 0, w, 3, COL.red, true, true, false, false)
		draw.SimpleText(T("APPARENCE"), "SCPArmory_BG_Title", 18, 14, COL.text)
		draw.SimpleText(T("BODYGROUPS AUTORISÉS PAR LE SITE"), "SCPArmory_BG_Small", 18, 42, COL.dim)
		if #opts == 0 then
			draw.SimpleText(T("Aucun bodygroup autorisé sur votre modèle."), "SCPArmory_BG_Small", 18, 74, COL.faint)
		end
	end

	local closeBtn = vgui.Create("DButton", frame)
	closeBtn:SetPos(W - 40, 12)
	closeBtn:SetSize(28, 28)
	closeBtn:SetText("")
	closeBtn.Paint = function(s, w, h)
		draw.RoundedBox(2, 0, 0, w, h, s:IsHovered() and COL.red or Color(16, 16, 19))
		draw.SimpleText("X", "SCPArmory_BG_Label", w / 2, h / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	closeBtn.DoClick = function() frame:Remove() end

	for i, opt in ipairs(opts) do
		local row = vgui.Create("DPanel", frame)
		row:SetPos(18, 64 + (i - 1) * 44)
		row:SetSize(W - 36, 40)
		row.Paint = function(_, w, h)
			draw.SimpleText(SCPArmory.FrUpper(opt.name), "SCPArmory_BG_Label", 0, 3, COL.dim)
			draw.SimpleText(T("VARIANTE") .. " " .. (opt.val + 1) .. " / " .. opt.num, "SCPArmory_BG_Name", 0, 17, COL.soft)
			surface.SetDrawColor(COL.line)
			surface.DrawRect(0, h - 1, w, 1)
		end

		local function ArrowBtn(x, txt, dir)
			local b = vgui.Create("DButton", row)
			b:SetPos(x, 6)
			b:SetSize(28, 26)
			b:SetText("")
			b.Paint = function(s, w, h)
				surface.SetDrawColor(s:IsHovered() and COL.text or COL.line)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText(txt, "SCPArmory_BG_Name", w / 2, h / 2 - 1,
					s:IsHovered() and COL.text or COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			b.DoClick = function()
				opt.val = (opt.val + dir) % opt.num
				surface.PlaySound("ui/buttonclick.wav")
			end
		end

		ArrowBtn(W - 36 - 64, "‹", -1)
		ArrowBtn(W - 36 - 30, "›", 1)
	end

	local applyBtn = vgui.Create("DButton", frame)
	applyBtn:SetPos(18, H - 54)
	applyBtn:SetSize(W - 36, 38)
	applyBtn:SetText("")
	applyBtn.Paint = function(s, w, h)
		draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and COL.redHi or COL.red)
		draw.SimpleText(T("APPLIQUER"), "SCPArmory_BG_Label", w / 2, h / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	applyBtn.DoClick = function()
		net.Start("SCPArmory_ApplyBG")
		net.WriteUInt(math.min(#opts, 24), 5)
		for j, opt in ipairs(opts) do
			if j > 24 then break end
			net.WriteString(opt.name)
			net.WriteUInt(math.Clamp(opt.val, 0, 31), 5)
		end
		net.SendToServer()

		surface.PlaySound("buttons/button14.wav")
		frame:AlphaTo(0, 0.12, 0, function()
			if IsValid(frame) then frame:Remove() end
		end)
	end
end

concommand.Add("scp_armory_apparence", OpenBGMenu, nil, "Ouvre le menu d'apparence (bodygroups).")

net.Receive("SCPArmory_OpenBG", OpenBGMenu)
