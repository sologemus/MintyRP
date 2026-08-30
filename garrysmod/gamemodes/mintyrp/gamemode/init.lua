--[[-------------------------------------------------------------------------
	MintyRP — Server entry point
	Realm: SERVER
---------------------------------------------------------------------------]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

util.AddNetworkString("MintyRP_Notify")
util.AddNetworkString("MintyRP_InventorySync")
util.AddNetworkString("MintyRP_InventoryAction")
util.AddNetworkString("MintyRP_CharacterReady")
util.AddNetworkString("MintyRP_CharacterList")
util.AddNetworkString("MintyRP_OpenCharacterMenu")
util.AddNetworkString("MintyRP_CharacterSelect")
util.AddNetworkString("MintyRP_CharacterCreate")
util.AddNetworkString("MintyRP_PropertyAction")
util.AddNetworkString("MintyRP_PropertySync")
util.AddNetworkString("MintyRP_BankOpen")
util.AddNetworkString("MintyRP_BankAction")
util.AddNetworkString("MintyRP_BankSync")

include("shared.lua")

local IsValid = IsValid
local CurTime = CurTime
local print = print
local ipairs = ipairs
local player = player
local timer = timer
local string_format = string.format

--- Give the standard RP loadout. Safe if a SWEP is missing.
function MintyRP.GiveLoadout(ply)
	if not IsValid(ply) then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end
	if ply.MintyRP.InCharacterMenu then return end

	ply:StripWeapons()
	ply:StripAmmo()

	local function tryGive(class)
		local ok, wep = pcall(function()
			return ply:Give(class, true)
		end)
		if ok and IsValid(wep) then return wep end
		-- Fallback without second arg (older GMod)
		ok, wep = pcall(function()
			return ply:Give(class)
		end)
		if ok and IsValid(wep) then return wep end
		print("[MintyRP] Could not give weapon: " .. tostring(class))
		return nil
	end

	tryGive("weapon_fists")
	tryGive("weapon_physgun")
	local keys = tryGive("mintyrp_keys")
	if IsValid(keys) then
		ply:SelectWeapon("mintyrp_keys")
	else
		ply:SelectWeapon("weapon_physgun")
	end
end

function GM:Initialize()
	print("[MintyRP] Server initializing...")

	if MintyRP.Database and MintyRP.Database.Initialize then
		MintyRP.Database.Initialize()
	end

	if MintyRP.Inventory and MintyRP.Inventory.Initialize then
		MintyRP.Inventory.Initialize()
	end

	if MintyRP.Property and MintyRP.Property.Initialize then
		MintyRP.Property.Initialize()
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

	-- Base gamemode does NOT always call PlayerLoadout — do it ourselves.
	self:PlayerLoadout(ply)

	-- One more pass next tick (fixes listen-server race after char create)
	timer.Simple(0.1, function()
		if IsValid(ply) then
			MintyRP.GiveLoadout(ply)
		end
	end)
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
	MintyRP.GiveLoadout(ply)
	return true
end

function GM:CanPlayerSuicide(ply)
	if ply.MintyRP and (ply.MintyRP.InCharacterMenu or not ply.MintyRP.Loaded) then
		return false
	end
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
