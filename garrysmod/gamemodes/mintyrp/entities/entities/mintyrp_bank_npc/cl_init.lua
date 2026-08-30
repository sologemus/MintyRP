include("shared.lua")

local beaconMat = Material("sprites/light_glow02_add")

function ENT:Draw()
	self:DrawModel()

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local pos = self:GetPos() + Vector(0, 0, 82)
	local ang = Angle(0, ply:EyeAngles().y - 90, 90)

	cam.Start3D2D(pos, ang, 0.15)
		draw.RoundedBox(4, -110, -36, 220, 58, Color(10, 16, 14, 210))
		draw.SimpleTextOutlined(
			self:GetNWString("MintyRP_NPCName", "Bank Teller"),
			"DermaLarge",
			0, -18,
			Color(62, 207, 142),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			2, Color(0, 0, 0, 230)
		)
		draw.SimpleTextOutlined(
			"Press E — Deposit / Withdraw",
			"DermaDefault",
			0, 10,
			Color(235, 235, 230),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			1, Color(0, 0, 0, 220)
		)
	cam.End3D2D()

	-- Vertical beacon so you can spot them across the street
	if self:GetNWBool("MintyRP_Beacon", false) then
		render.SetMaterial(beaconMat)
		local pulse = 120 + math.sin(CurTime() * 3) * 40
		render.DrawSprite(self:GetPos() + Vector(0, 0, 100), 48, 48, Color(62, 207, 142, pulse))
		render.DrawSprite(self:GetPos() + Vector(0, 0, 140), 28, 96, Color(62, 207, 142, pulse * 0.7))
	end
end
