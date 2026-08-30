include("shared.lua")

function SWEP:DrawHUD()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local tr = ply:GetEyeTrace()
	if not tr or not IsValid(tr.Entity) then return end
	if tr.HitPos:DistToSqr(ply:EyePos()) > (120 * 120) then return end
	if not MintyRP.Property or not MintyRP.Property.IsDoor(tr.Entity) then return end

	local id = tr.Entity:GetNWString("MintyRP_Property", "")
	if id == "" then return end
	local def = MintyRP.Property.Get(id)
	if not def then return end

	local owned = MintyRP.Property.Owned and MintyRP.Property.Owned[id] ~= nil
	local x, y = ScrW() * 0.5, ScrH() * 0.55
	draw.SimpleText(def.name, "DermaDefaultBold", x, y, Color(62, 207, 142), TEXT_ALIGN_CENTER)
	if owned then
		draw.SimpleText("LMB Lock  ·  RMB Unlock", "DermaDefault", x, y + 16, color_white, TEXT_ALIGN_CENTER)
	else
		draw.SimpleText("No keys", "DermaDefault", x, y + 16, Color(200, 120, 120), TEXT_ALIGN_CENTER)
	end
end
