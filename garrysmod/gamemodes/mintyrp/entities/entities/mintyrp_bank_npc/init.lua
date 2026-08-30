--[[-------------------------------------------------------------------------
	MintyRP Bank NPC
---------------------------------------------------------------------------]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel(self.Model or "models/player/Group01/male_07.mdl")
	self:SetHullType(HULL_HUMAN)
	self:SetHullSizeNormal()
	self:SetNPCState(NPC_STATE_SCRIPT)
	self:SetSolid(SOLID_BBOX)
	self:CapabilitiesAdd(CAP_ANIMATEDFACE)
	self:SetUseType(SIMPLE_USE)
	self:DropToFloor()
	self:SetMaxYawSpeed(90)

	self:SetNWString("MintyRP_NPCName", "Bank Teller")
end

function ENT:Use(activator, caller)
	if IsValid(activator) and activator:IsPlayer() then
		self:OpenBank(activator)
	end
end

function ENT:AcceptInput(name, activator)
	if name == "Use" and IsValid(activator) and activator:IsPlayer() then
		self:OpenBank(activator)
		return true
	end
end

function ENT:OnTakeDamage()
	return 0
end

function ENT:OpenBank(ply)
	if not IsValid(ply) or not ply.MintyRP or not ply.MintyRP.Loaded then return end

	net.Start("MintyRP_BankOpen")
		net.WriteUInt(math.floor(ply.MintyRP.money or 0), 32)
		net.WriteUInt(math.floor(ply.MintyRP.bank or 0), 32)
	net.Send(ply)
end
