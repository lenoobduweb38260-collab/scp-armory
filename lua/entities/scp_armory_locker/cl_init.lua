include("shared.lua")

surface.CreateFont("SCPArmory_3D2D", { font = "Roboto", size = 64, weight = 800 })
surface.CreateFont("SCPArmory_3D2D_Small", { font = "Roboto", size = 28, weight = 500 })

local COL_ACCENT = Color(255, 176, 0, 255)
local COL_TEXT = Color(232, 233, 235, 255)
local COL_BG = Color(13, 15, 18, 200)

function ENT:Draw()
	self:DrawModel()

	-- Étiquette 3D2D visible à moins de 500 unités, face au joueur
	if EyePos():DistToSqr(self:GetPos()) > 250000 then return end

	local pos = self:GetPos() + Vector(0, 0, 80)
	local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

	cam.Start3D2D(pos, ang, 0.06)
		draw.RoundedBox(8, -220, -50, 440, 100, COL_BG)
		surface.SetDrawColor(COL_ACCENT)
		surface.DrawRect(-220, -50, 440, 3)
		draw.SimpleText("ARMURERIE", "SCPArmory_3D2D", 0, -28, COL_ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Fondation SCP — Appuyez sur [E]", "SCPArmory_3D2D_Small", 0, 22, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
