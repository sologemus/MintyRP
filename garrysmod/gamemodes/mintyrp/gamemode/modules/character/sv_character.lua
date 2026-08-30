--[[-------------------------------------------------------------------------
	MintyRP — Character select / create (server)
	Realm: SERVER
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Character = MintyRP.Character or {}

local Char = MintyRP.Character
local IsValid = IsValid
local math_floor = math.floor
local util_JSONToTable = util.JSONToTable
local util_TableToJSON = util.TableToJSON

local RATE = 0.5

local function rateLimited(ply, key)
	ply.MintyRP = ply.MintyRP or {}
	local now = CurTime()
	local stampKey = "_charRate_" .. key
	if (ply.MintyRP[stampKey] or 0) > now then return true end
	ply.MintyRP[stampKey] = now + RATE
	return false
end

function Char.FreezeForMenu(ply)
	if not IsValid(ply) then return end
	ply:StripWeapons()
	ply:Spectate(OBS_MODE_ROAMING)
	ply:SetMoveType(MOVETYPE_NONE)
	ply:Freeze(true)
	ply.MintyRP = ply.MintyRP or {}
	ply.MintyRP.InCharacterMenu = true
	ply.MintyRP.Loaded = false
end

function Char.ReleaseFromMenu(ply)
	if not IsValid(ply) then return end
	ply.MintyRP.InCharacterMenu = false
	ply:Freeze(false)
	ply:UnSpectate()
	ply:SetMoveType(MOVETYPE_WALK)
	ply:Spawn()
end

function Char.SendList(ply)
	if not IsValid(ply) then return end
	local sid = ply:SteamID64()
	if not sid then return end

	local list = MintyRP.Database.ListCharacters(sid)
	local maxSlots = Char.MaxSlots or 3

	net.Start("MintyRP_CharacterList")
		net.WriteUInt(math.min(#list, maxSlots), 3)
		for i = 1, math.min(#list, maxSlots) do
			local c = list[i]
			net.WriteUInt(c.id, 32)
			net.WriteUInt(c.slot, 3)
			net.WriteString(c.name)
			net.WriteString(c.model)
			net.WriteUInt(math_floor(c.money), 32)
		end
		net.WriteUInt(maxSlots, 3)
	net.Send(ply)
end

function Char.OpenMenu(ply)
	Char.FreezeForMenu(ply)
	Char.SendList(ply)
	net.Start("MintyRP_OpenCharacterMenu")
	net.Send(ply)
end

function Char.ApplyToPlayer(ply, charRow)
	local data = MintyRP.Player.EnsureTable(ply)

	data.characterId = charRow.id
	data.rpName = charRow.name
	data.model = charRow.model
	data.money = charRow.money
	data.bank = charRow.bank
	data.extra = util_JSONToTable(charRow.data or "{}") or {}

	local invRows = MintyRP.Database.LoadInventory(charRow.id)
	if MintyRP.Inventory and MintyRP.Inventory.FromDBRows then
		data.inventory = MintyRP.Inventory.FromDBRows(invRows)
	else
		data.inventory = invRows
	end

	data.Loaded = true
	data.LastSave = CurTime()

	ply:SetNWString("MintyRP_RPName", charRow.name)

	MintyRP.Database.SetLastCharacter(ply:SteamID64(), charRow.id)

	if MintyRP.Inventory and MintyRP.Inventory.Sync then
		MintyRP.Inventory.Sync(ply)
	end

	net.Start("MintyRP_CharacterReady")
		net.WriteUInt(math_floor(data.money), 32)
		net.WriteUInt(math_floor(data.bank), 32)
		net.WriteString(charRow.name)
	net.Send(ply)

	MintyRP.Util.Notify(ply, "Welcome, " .. charRow.name .. ".", 0)
	print(string.format("[MintyRP] %s playing as %s (char #%d)", ply:Nick(), charRow.name, charRow.id))
end

net.Receive("MintyRP_CharacterSelect", function(len, ply)
	if not IsValid(ply) then return end
	if len > 32 then return end
	if rateLimited(ply, "select") then return end
	if ply.MintyRP and ply.MintyRP.Loaded then return end

	local charId = net.ReadUInt(32)
	if charId < 1 then return end

	local sid = ply:SteamID64()
	local row = MintyRP.Database.GetCharacter(charId, sid)
	if not row then
		MintyRP.Util.Notify(ply, "Character not found.", 3)
		return
	end

	Char.ApplyToPlayer(ply, row)
	Char.ReleaseFromMenu(ply)

	-- Starter kit if empty inventory
	timer.Simple(0.5, function()
		if not IsValid(ply) or not ply.MintyRP or not ply.MintyRP.Loaded then return end
		if ply.MintyRP._starterChecked then return end
		ply.MintyRP._starterChecked = true
		local inv = ply.MintyRP.inventory
		if type(inv) == "table" and #inv == 0 then
			hook.Run("MintyRP_PlayerFirstJoin", ply)
		end
	end)
end)

net.Receive("MintyRP_CharacterCreate", function(len, ply)
	if not IsValid(ply) then return end
	if len > 256 then return end
	if rateLimited(ply, "create") then return end
	if ply.MintyRP and ply.MintyRP.Loaded then return end

	local name = net.ReadString()
	local model = net.ReadString()

	if #name > 48 or #model > 128 then return end

	local clean, err = Char.ValidateName(name)
	if not clean then
		local messages = {
			length = "Name must be 3–24 characters.",
			chars = "Name may only use letters, spaces, hyphens, apostrophes.",
			fullname = "Use a first and last name.",
			caps = "Don't use all caps.",
			invalid = "Invalid name.",
		}
		MintyRP.Util.Notify(ply, messages[err] or "Invalid name.", 3)
		return
	end

	if not Char.IsAllowedModel(model) then
		MintyRP.Util.Notify(ply, "That model isn't allowed.", 3)
		return
	end

	local sid = ply:SteamID64()
	local row, createErr = MintyRP.Database.CreateCharacter(sid, clean, model)
	if not row then
		local messages = {
			slots_full = "All character slots are full.",
			db = "Could not create character.",
			account = "Account error.",
		}
		MintyRP.Util.Notify(ply, messages[createErr] or "Create failed.", 3)
		Char.SendList(ply)
		return
	end

	Char.ApplyToPlayer(ply, row)
	Char.ReleaseFromMenu(ply)

	timer.Simple(0.5, function()
		if not IsValid(ply) or not ply.MintyRP then return end
		ply.MintyRP._starterChecked = true
		hook.Run("MintyRP_PlayerFirstJoin", ply)
	end)
end)

print("[MintyRP] Character server loaded")
