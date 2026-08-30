--[[-------------------------------------------------------------------------
	MintyRP — Global configuration
	Realm: SHARED
---------------------------------------------------------------------------]]

MintyRP.Config = MintyRP.Config or {}

local Config = MintyRP.Config

Config.Map = "rp_rockford_v2b"
Config.MapPrefix = "rp_rockford"

Config.StartMoney = 500
Config.StartBank = 0
Config.MaxInventoryWeight = 50
Config.MaxStackSize = 100

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
