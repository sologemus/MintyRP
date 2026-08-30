--[[-------------------------------------------------------------------------
	MintyRP Keys — lock / unlock owned property doors
	Primary = Lock · Secondary = Unlock
---------------------------------------------------------------------------]]

if SERVER then
	AddCSLuaFile("cl_init.lua")
	AddCSLuaFile("shared.lua")
end

include("shared.lua")

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.4)
	if CLIENT then return end
	self:DoorAction(true)
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.4)
	if CLIENT then return end
	self:DoorAction(false)
end

function SWEP:DoorAction(lock)
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	local tr = ply:GetEyeTrace()
	if not tr or not IsValid(tr.Entity) then return end
	if tr.HitPos:DistToSqr(ply:EyePos()) > (120 * 120) then
		MintyRP.Util.Notify(ply, "Too far from the door.", 2)
		return
	end

	if not MintyRP.Property or not MintyRP.Property.IsDoor(tr.Entity) then
		MintyRP.Util.Notify(ply, "That's not a door.", 2)
		return
	end

	local id, def = MintyRP.Property.GetByDoor(tr.Entity)
	if not id then
		MintyRP.Util.Notify(ply, "This door isn't part of a property.", 2)
		return
	end

	if not MintyRP.Property.IsOwner(ply, id) then
		MintyRP.Util.Notify(ply, "You don't have keys to this property.", 3)
		return
	end

	MintyRP.Property.ApplyLock(id, lock)
	MintyRP.Util.Notify(ply, lock and ("Locked " .. def.name .. ".") or ("Unlocked " .. def.name .. "."), 0)
	ply:EmitSound(lock and "npc/metropolice/gear1.wav" or "npc/metropolice/gear5.wav", 60, 100)
end
