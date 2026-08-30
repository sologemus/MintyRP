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
local util_JSONToTable = util.JSONToTable
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

function Ply.Load(ply)
	if not IsValid(ply) then return end

	local sid = ply:SteamID64()
	if not sid then return end

	local data = Ply.EnsureTable(ply)

	if not MintyRP.Database or not MintyRP.Database.IsReady() then
		print("[MintyRP] Database not ready for " .. ply:Nick())
		return
	end

	local row = MintyRP.Database.GetPlayer(sid)
	if not row then
		MintyRP.Database.CreatePlayer(sid, MintyRP.Config.StartMoney, MintyRP.Config.StartBank, DEFAULT_MODEL)
		row = MintyRP.Database.GetPlayer(sid)
	end

	if row then
		data.money = row.money
		data.bank = row.bank
		data.model = row.model or DEFAULT_MODEL
		data.extra = util_JSONToTable(row.data or "{}") or {}
	else
		data.money = MintyRP.Config.StartMoney
		data.bank = MintyRP.Config.StartBank
		data.model = DEFAULT_MODEL
		data.extra = {}
	end

	local invRows = MintyRP.Database.LoadInventory(sid)
	if MintyRP.Inventory and MintyRP.Inventory.FromDBRows then
		data.inventory = MintyRP.Inventory.FromDBRows(invRows)
	else
		data.inventory = invRows
	end

	data.Loaded = true
	data.LastSave = CurTime()

	if MintyRP.Inventory and MintyRP.Inventory.Sync then
		MintyRP.Inventory.Sync(ply)
	end

	net.Start("MintyRP_CharacterReady")
		net.WriteUInt(math_floor(data.money), 32)
		net.WriteUInt(math_floor(data.bank), 32)
	net.Send(ply)

	MintyRP.Util.Notify(ply, "Welcome to MintyRP.", 0)
	print(string.format("[MintyRP] Loaded %s — $%d", ply:Nick(), data.money))
end

function Ply.Save(ply)
	if not IsValid(ply) then return end

	local data = ply.MintyRP
	if not data or not data.Loaded then return end

	local sid = ply:SteamID64()
	if not sid then return end

	local json = util_TableToJSON(data.extra or {}) or "{}"
	MintyRP.Database.SavePlayer(sid, data.money, data.bank, data.model or DEFAULT_MODEL, json)

	if MintyRP.Inventory and MintyRP.Inventory.ToDBRows then
		MintyRP.Database.SaveInventory(sid, MintyRP.Inventory.ToDBRows(data.inventory))
	end

	data.LastSave = CurTime()
end

function Ply.OnSpawn(ply)
	local data = Ply.EnsureTable(ply)

	ply:SetWalkSpeed(MintyRP.Config.WalkSpeed)
	ply:SetRunSpeed(MintyRP.Config.RunSpeed)
	ply:SetJumpPower(MintyRP.Config.JumpPower)
	ply:SetMaxHealth(100)
	ply:SetHealth(100)
	ply:SetModel(data.model or DEFAULT_MODEL)
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

-- Autosave loop
timer.Create("MintyRP_Autosave", 30, 0, function()
	local interval = MintyRP.Config.SaveInterval or 120
	local now = CurTime()

	for _, ply in ipairs(player.GetAll()) do
		local data = ply.MintyRP
		if data and data.Loaded and (now - (data.LastSave or 0)) >= interval then
			Ply.Save(ply)
		end
	end
end)

print("[MintyRP] Player module registered")
