AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	local mdl = self.Model or "models/props_unique/atm01.mdl"
	self:SetModel(mdl)
	if self:GetModel() == "models/error.mdl" then
		self:SetModel("models/props_lab/reciever_cart.mdl")
	end

	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	self:SetNWString("MintyRP_ATMName", "ATM")
	self:SetNWBool("MintyRP_Beacon", true)
	print("[MintyRP] ATM entity initialized")
end

function ENT:OnTakeDamage()
	return 0
end

function ENT:Use(activator)
	if not IsValid(activator) or not activator:IsPlayer() then return end
	if not activator.MintyRP or not activator.MintyRP.Loaded then
		if MintyRP.Util then
			MintyRP.Util.Notify(activator, "Select a character first.", 2)
		end
		return
	end

	net.Start("MintyRP_BankOpen")
		net.WriteUInt(math.floor(activator.MintyRP.money or 0), 32)
		net.WriteUInt(math.floor(activator.MintyRP.bank or 0), 32)
		net.WriteBool(true) -- is ATM
	net.Send(activator)
end
