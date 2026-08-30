include("shared.lua")

local beaconMat = Material("sprites/light_glow02_add")

function ENT:Draw()
	self:DrawModel()

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local pos = self:GetPos() + Vector(0, 0, 48)
	local ang = Angle(0, ply:EyeAngles().y - 90, 90)

	cam.Start3D2D(pos, ang, 0.12)
		draw.RoundedBox(4, -90, -28, 180, 48, Color(10, 14, 20, 210))
		draw.SimpleTextOutlined(
			self:GetNWString("MintyRP_ATMName", "ATM"),
			"DermaLarge",
			0, -10,
			Color(120, 190, 255),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			2, Color(0, 0, 0, 230)
		)
		draw.SimpleTextOutlined(
			"Press E — Withdraw / Deposit",
			"DermaDefault",
			0, 12,
			Color(235, 235, 230),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			1, Color(0, 0, 0, 220)
		)
	cam.End3D2D()

	if self:GetNWBool("MintyRP_Beacon", false) then
		render.SetMaterial(beaconMat)
		local pulse = 110 + math.sin(CurTime() * 3) * 35
		render.DrawSprite(self:GetPos() + Vector(0, 0, 56), 36, 36, Color(100, 170, 255, pulse))
	end
end
