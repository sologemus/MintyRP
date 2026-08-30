--[[-------------------------------------------------------------------------
	MintyRP — Storage server (Perpheads-style containers)
	Realm: SERVER

	Containers identified by stable storage_id string.
	Personal locker: char_<characterId>
	World crates: box_* placed with mintyrp_setstorage
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Storage = MintyRP.Storage or {}

local Stor = MintyRP.Storage
local INV = MintyRP.Inventory
local IsValid = IsValid
local math_floor = math.floor
local math_min = math.min

util.AddNetworkString("MintyRP_StorageOpen")
util.AddNetworkString("MintyRP_StorageSync")
util.AddNetworkString("MintyRP_StorageClose")
util.AddNetworkString("MintyRP_StorageAction")

local DATA_FILE = "mintyrp/storage_stations.json"
local OPEN_DIST = 180
local RATE = 0.12

Stor.Cache = Stor.Cache or {} -- storage_id → { items = {}, max_weight, name, owner }
Stor.Stations = Stor.Stations or {}

local function charId(ply)
	return ply.MintyRP and tonumber(ply.MintyRP.characterId)
end

local function rateLimited(ply)
	ply.MintyRP = ply.MintyRP or {}
	local now = CurTime()
	if (ply.MintyRP._storRate or 0) > now then return true end
	ply.MintyRP._storRate = now + RATE
	return false
end

function Stor.Ensure(storageId, meta)
	if not storageId or storageId == "" then return nil end
	meta = meta or {}

	if Stor.Cache[storageId] then
		return Stor.Cache[storageId]
	end

	local row = sql.QueryRow("SELECT * FROM mintyrp_storages WHERE storage_id = " .. sql.SQLStr(storageId))
	if not row then
		sql.Query(string.format(
			"INSERT INTO mintyrp_storages (storage_id, name, max_weight, owner_character_id, updated_at) VALUES (%s, %s, %d, %s, %d)",
			sql.SQLStr(storageId),
			sql.SQLStr(meta.name or "Storage"),
			tonumber(meta.max_weight) or Stor.DefaultMaxWeight or 100,
			meta.owner_character_id and tostring(tonumber(meta.owner_character_id)) or "NULL",
			os.time()
		))
		row = sql.QueryRow("SELECT * FROM mintyrp_storages WHERE storage_id = " .. sql.SQLStr(storageId))
	end

	local items = {}
	local rows = sql.Query(
		"SELECT slot, item_id, amount, meta FROM mintyrp_storage_items WHERE storage_id = "
		.. sql.SQLStr(storageId) .. " ORDER BY slot ASC"
	)
	if type(rows) == "table" then
		items = INV.FromDBRows(rows)
	end

	Stor.Cache[storageId] = {
		id = storageId,
		name = (row and row.name) or meta.name or "Storage",
		max_weight = tonumber(row and row.max_weight) or meta.max_weight or Stor.DefaultMaxWeight or 100,
		owner = row and tonumber(row.owner_character_id) or meta.owner_character_id,
		items = items,
	}
	return Stor.Cache[storageId]
end

function Stor.Save(storageId)
	local box = Stor.Cache[storageId]
	if not box then return end

	sql.Query(string.format(
		"UPDATE mintyrp_storages SET name = %s, max_weight = %d, owner_character_id = %s, updated_at = %d WHERE storage_id = %s",
		sql.SQLStr(box.name or "Storage"),
		math_floor(box.max_weight or 100),
		box.owner and tostring(box.owner) or "NULL",
		os.time(),
		sql.SQLStr(storageId)
	))

	sql.Query("DELETE FROM mintyrp_storage_items WHERE storage_id = " .. sql.SQLStr(storageId))
	local rows = INV.ToDBRows(box.items)
	for i = 1, #rows do
		local it = rows[i]
		sql.Query(string.format(
			"INSERT INTO mintyrp_storage_items (storage_id, slot, item_id, amount, meta) VALUES (%s, %d, %s, %d, %s)",
			sql.SQLStr(storageId),
			it.slot or i,
			sql.SQLStr(it.item_id),
			it.amount or 1,
			sql.SQLStr(it.meta or "{}")
		))
	end
end

local function reindex(items)
	for i = 1, #items do
		items[i].slot = i
	end
end

local function canFit(items, maxWeight, itemId, amount)
	local def = INV.GetItem(itemId)
	if not def then return false, "unknown_item" end
	amount = math_floor(tonumber(amount) or 0)
	if amount < 1 then return false, "bad_amount" end
	local add = INV.GetStackWeight(itemId, amount)
	if INV.CalcWeight(items) + add > (maxWeight or 100) + 0.001 then
		return false, "overweight"
	end
	return true
end

local function giveToList(items, itemId, amount, maxStack)
	amount = math_floor(amount)
	local idx, slot = INV.FindSlot(items, itemId)
	if idx and slot and maxStack > 1 then
		local space = maxStack - slot.amount
		if space > 0 then
			local add = math_min(space, amount)
			slot.amount = slot.amount + add
			amount = amount - add
		end
	end
	while amount > 0 do
		local stack = math_min(amount, maxStack)
		items[#items + 1] = {
			slot = #items + 1,
			item_id = itemId,
			amount = stack,
			meta = "{}",
		}
		amount = amount - stack
	end
	reindex(items)
end

local function takeFromList(items, itemId, amount)
	amount = math_floor(amount)
	local remaining = amount
	for i = #items, 1, -1 do
		local slot = items[i]
		if slot and slot.item_id == itemId then
			local take = math_min(slot.amount, remaining)
			slot.amount = slot.amount - take
			remaining = remaining - take
			if slot.amount <= 0 then table.remove(items, i) end
			if remaining <= 0 then break end
		end
	end
	reindex(items)
	return remaining <= 0
end

local function countIn(items, itemId)
	local n = 0
	for i = 1, #items do
		if items[i].item_id == itemId then n = n + items[i].amount end
	end
	return n
end

function Stor.WriteSync(ply, storageId)
	local box = Stor.Ensure(storageId)
	if not box or not IsValid(ply) then return end

	local items = box.items or {}
	local count = math_min(#items, 128)

	net.Start("MintyRP_StorageSync")
		net.WriteString(storageId)
		net.WriteString(box.name or "Storage")
		net.WriteFloat(box.max_weight or 100)
		net.WriteFloat(INV.CalcWeight(items))
		net.WriteUInt(count, 8)
		for i = 1, count do
			net.WriteString(items[i].item_id or "")
			net.WriteUInt(math_min(items[i].amount or 1, 65535), 16)
		end
	net.Send(ply)
end

function Stor.OpenFor(ply, ent)
	if not IsValid(ply) or not IsValid(ent) then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then
		MintyRP.Util.Notify(ply, "Select a character first.", 2)
		return
	end
	if ply:GetPos():DistToSqr(ent:GetPos()) > (OPEN_DIST * OPEN_DIST) then
		MintyRP.Util.Notify(ply, "Too far from storage.", 2)
		return
	end

	local sid = ent.MintyRP_StorageId or ent:GetNWString("MintyRP_StorageId", "")
	if sid == "" then return end

	-- Personal lockers bind to the using character
	if ent.MintyRP_Personal then
		local cid = charId(ply)
		if not cid then return end
		sid = "char_" .. tostring(cid)
		ent.MintyRP_StorageId = sid
		ent:SetNWString("MintyRP_StorageId", sid)
		Stor.Ensure(sid, {
			name = "Personal Locker",
			max_weight = Stor.PersonalMaxWeight or 80,
			owner_character_id = cid,
		})
	else
		local box = Stor.Ensure(sid, {
			name = ent:GetNWString("MintyRP_StorageName", "Storage"),
			max_weight = ent.MintyRP_MaxWeight or ent:GetNWFloat("MintyRP_StorageMaxWeight", 100),
			owner_character_id = ent.MintyRP_OwnerCharId,
		})
		if box.owner and ent.MintyRP_OwnerOnly and box.owner ~= charId(ply) then
			MintyRP.Util.Notify(ply, "This storage is locked.", 3)
			return
		end
	end

	ply.MintyRP.OpenStorageId = sid
	ply.MintyRP.OpenStorageEnt = ent

	if INV and INV.Sync then INV.Sync(ply) end
	Stor.WriteSync(ply, sid)

	net.Start("MintyRP_StorageOpen")
		net.WriteString(sid)
		net.WriteString(Stor.Cache[sid].name or "Storage")
		net.WriteFloat(Stor.Cache[sid].max_weight or 100)
	net.Send(ply)
end

function Stor.Close(ply)
	if not IsValid(ply) or not ply.MintyRP then return end
	local sid = ply.MintyRP.OpenStorageId
	if sid then Stor.Save(sid) end
	ply.MintyRP.OpenStorageId = nil
	ply.MintyRP.OpenStorageEnt = nil
end

--- dir: 1 = inventory → storage (deposit), 2 = storage → inventory (withdraw)
function Stor.Transfer(ply, itemId, amount, dir)
	if not IsValid(ply) or not ply.MintyRP or not ply.MintyRP.Loaded then return false, "loaded" end
	local sid = ply.MintyRP.OpenStorageId
	if not sid then return false, "closed" end

	local ent = ply.MintyRP.OpenStorageEnt
	if IsValid(ent) and ply:GetPos():DistToSqr(ent:GetPos()) > (OPEN_DIST * OPEN_DIST) then
		Stor.Close(ply)
		return false, "far"
	end

	local box = Stor.Ensure(sid)
	if not box then return false, "invalid" end

	local def = INV.GetItem(itemId)
	if not def then return false, "unknown_item" end
	amount = math_floor(tonumber(amount) or 0)
	if amount < 1 or amount > 100 then return false, "bad_amount" end

	if dir == 1 then
		-- Deposit
		if INV.Count(ply, itemId) < amount then return false, "not_enough" end
		local ok, err = canFit(box.items, box.max_weight, itemId, amount)
		if not ok then return false, err end
		if not INV.Take(ply, itemId, amount) then return false, "not_enough" end
		giveToList(box.items, itemId, amount, def.maxStack or 100)
		Stor.Save(sid)
		INV.Sync(ply)
		Stor.WriteSync(ply, sid)
		return true
	elseif dir == 2 then
		-- Withdraw
		if countIn(box.items, itemId) < amount then return false, "not_enough" end
		local ok, err = INV.CanCarry(ply, itemId, amount)
		if not ok then return false, err end
		if not takeFromList(box.items, itemId, amount) then return false, "not_enough" end
		local given = INV.Give(ply, itemId, amount)
		if not given then
			giveToList(box.items, itemId, amount, def.maxStack or 100)
			Stor.Save(sid)
			return false, "overweight"
		end
		Stor.Save(sid)
		INV.Sync(ply)
		Stor.WriteSync(ply, sid)
		return true
	end
	return false, "dir"
end

net.Receive("MintyRP_StorageAction", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if len > 2048 then return end
	if rateLimited(ply) then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end

	local dir = net.ReadUInt(2) -- 1 deposit, 2 withdraw
	local itemId = net.ReadString()
	local amount = net.ReadUInt(8)
	if #itemId < 1 or #itemId > 64 then return end

	local ok, err = Stor.Transfer(ply, itemId, amount, dir)
	if not ok then
		local msg = ({
			overweight = "Not enough weight capacity.",
			not_enough = "Not enough of that item.",
			far = "Too far from storage.",
			closed = "No storage open.",
			unknown_item = "Unknown item.",
		})[err] or "Transfer failed."
		MintyRP.Util.Notify(ply, msg, 3)
	end
end)

net.Receive("MintyRP_StorageClose", function(_, ply)
	if IsValid(ply) then Stor.Close(ply) end
end)

hook.Add("PlayerDisconnected", "MintyRP_StorageClose", function(ply)
	Stor.Close(ply)
end)

-- Placement for world crates / personal lockers
local function saveStations()
	if not file.Exists("mintyrp", "DATA") then file.CreateDir("mintyrp") end
	file.Write(DATA_FILE, util.TableToJSON(Stor.Stations or {}, true) or "[]")
end

local function loadStations()
	Stor.Stations = {}
	if not file.Exists(DATA_FILE, "DATA") then return end
	local decoded = util.JSONToTable(file.Read(DATA_FILE, "DATA") or "")
	if type(decoded) == "table" then Stor.Stations = decoded end
end

local function spawnStation(st)
	local ent = ents.Create("mintyrp_storage")
	if not IsValid(ent) then return nil end
	local pos = st.pos
	if istable(pos) then pos = Vector(pos.x or 0, pos.y or 0, pos.z or 0) end
	local ang = st.ang or Angle(0, 0, 0)
	if istable(ang) and not ang.Yaw then ang = Angle(ang.p or 0, ang.y or 0, ang.r or 0) end

	ent.MintyRP_StorageId = st.id
	ent.MintyRP_StorageName = st.name or "Storage"
	ent.MintyRP_MaxWeight = st.max_weight or 100
	ent.MintyRP_Personal = st.personal == true
	ent.MintyRP_OwnerOnly = st.owner_only == true
	ent.MintyRP_AutoSpawn = true

	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent:Spawn()
	ent:Activate()
	ent:SetNWString("MintyRP_StorageName", ent.MintyRP_StorageName)
	return ent
end

function Stor.SpawnAll()
	for _, ent in ipairs(ents.FindByClass("mintyrp_storage")) do
		if IsValid(ent) and ent.MintyRP_AutoSpawn then ent:Remove() end
	end
	loadStations()
	local n = 0
	for i = 1, #(Stor.Stations or {}) do
		if IsValid(spawnStation(Stor.Stations[i])) then n = n + 1 end
	end
	print("[MintyRP] Spawned " .. n .. " storage crate(s)")
	return n
end

hook.Add("InitPostEntity", "MintyRP_StorageSpawn", function()
	timer.Simple(2.5, Stor.SpawnAll)
end)
hook.Add("PostCleanupMap", "MintyRP_StorageRespawn", function()
	timer.Simple(1.5, Stor.SpawnAll)
end)

concommand.Add("mintyrp_setstorage", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if not IsValid(ply) then return end

	local name = table.concat(args or {}, " ")
	if name == "" then name = "Storage Crate" end
	local id = "box_" .. tostring(os.time())

	loadStations()
	Stor.Stations = Stor.Stations or {}
	Stor.Stations[#Stor.Stations + 1] = {
		id = id,
		name = name,
		max_weight = 100,
		personal = false,
		pos = { x = ply:GetPos().x, y = ply:GetPos().y, z = ply:GetPos().z },
		ang = { p = 0, y = ply:EyeAngles().y, r = 0 },
	}
	saveStations()
	Stor.SpawnAll()
	MintyRP.Util.Notify(ply, "Placed storage '" .. name .. "'", 1)
end)

concommand.Add("mintyrp_setlocker", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if not IsValid(ply) then return end

	local name = table.concat(args or {}, " ")
	if name == "" then name = "Personal Locker" end
	local id = "locker_" .. tostring(os.time())

	loadStations()
	Stor.Stations = Stor.Stations or {}
	Stor.Stations[#Stor.Stations + 1] = {
		id = id,
		name = name,
		max_weight = Stor.PersonalMaxWeight or 80,
		personal = true,
		pos = { x = ply:GetPos().x, y = ply:GetPos().y, z = ply:GetPos().z },
		ang = { p = 0, y = ply:EyeAngles().y, r = 0 },
	}
	saveStations()
	Stor.SpawnAll()
	MintyRP.Util.Notify(ply, "Placed personal locker (per-character)", 1)
end)

concommand.Add("mintyrp_clearstorage", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Stor.Stations = {}
	saveStations()
	Stor.SpawnAll()
	if IsValid(ply) then MintyRP.Util.Notify(ply, "Storage placements cleared.", 0) end
end)

print("[MintyRP] Storage server loaded")
