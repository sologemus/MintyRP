--[[-------------------------------------------------------------------------
	MintyRP — Property / doors (server)
	Realm: SERVER

	Per-door ownership (DarkRP / Perpheads style):
	  • Every map door is its own buyable unit: door_<MapCreationID>
	  • City/franchise doors reserved by name heuristic only (no fake centers)
	  • Look at door → N buys THAT door. No placeholder radius linking.
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Property = MintyRP.Property or {}

local Prop = MintyRP.Property
local IsValid = IsValid
local math_floor = math.floor
local CurTime = CurTime

Prop.State = Prop.State or {}
Prop.DoorIndex = Prop.DoorIndex or {}
Prop.DynamicIds = Prop.DynamicIds or {}

local MAX_BITS = 2048
local RATE = 0.4
local DEFAULT_DOOR_PRICE = 3500

local NAME_RULES = {
	{ pat = "bank", id = "city_bank" },
	{ pat = "vault", id = "city_bank" },
	{ pat = "police", id = "city_police_station" },
	{ pat = "pd_", id = "city_police_station" },
	{ pat = "jail", id = "city_police_cells" },
	{ pat = "cell", id = "city_police_cells" },
	{ pat = "hospital", id = "city_hospital" },
	{ pat = "clinic", id = "city_hospital" },
	{ pat = "fire", id = "city_fire_ems" },
	{ pat = "ems", id = "city_fire_ems" },
	{ pat = "cityhall", id = "city_hall" },
	{ pat = "city_hall", id = "city_hall" },
	{ pat = "mayor", id = "city_hall" },
	{ pat = "impound", id = "city_impound" },
	{ pat = "transit", id = "city_transit" },
	{ pat = "gas", id = "fran_gas_downtown" },
	{ pat = "fuel", id = "fran_gas_downtown" },
	{ pat = "petrol", id = "fran_gas_downtown" },
	{ pat = "cinema", id = "fran_cinema" },
	{ pat = "theater", id = "fran_cinema" },
	{ pat = "club", id = "fran_nightclub" },
	{ pat = "nightclub", id = "fran_nightclub" },
	{ pat = "dealership", id = "fran_dealership" },
	{ pat = "cardealer", id = "fran_dealership" },
}

local function rateLimited(ply, key)
	ply.MintyRP = ply.MintyRP or {}
	local stamp = "_propRate_" .. key
	local now = CurTime()
	if (ply.MintyRP[stamp] or 0) > now then return true end
	ply.MintyRP[stamp] = now + RATE
	return false
end

local function charId(ply)
	return ply.MintyRP and ply.MintyRP.characterId
end

local function collectDoors()
	local doors = ents.FindByClass("prop_door_rotating")
	table.Add(doors, ents.FindByClass("func_door"))
	table.Add(doors, ents.FindByClass("func_door_rotating"))
	local out = {}
	for i = 1, #doors do
		local d = doors[i]
		if IsValid(d) and d:CreatedByMap() then
			out[#out + 1] = d
		end
	end
	return out
end

local function doorName(door)
	return string.lower(door:GetName() or "")
end

local function matchReserved(door)
	local n = doorName(door)
	if n == "" then return nil end
	for i = 1, #NAME_RULES do
		if string.find(n, NAME_RULES[i].pat, 1, true) then
			return NAME_RULES[i].id
		end
	end
	return nil
end

local function ensureState(id, def)
	if Prop.State[id] then return Prop.State[id] end
	local row = MintyRP.Database.GetProperty(id)
	local owner, locked
	if def and not def.ownable then
		owner = nil
		locked = def.doorPolicy ~= "public"
		if row and row.owner_character_id then
			MintyRP.Database.SetPropertyOwner(id, nil, locked)
		end
	elseif row then
		owner = tonumber(row.owner_character_id) or nil
		locked = (tonumber(row.locked) or 1) == 1
	else
		owner = nil
		locked = true
	end
	Prop.State[id] = { owner = owner, locked = locked, doors = {} }
	return Prop.State[id]
end

local function registerDoorProp(id, name, price, ownable, doorPolicy, ownerType)
	local def = {
		id = id,
		name = name,
		category = ownable and "apartment" or (ownerType or "city"),
		district = "rockford",
		ownable = ownable == true,
		ownerType = ownable and "private" or (ownerType or "city"),
		doorPolicy = doorPolicy or (ownable and "owner" or "secure"),
		price = ownable and (price or DEFAULT_DOOR_PRICE) or 0,
		dynamic = true,
		perDoor = true,
	}
	Prop.List[id] = def
	Prop.DynamicIds[id] = true
	ensureState(id, def)
	return def
end

local function linkDoor(door, propertyId)
	if not Prop.State[propertyId] then return false end
	local mid = door:MapCreationID()
	Prop.State[propertyId].doors[#Prop.State[propertyId].doors + 1] = door
	if mid and mid > 0 then
		Prop.DoorIndex[mid] = propertyId
	end

	local def = Prop.List[propertyId]
	door:SetNWString("MintyRP_Property", propertyId)
	door:SetNWBool("MintyRP_Ownable", def and def.ownable == true)
	door:SetNWString("MintyRP_PropName", (def and def.name) or propertyId)
	door:SetNWInt("MintyRP_PropPrice", (def and def.price) or 0)

	local st = Prop.State[propertyId]
	local policy = (def and def.doorPolicy) or "owner"
	if policy == "public" then
		door:Fire("Unlock", "", 0)
		st.locked = false
	elseif st.locked then
		door:Fire("Lock", "", 0)
	else
		door:Fire("Unlock", "", 0)
	end
	return true
end

function Prop.Initialize()
	Prop.State = {}
	Prop.DoorIndex = {}
	Prop.DynamicIds = {}

	-- Keep static catalog defs for F3 labels, but door linking ignores centers
	for id, def in pairs(Prop.List) do
		if def.dynamic then
			Prop.List[id] = nil
		else
			ensureState(id, def)
		end
	end

	timer.Simple(2, function()
		Prop.ScanDoors()
	end)
	print("[MintyRP] Property system initialized (per-door)")
end

function Prop.ScanDoors()
	Prop.DoorIndex = {}
	for id in pairs(Prop.DynamicIds or {}) do
		Prop.List[id] = nil
		Prop.State[id] = nil
	end
	Prop.DynamicIds = {}

	for id, st in pairs(Prop.State) do
		st.doors = {}
	end
	for id, def in pairs(Prop.List) do
		if not def.dynamic then
			ensureState(id, def)
		end
	end

	local doors = collectDoors()
	local buyable, reserved = 0, 0

	for i = 1, #doors do
		local door = doors[i]
		local mid = door:MapCreationID()
		if mid and mid > 0 then
			local rid = matchReserved(door)
			if rid and Prop.List[rid] then
				ensureState(rid, Prop.List[rid])
				linkDoor(door, rid)
				reserved = reserved + 1
			else
				local id = "door_" .. tostring(mid)
				local price = DEFAULT_DOOR_PRICE
				local name = "Door #" .. tostring(mid)
				registerDoorProp(id, name, price, true, "owner", "private")
				linkDoor(door, id)
				buyable = buyable + 1
			end
		end
	end

	print(string.format(
		"[MintyRP] Door scan (per-door): %d map doors → %d buyable, %d reserved",
		#doors, buyable, reserved
	))

	if MintyRP.Bank and MintyRP.Bank.ResolveFromMap then
		timer.Simple(0.25, MintyRP.Bank.ResolveFromMap)
	end
end

function Prop.GetByDoor(ent)
	if not Prop.IsDoor(ent) then return nil end
	local id = ent:GetNWString("MintyRP_Property", "")
	if id ~= "" and Prop.List[id] then return id, Prop.List[id], Prop.State[id] end
	local mid = ent:MapCreationID()
	id = Prop.DoorIndex[mid]
	if id and Prop.List[id] then return id, Prop.List[id], Prop.State[id] end
	return nil
end

function Prop.IsOwner(ply, propertyId)
	local st = Prop.State[propertyId]
	local cid = charId(ply)
	return st and cid and st.owner == cid
end

function Prop.ApplyLock(propertyId, locked)
	local st = Prop.State[propertyId]
	if not st then return end
	st.locked = locked and true or false
	for _, door in ipairs(st.doors) do
		if IsValid(door) then
			door:Fire(st.locked and "Lock" or "Unlock", "", 0)
		end
	end
	MintyRP.Database.SetPropertyLock(propertyId, st.locked)
	for _, ply in ipairs(player.GetAll()) do
		if Prop.IsOwner(ply, propertyId) then
			Prop.SyncPlayer(ply)
		end
	end
end

function Prop.SyncPlayer(ply)
	if not IsValid(ply) or not charId(ply) then return end
	local cid = charId(ply)
	local owned = {}
	for id, st in pairs(Prop.State) do
		if st.owner == cid then owned[#owned + 1] = id end
	end
	net.Start("MintyRP_PropertySync")
		net.WriteUInt(math.min(#owned, 255), 8)
		for i = 1, math.min(#owned, 255) do
			local oid = owned[i]
			local def = Prop.List[oid]
			net.WriteString(oid)
			net.WriteString((def and def.name) or oid)
			net.WriteBool(Prop.State[oid].locked)
		end
	net.Send(ply)
end

local function chargePlayer(ply, amount)
	amount = math_floor(amount)
	local cash = MintyRP.Player.GetMoney(ply)
	local bank = math_floor((ply.MintyRP and ply.MintyRP.bank) or 0)
	if cash + bank < amount then return false end
	if cash >= amount then
		MintyRP.Player.AddMoney(ply, -amount)
	else
		local need = amount - cash
		if cash > 0 then MintyRP.Player.AddMoney(ply, -cash) end
		ply.MintyRP.bank = bank - need
		net.Start("MintyRP_BankSync")
			net.WriteUInt(math_floor(ply.MintyRP.money or 0), 32)
			net.WriteUInt(math_floor(ply.MintyRP.bank or 0), 32)
		net.Send(ply)
	end
	return true
end

function Prop.Buy(ply, propertyId)
	local def = Prop.Get(propertyId)
	local st = Prop.State[propertyId]
	local cid = charId(ply)
	if not def or not st or not cid then return false, "invalid" end
	if not def.ownable then return false, "reserved" end
	if st.owner then return false, "owned" end
	local price = math_floor(def.price or 0)
	if not chargePlayer(ply, price) then return false, "money" end
	st.owner = cid
	st.locked = true
	MintyRP.Database.SetPropertyOwner(propertyId, cid, true)
	Prop.ApplyLock(propertyId, true)
	Prop.SyncPlayer(ply)
	MintyRP.Player.Save(ply)
	return true
end

function Prop.Sell(ply, propertyId)
	local def = Prop.Get(propertyId)
	local st = Prop.State[propertyId]
	if not def or not st then return false, "invalid" end
	if not def.ownable then return false, "reserved" end
	if not Prop.IsOwner(ply, propertyId) then return false, "not_owner" end
	local refund = math_floor((def.price or 0) * 0.5)
	st.owner = nil
	st.locked = true
	MintyRP.Database.SetPropertyOwner(propertyId, nil, true)
	Prop.ApplyLock(propertyId, true)
	MintyRP.Player.AddMoney(ply, refund)
	Prop.SyncPlayer(ply)
	MintyRP.Player.Save(ply)
	return true, refund
end

hook.Add("PlayerUse", "MintyRP_PropertyDoorUse", function(ply, ent)
	local id, def, st = Prop.GetByDoor(ent)
	if not id or not st or not def then return end
	local policy = def.doorPolicy or "owner"
	if policy == "public" then return end
	if not st.locked then return end
	if policy == "secure" then
		if (ply.MintyRP._doorNotify or 0) < CurTime() then
			ply.MintyRP._doorNotify = CurTime() + 1.5
			MintyRP.Util.Notify(ply, "Restricted — " .. def.name .. ".", 2)
		end
		return false
	end
	if Prop.IsOwner(ply, id) then return end
	if (ply.MintyRP._doorNotify or 0) < CurTime() then
		ply.MintyRP._doorNotify = CurTime() + 1.5
		MintyRP.Util.Notify(ply, "Locked — " .. def.name .. ".", 2)
	end
	return false
end)

net.Receive("MintyRP_PropertyAction", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if len > MAX_BITS then return end
	if rateLimited(ply, "action") then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end

	local action = net.ReadUInt(3)
	local propertyId = net.ReadString()
	if #propertyId < 1 or #propertyId > 64 then return end
	if not Prop.Get(propertyId) then return end

	if action == 1 then
		local ok, err = Prop.Buy(ply, propertyId)
		if ok then
			MintyRP.Util.Notify(ply, "Purchased " .. Prop.Get(propertyId).name .. ".", 1)
		else
			MintyRP.Util.Notify(ply, ({
				owned = "Already owned.",
				money = "Not enough money (cash + bank).",
				invalid = "Invalid property.",
				reserved = "City / franchise — not for sale.",
			})[err] or "Purchase failed.", 3)
		end
	elseif action == 2 then
		local ok, refund = Prop.Sell(ply, propertyId)
		if ok then
			MintyRP.Util.Notify(ply, "Sold for $" .. tostring(refund) .. ".", 1)
		else
			MintyRP.Util.Notify(ply, "You don't own that.", 3)
		end
	elseif action == 3 or action == 4 then
		if not Prop.IsOwner(ply, propertyId) then
			MintyRP.Util.Notify(ply, "You don't own that.", 3)
			return
		end
		Prop.ApplyLock(propertyId, action == 3)
		MintyRP.Util.Notify(ply, action == 3 and "Locked." or "Unlocked.", 0)
		Prop.SyncPlayer(ply)
	end
end)

hook.Add("InitPostEntity", "MintyRP_PropertyScan", function()
	timer.Simple(3, function() if Prop.ScanDoors then Prop.ScanDoors() end end)
end)
hook.Add("PostCleanupMap", "MintyRP_PropertyRescan", function()
	timer.Simple(2, function() Prop.ScanDoors() end)
end)
hook.Add("MintyRP_CharacterApplied", "MintyRP_PropertySyncChar", function(ply)
	timer.Simple(0.2, function() if IsValid(ply) then Prop.SyncPlayer(ply) end end)
end)

concommand.Add("mintyrp_propscan", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Prop.ScanDoors()
	if IsValid(ply) then MintyRP.Util.Notify(ply, "Doors rescanned (per-door).", 0) end
end)

concommand.Add("mintyrp_propstats", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local buyable, reserved = 0, 0
	for id, def in pairs(Prop.List) do
		local n = Prop.State[id] and #Prop.State[id].doors or 0
		if n > 0 then
			if def.ownable then buyable = buyable + 1 else reserved = reserved + 1 end
		end
	end
	print(string.format("[MintyRP] buyable doors:%d reserved:%d", buyable, reserved))
	if IsValid(ply) then
		MintyRP.Util.Notify(ply, buyable .. " buyable doors linked.", 0)
	end
end)

-- Admin: force-reserve or force-ownable the door you're looking at
concommand.Add("mintyrp_markdoor", function(ply, cmd, args)
	if not IsValid(ply) or not ply:IsSuperAdmin() then return end
	local mode = string.lower(tostring((args and args[1]) or ""))
	local tr = ply:GetEyeTrace()
	if not tr or not IsValid(tr.Entity) or not Prop.IsDoor(tr.Entity) then
		MintyRP.Util.Notify(ply, "Look at a door. mintyrp_markdoor reserve|ownable", 3)
		return
	end
	local door = tr.Entity
	local mid = door:MapCreationID()
	if not mid or mid < 1 then return end

	-- Unlink old
	local old = door:GetNWString("MintyRP_Property", "")
	if old ~= "" and Prop.State[old] then
		local nd = {}
		for _, d in ipairs(Prop.State[old].doors) do
			if d ~= door then nd[#nd + 1] = d end
		end
		Prop.State[old].doors = nd
	end

	if mode == "reserve" or mode == "city" then
		local id = "reserved_" .. tostring(mid)
		registerDoorProp(id, "Reserved Door", 0, false, "secure", "city")
		linkDoor(door, id)
		MintyRP.Util.Notify(ply, "Door marked reserved.", 0)
	else
		local id = "door_" .. tostring(mid)
		registerDoorProp(id, "Door #" .. tostring(mid), DEFAULT_DOOR_PRICE, true, "owner", "private")
		linkDoor(door, id)
		MintyRP.Util.Notify(ply, "Door marked buyable ($" .. DEFAULT_DOOR_PRICE .. ").", 0)
	end
end)

print("[MintyRP] Property server loaded (per-door)")
