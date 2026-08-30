--[[-------------------------------------------------------------------------
	MintyRP — Player data load / save / spawn
	Realm: SERVER
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Player = MintyRP.Player or {}

local Ply = MintyRP.Player
local IsValid = IsValid
local CurTime = CurTime
local math_floor = math.floor
local util_TableToJSON = util.TableToJSON

local DEFAULT_MODEL = "models/player/Group01/male_02.mdl"

function Ply.EnsureTable(ply)
	ply.MintyRP = ply.MintyRP or {}
	local data = ply.MintyRP
	data.money = data.money or MintyRP.Config.StartMoney
	data.bank = data.bank or MintyRP.Config.StartBank
	data.inventory = data.inventory or {}
	data.Loaded = data.Loaded or false
	return data
end

--- Account bootstrap + open character menu (actual char load happens on select/create)
function Ply.Load(ply)
	if not IsValid(ply) then return end

	local sid = ply:SteamID64()
	if not sid then return end

	Ply.EnsureTable(ply)

	if not MintyRP.Database or not MintyRP.Database.IsReady() then
		print("[MintyRP] Database not ready for " .. ply:Nick())
		return
	end

	MintyRP.Database.EnsureAccount(sid)

	if MintyRP.Character and MintyRP.Character.OpenMenu then
		MintyRP.Character.OpenMenu(ply)
	end

	print(string.format("[MintyRP] Account ready for %s — awaiting character", ply:Nick()))
end

function Ply.Save(ply)
	if not IsValid(ply) then return end

	local data = ply.MintyRP
	if not data or not data.Loaded or not data.characterId then return end

	data.extra = data.extra or {}
	if data.appearance then
		data.extra.skin = data.appearance.skin or 0
		data.extra.bodygroups = data.appearance.bodygroups or {}
	end

	local json = util_TableToJSON(data.extra or {}) or "{}"
	MintyRP.Database.SaveCharacter(data.characterId, data.money, data.bank, data.model or DEFAULT_MODEL, json)

	if MintyRP.Inventory and MintyRP.Inventory.ToDBRows then
		MintyRP.Database.SaveInventory(data.characterId, MintyRP.Inventory.ToDBRows(data.inventory))
	end

	data.LastSave = CurTime()
end

function Ply.OnSpawn(ply)
	local data = Ply.EnsureTable(ply)

	if data.InCharacterMenu or not data.Loaded then
		if MintyRP.Character and MintyRP.Character.FreezeForMenu then
			MintyRP.Character.FreezeForMenu(ply)
		end
		return
	end

	ply:SetWalkSpeed(MintyRP.Config.WalkSpeed)
	ply:SetRunSpeed(MintyRP.Config.RunSpeed)
	ply:SetJumpPower(MintyRP.Config.JumpPower)
	ply:SetMaxHealth(100)
	ply:SetHealth(100)
	ply:SetModel(data.model or DEFAULT_MODEL)

	if MintyRP.Character and MintyRP.Character.ApplyAppearance then
		MintyRP.Character.ApplyAppearance(ply, data.appearance or data.extra)
	end
end

function Ply.GetMoney(ply)
	if not IsValid(ply) or not ply.MintyRP then return 0 end
	return ply.MintyRP.money or 0
end

function Ply.SetMoney(ply, amount)
	if not IsValid(ply) then return end
	local data = Ply.EnsureTable(ply)
	data.money = math.max(0, math_floor(tonumber(amount) or 0))
end

function Ply.AddMoney(ply, delta)
	Ply.SetMoney(ply, Ply.GetMoney(ply) + (tonumber(delta) or 0))
end

timer.Create("MintyRP_Autosave", 30, 0, function()
	local interval = MintyRP.Config.SaveInterval or 120
	local now = CurTime()

	for _, ply in ipairs(player.GetAll()) do
		local data = ply.MintyRP
		if data and data.Loaded and data.characterId and (now - (data.LastSave or 0)) >= interval then
			Ply.Save(ply)
		end
	end
end)

print("[MintyRP] Player module registered")
