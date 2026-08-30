include("shared.lua")

function ENT:Draw()
	self:DrawModel()

	local pos = self:GetPos() + Vector(0, 0, 78)
	local ang = LocalPlayer():EyeAngles()
	ang = Angle(0, ang.y - 90, 90)

	cam.Start3D2D(pos, ang, 0.12)
		draw.SimpleTextOutlined(
			self:GetNWString("MintyRP_NPCName", "Bank Teller"),
			"DermaLarge",
			0, 0,
			Color(62, 207, 142),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			1, Color(0, 0, 0, 200)
		)
		draw.SimpleTextOutlined(
			"Press E — Deposit / Withdraw",
			"DermaDefault",
			0, 28,
			Color(220, 220, 220),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			1, Color(0, 0, 0, 200)
		)
	cam.End3D2D()
end
