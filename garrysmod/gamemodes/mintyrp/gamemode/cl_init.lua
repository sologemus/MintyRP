--[[-------------------------------------------------------------------------
	MintyRP — Client entry point
	Realm: CLIENT
---------------------------------------------------------------------------]]

include("shared.lua")

local LocalPlayer = LocalPlayer
local IsValid = IsValid
local surface = surface
local draw = draw
local ScrW = ScrW
local ScrH = ScrH
local Color = Color

MintyRP.Client = MintyRP.Client or {}

function GM:Initialize()
	print("[MintyRP] Client initializing...")
end

function GM:InitPostEntity()
	local ply = LocalPlayer()
	if IsValid(ply) then
		ply.MintyRP = ply.MintyRP or {}
	end
end

-- Lightweight spawn HUD cue (no per-frame work beyond text when needed)
local notifyQueue = {}
local NOTIFY_LIFE = 4

net.Receive("MintyRP_Notify", function()
	local msg = net.ReadString()
	local ntype = net.ReadUInt(3)

	if #msg > 256 then return end

	notifyQueue[#notifyQueue + 1] = {
		text = msg,
		type = ntype,
		die = CurTime() + NOTIFY_LIFE,
	}
end)

local typeColors = {
	[0] = Color(220, 220, 220), -- info
	[1] = Color(80, 200, 120),  -- success
	[2] = Color(220, 160, 60),  -- warn
	[3] = Color(220, 80, 80),   -- error
}

hook.Add("HUDPaint", "MintyRP_NotifyPaint", function()
	local ct = CurTime()
	local y = ScrH() * 0.18
	local x = ScrW() * 0.5

	for i = #notifyQueue, 1, -1 do
		local n = notifyQueue[i]
		if ct >= n.die then
			table.remove(notifyQueue, i)
		else
			local col = typeColors[n.type] or typeColors[0]
			draw.SimpleText(n.text, "DermaDefault", x, y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			y = y + 18
		end
	end
end)

-- Suppress default base HUD elements we will replace later
local hide = {
	CHudHealth = true,
	CHudBattery = true,
	CHudAmmo = true,
	CHudSecondaryAmmo = true,
}

function GM:HUDShouldDraw(name)
	if hide[name] then return false end
	return true
end

print("[MintyRP] Client scripts loaded")
