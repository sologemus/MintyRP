--[[-------------------------------------------------------------------------
	MintyRP Bank Teller — usable anim entity
---------------------------------------------------------------------------]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel(self.Model or "models/player/Group01/male_07.mdl")
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	self:SetUseType(SIMPLE_USE)
	self:SetCollisionBounds(Vector(-18, -18, 0), Vector(18, 18, 72))

	local seq = self:LookupSequence("idle_all_01")
	if seq and seq >= 0 then
		self:ResetSequence(seq)
		self:SetCycle(0)
		self:SetPlaybackRate(1)
	end

	self:SetNWString("MintyRP_NPCName", "Bank Teller")
	print("[MintyRP] Bank teller entity initialized")
end

function ENT:Think()
	self:NextThink(CurTime() + 0.5)
	return true
end

function ENT:OnTakeDamage()
	return 0
end

function ENT:AcceptInput(name, activator, caller)
	if name == "Use" and IsValid(activator) and activator:IsPlayer() then
		self:OpenFor(activator)
		return true
	end
end

function ENT:Use(activator, caller)
	if IsValid(activator) and activator:IsPlayer() then
		self:OpenFor(activator)
	end
end

function ENT:OpenFor(ply)
	if not IsValid(ply) then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then
		if MintyRP.Util then
			MintyRP.Util.Notify(ply, "Select a character first.", 2)
		end
		return
	end

	net.Start("MintyRP_BankOpen")
		net.WriteUInt(math.floor(ply.MintyRP.money or 0), 32)
		net.WriteUInt(math.floor(ply.MintyRP.bank or 0), 32)
	net.Send(ply)
end
