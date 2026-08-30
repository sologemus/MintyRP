--[[-------------------------------------------------------------------------
	MintyRP — Player class
	Realm: SHARED
---------------------------------------------------------------------------]]

local PLAYER = {}

PLAYER.DisplayName = "MintyRP Citizen"
PLAYER.WalkSpeed = 160
PLAYER.RunSpeed = 240
PLAYER.JumpPower = 160
PLAYER.CrouchedWalkSpeed = 0.3
PLAYER.DuckSpeed = 0.3
PLAYER.UnDuckSpeed = 0.3
PLAYER.TeammateNoCollide = false
PLAYER.AvoidPlayers = false

function PLAYER:SetupDataTables()
end

function PLAYER:Loadout()
	-- Handled in GM:PlayerLoadout
end

function PLAYER:SetModel()
	local mdl = (self.Player.MintyRP and self.Player.MintyRP.model) or "models/player/Group01/male_02.mdl"
	self.Player:SetModel(mdl)
end

function PLAYER:GetHandsModel()
	local playermodel = player_manager.TranslateToPlayerModelName(self.Player:GetModel())
	return player_manager.TranslatePlayerHands(playermodel)
end

player_manager.RegisterClass("player_mintyrp", PLAYER, "player_default")

print("[MintyRP] Player class registered")
