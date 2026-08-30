--[[-------------------------------------------------------------------------
	MintyRP — Bank shared (teller stations)
	Realm: SHARED
---------------------------------------------------------------------------]]

MintyRP.Bank = MintyRP.Bank or {}

local Bank = MintyRP.Bank
local Vector = Vector
local Angle = Angle

-- Default stations. Placeholders until pinned with mintyrp_setteller.
-- Host: stand where you want a teller → mintyrp_setteller "Name"
-- spawn_kiosk sits at civilian spawn so new players always see a teller.
Bank.DefaultStations = {
	{ id = "spawn_kiosk", name = "City Spawn Kiosk", pos = Vector(-2890, -1350, 72), ang = Angle(0, 90, 0) },
	{ id = "bank_main", name = "Rockford Bank", pos = Vector(-3200, 400, 80), ang = Angle(0, 90, 0) },
	{ id = "gas_downtown", name = "Downtown Gas Desk", pos = Vector(-3600, -200, 72), ang = Angle(0, 0, 0) },
	{ id = "gas_industrial", name = "Industrial Gas Desk", pos = Vector(3800, -200, 64), ang = Angle(0, 180, 0) },
	{ id = "gas_suburb", name = "Suburban Gas Desk", pos = Vector(-5500, -2200, 72), ang = Angle(0, 90, 0) },
}

print("[MintyRP] Bank shared loaded")
