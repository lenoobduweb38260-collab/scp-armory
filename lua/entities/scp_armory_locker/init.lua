AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/props_c17/lockers001a.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:Wake() end
end

function ENT:Use(activator)
	if not IsValid(activator) or not activator:IsPlayer() then return end
	if self.NextUse and self.NextUse > CurTime() then return end
	self.NextUse = CurTime() + 0.5

	self:EmitSound("doors/door_metal_thin_open1.wav", 60)

	net.Start("SCPArmory_Open")
	net.Send(activator)
end
