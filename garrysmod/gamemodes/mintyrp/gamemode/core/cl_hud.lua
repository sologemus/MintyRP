--[[-------------------------------------------------------------------------
	MintyRP — Minimal client HUD
	Realm: CLIENT
---------------------------------------------------------------------------]]

if not CLIENT then return end

local LocalPlayer = LocalPlayer
local IsValid = IsValid
local draw_SimpleText = draw.SimpleText
local ScrW = ScrW
local ScrH = ScrH
local Color = Color
local TEXT_ALIGN_LEFT = TEXT_ALIGN_LEFT
local TEXT_ALIGN_BOTTOM = TEXT_ALIGN_BOTTOM

local colText = Color(235, 235, 230)
local colDim = Color(180, 180, 175)
local money = 0
local bank = 0

net.Receive("MintyRP_CharacterReady", function()
	money = net.ReadUInt(32)
	bank = net.ReadUInt(32)

	local ply = LocalPlayer()
	if IsValid(ply) then
		ply.MintyRP = ply.MintyRP or {}
		ply.MintyRP.money = money
		ply.MintyRP.bank = bank
		ply.MintyRP.Loaded = true
	end
end)

-- Update cached money when inventory sync also carries economy (future)
hook.Add("HUDPaint", "MintyRP_CoreHUD", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end

	local w, h = ScrW(), ScrH()
	local cash = ply.MintyRP.money or money

	draw_SimpleText(
		MintyRP.Util and MintyRP.Util.FormatMoney(cash) or ("$" .. cash),
		"DermaLarge",
		24,
		h - 48,
		colText,
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_BOTTOM
	)

	draw_SimpleText(
		"MintyRP",
		"DermaDefault",
		24,
		h - 28,
		colDim,
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_BOTTOM
	)
end)

print("[MintyRP] Client HUD loaded")
