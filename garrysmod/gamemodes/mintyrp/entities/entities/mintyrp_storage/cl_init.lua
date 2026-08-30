include("shared.lua")

function ENT:Draw()
	self:DrawModel()

	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if ply:GetPos():DistToSqr(self:GetPos()) > (400 * 400) then return end

	local pos = self:GetPos() + Vector(0, 0, 36)
	local ang = Angle(0, ply:EyeAngles().y - 90, 90)

	cam.Start3D2D(pos, ang, 0.12)
		draw.RoundedBox(4, -100, -24, 200, 42, Color(12, 16, 14, 200))
		draw.SimpleTextOutlined(
			self:GetNWString("MintyRP_StorageName", "Storage"),
			"DermaDefaultBold",
			0, -8,
			Color(62, 207, 142),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			1, Color(0, 0, 0, 220)
		)
		draw.SimpleTextOutlined(
			"Press E — Open",
			"DermaDefault",
			0, 10,
			Color(230, 236, 232),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			1, Color(0, 0, 0, 200)
		)
	cam.End3D2D()
end
