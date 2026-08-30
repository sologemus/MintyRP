SWEP.PrintName = "Keys"
SWEP.Author = "MintyRP"
SWEP.Instructions = "Primary: Lock owned property\nSecondary: Unlock owned property"
SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.Spawnable = false
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = true
SWEP.ViewModelFOV = 50

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:Deploy()
	self:SetHoldType("normal")
	return true
end

function SWEP:Holster()
	return true
end

function SWEP:Reload()
end
