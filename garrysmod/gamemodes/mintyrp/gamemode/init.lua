--[[-------------------------------------------------------------------------
	MintyRP — Server entry point
	Realm: SERVER
---------------------------------------------------------------------------]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

-- Register net strings before modules load receivers / senders
util.AddNetworkString("MintyRP_Notify")
util.AddNetworkString("MintyRP_InventorySync")
util.AddNetworkString("MintyRP_InventoryAction")
util.AddNetworkString("MintyRP_CharacterReady")

include("shared.lua")

local IsValid = IsValid
local CurTime = CurTime
local print = print
local ipairs = ipairs
local player = player
local timer = timer
local string_format = string.format

function GM:Initialize()
	print("[MintyRP] Server initializing...")

	if MintyRP.Database and MintyRP.Database.Initialize then
		MintyRP.Database.Initialize()
	end

	if MintyRP.Inventory and MintyRP.Inventory.Initialize then
		MintyRP.Inventory.Initialize()
	end

	print("[MintyRP] Server ready — map target: rp_rockford_v2b")
end

function GM:PlayerInitialSpawn(ply)
	if not IsValid(ply) or ply:IsBot() then return end

	ply.MintyRP = ply.MintyRP or {}
	ply.MintyRP.Loaded = false
	ply.MintyRP.JoinTime = CurTime()

	print(string_format("[MintyRP] Player connecting: %s (%s)", ply:Nick(), ply:SteamID64() or "unknown"))

	timer.Simple(0.5, function()
		if not IsValid(ply) then return end

		if MintyRP.Player and MintyRP.Player.Load then
			MintyRP.Player.Load(ply)
		end
	end)
end

function GM:PlayerSpawn(ply)
	if not IsValid(ply) then return end

	player_manager.SetPlayerClass(ply, "player_mintyrp")
	ply:UnSpectate()
	ply:SetupHands()

	local spawn = MintyRP.Locations and MintyRP.Locations.GetDefaultSpawn and MintyRP.Locations.GetDefaultSpawn()
	if spawn then
		ply:SetPos(spawn.pos)
		ply:SetEyeAngles(spawn.ang or Angle(0, 0, 0))
	end

	if MintyRP.Player and MintyRP.Player.OnSpawn then
		MintyRP.Player.OnSpawn(ply)
	end
end

function GM:PlayerSetHandsModel(ply, ent)
	local info = player_manager.RunClass(ply, "GetHandsModel")
	if info then
		ent:SetModel(info.model)
		ent:SetSkin(info.skin)
		ent:SetBodyGroups(info.body)
	end
end

function GM:PlayerLoadout(ply)
	ply:StripWeapons()
	ply:StripAmmo()
	ply:Give("weapon_physcannon")
	ply:Give("weapon_physgun")
	ply:Give("gmod_tool")
	ply:Give("weapon_fists")
	return true
end

function GM:PlayerDisconnected(ply)
	if not IsValid(ply) then return end

	if MintyRP.Player and MintyRP.Player.Save then
		MintyRP.Player.Save(ply)
	end
end

function GM:ShutDown()
	for _, ply in ipairs(player.GetAll()) do
		if MintyRP.Player and MintyRP.Player.Save then
			MintyRP.Player.Save(ply)
		end
	end

	if MintyRP.Database and MintyRP.Database.Close then
		MintyRP.Database.Close()
	end
end

print("[MintyRP] Server scripts loaded")
