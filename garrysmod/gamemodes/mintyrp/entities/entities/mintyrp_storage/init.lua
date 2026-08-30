AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel(self.Model or "models/props_junk/wood_crate002a.mdl")
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:EnableMotion(false)
	end

	self.MintyRP_StorageId = self.MintyRP_StorageId or ("box_" .. tostring(self:EntIndex()) .. "_" .. tostring(os.time()))
	self.MintyRP_MaxWeight = self.MintyRP_MaxWeight or self.DefaultMaxWeight or 100
	self.MintyRP_OwnerOnly = self.MintyRP_OwnerOnly == true

	self:SetNWString("MintyRP_StorageId", self.MintyRP_StorageId)
	self:SetNWString("MintyRP_StorageName", self.MintyRP_StorageName or "Storage")
	self:SetNWFloat("MintyRP_StorageMaxWeight", self.MintyRP_MaxWeight)

	if MintyRP.Storage and MintyRP.Storage.Ensure then
		MintyRP.Storage.Ensure(self.MintyRP_StorageId, {
			name = self:GetNWString("MintyRP_StorageName", "Storage"),
			max_weight = self.MintyRP_MaxWeight,
			owner_character_id = self.MintyRP_OwnerCharId,
		})
	end

	print("[MintyRP] Storage crate initialized: " .. tostring(self.MintyRP_StorageId))
end

function ENT:Use(activator)
	if not IsValid(activator) or not activator:IsPlayer() then return end
	if not MintyRP.Storage or not MintyRP.Storage.OpenFor then return end
	MintyRP.Storage.OpenFor(activator, self)
end

function ENT:OnRemove()
	-- Contents persist in DB by storage id (crate can be re-placed with same id)
end
