--[[-------------------------------------------------------------------------
	MintyRP — Global configuration
	Realm: SHARED
---------------------------------------------------------------------------]]

MintyRP.Config = MintyRP.Config or {}

local Config = MintyRP.Config

Config.Map = "rp_rockford_v2b"
Config.MapPrefix = "rp_rockford"

Config.StartMoney = 5000
Config.StartBank = 0
Config.MaxInventoryWeight = 100 -- PERP-style larger bag capacity
Config.MaxStackSize = 100

-- PERP-inspired slot grid (equip 1-2 + bag grid)
Config.InventoryWidth = 10
Config.InventoryHeight = 5
Config.EquipMain = 1
Config.EquipSide = 2
-- Bag slots start at 3 → 3 + W*H - 1

Config.SaveInterval = 120 -- seconds between autosaves

Config.WalkSpeed = 160
Config.RunSpeed = 240
Config.JumpPower = 160

Config.Chat = {
	LocalRadius = 300,
	YellRadius = 600,
	WhisperRadius = 90,
}

print("[MintyRP] Config loaded")
