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

-- CharacterReady is handled in modules/character/cl_character.lua (includes RP name)

-- Show bank balance under cash
hook.Add("HUDPaint", "MintyRP_CoreHUD", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end

	local h = ScrH()
	local cash = ply.MintyRP.money or 0
	local bank = ply.MintyRP.bank or 0
	local rpName = ply.MintyRP.rpName or ply:GetNWString("MintyRP_RPName", "")

	if rpName ~= "" then
		draw_SimpleText(rpName, "DermaDefaultBold", 24, h - 86, colDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	draw_SimpleText(
		MintyRP.Util and MintyRP.Util.FormatMoney(cash) or ("$" .. cash),
		"DermaLarge",
		24,
		h - 64,
		colText,
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_BOTTOM
	)

	draw_SimpleText(
		"Bank " .. (MintyRP.Util and MintyRP.Util.FormatMoney(bank) or ("$" .. bank)),
		"DermaDefault",
		24,
		h - 44,
		colDim,
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
