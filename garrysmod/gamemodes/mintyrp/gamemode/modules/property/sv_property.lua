--[[-------------------------------------------------------------------------
	MintyRP — Property ownership / doors (server)
	Realm: SERVER

	Megafix: do NOT rely on placeholder centers for buyable housing.
	1) Reserve city/franchise doors (name heuristics + wide radii)
	2) Cluster every remaining map door into buyable units
	3) Stable unit IDs from MapCreationIDs so ownership persists
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Property = MintyRP.Property or {}

local Prop = MintyRP.Property
local IsValid = IsValid
local math_floor = math.floor
local CurTime = CurTime
local Vector = Vector

Prop.State = Prop.State or {}
Prop.DoorIndex = Prop.DoorIndex or {}
Prop.DynamicIds = Prop.DynamicIds or {} -- set of auto unit ids

local MAX_BITS = 2048
local RATE = 0.4
local CLUSTER_DIST = 200 -- doors within this (units) share a unit
local CLUSTER_DIST_SQR = CLUSTER_DIST * CLUSTER_DIST

-- Name → reserved property (Rockford targetnames often include these)
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
	local n = door:GetName() or ""
	if n == "" then
		n = door:GetNWString("Targetname", "") -- rarely set
	end
	return string.lower(n)
end

local function matchNameRule(door)
	local n = doorName(door)
	if n == "" then return nil end
	for i = 1, #NAME_RULES do
		if string.find(n, NAME_RULES[i].pat, 1, true) then
			return NAME_RULES[i].id
		end
	end
	return nil
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

local function registerDynamic(id, name, center, price, district)
	local def = {
		id = id,
		name = name,
		category = "apartment",
		district = district or "residential",
		ownable = true,
		ownerType = "private",
		doorPolicy = "owner",
		price = price,
		center = center,
		radius = CLUSTER_DIST,
		dynamic = true,
	}
	Prop.List[id] = def
	Prop.DynamicIds[id] = true
	ensureState(id, def)
	return def
end

local function guessDistrict(pos)
	-- Rough Rockford layout heuristics (works even when centers are wrong)
	local x, y = pos.x, pos.y
	if x > 3500 then return "industrial" end
	if x > 500 and y < -2500 then return "civic" end
	if x < -5000 and y < -2000 then return "residential" end
	if y > 1800 then return "commercial" end
	if y < -3500 then return "outskirts" end
	return "downtown"
end

local function priceForCluster(doors, district)
	local n = #doors
	local base = ({
		downtown = 4000,
		commercial = 8000,
		civic = 4500,
		residential = 2800,
		industrial = 12000,
		outskirts = 6000,
	})[district] or 3500
	return math_floor(base + (n - 1) * 1800)
end

local function stableUnitId(doors)
	local mids = {}
	for i = 1, #doors do
		local mid = doors[i]:MapCreationID()
		if mid and mid > 0 then
			mids[#mids + 1] = mid
		end
	end
	table.sort(mids)
	if #mids == 0 then
		return "unit_tmp_" .. tostring(doors[1]:EntIndex())
	end
	-- CRC keeps IDs short & stable across sessions
	local key = table.concat(mids, ",")
	return "unit_" .. tostring(util.CRC(key))
end

local function clusterOrphans(orphans)
	local used = {}
	local units = 0

	for i = 1, #orphans do
		if not used[i] then
			local seed = orphans[i]
			local cluster = { seed }
			used[i] = true

			-- Grow cluster (single-pass flood is enough for housing doors)
			local changed = true
			while changed do
				changed = false
				for j = 1, #orphans do
					if not used[j] then
						local cand = orphans[j]
						local cpos = cand:GetPos()
						for k = 1, #cluster do
							if cpos:DistToSqr(cluster[k]:GetPos()) <= CLUSTER_DIST_SQR then
								cluster[#cluster + 1] = cand
								used[j] = true
								changed = true
								break
							end
						end
					end
				end
			end

			local avg = Vector(0, 0, 0)
			for k = 1, #cluster do
				avg = avg + cluster[k]:GetPos()
			end
			avg = avg / #cluster

			local district = guessDistrict(avg)
			local id = stableUnitId(cluster)
			local price = priceForCluster(cluster, district)
			local name = (#cluster == 1)
				and string.format("For-sale Door (%s)", district)
				or string.format("Unit (%d doors, %s)", #cluster, district)

			-- Prefer a nicer catalog name if a catalog ownable center is close
			for cid, def in pairs(Prop.List) do
				if def.ownable and not def.dynamic and def.center then
					local r = (def.radius or 160) * 2.5
					if avg:DistToSqr(def.center) <= (r * r) then
						name = def.name
						price = def.price or price
						district = def.district or district
						-- Keep stable unit id (ownership), but adopt catalog label/price
						break
					end
				end
			end

			registerDynamic(id, name, avg, price, district)
			for k = 1, #cluster do
				linkDoor(cluster[k], id)
			end
			units = units + 1
		end
	end

	return units
end

function Prop.Initialize()
	Prop.State = {}
	Prop.DoorIndex = {}
	Prop.DynamicIds = {}

	-- Catalog entries (static)
	for id, def in pairs(Prop.List) do
		if not def.dynamic then
			ensureState(id, def)
		end
	end

	-- Strip dynamic leftovers from a previous round if lua reloaded
	for id, def in pairs(Prop.List) do
		if def.dynamic then
			Prop.List[id] = nil
		end
	end

	timer.Simple(2, function()
		Prop.ScanDoors()
	end)

	print("[MintyRP] Property system initialized")
end

function Prop.ScanDoors()
	-- Reset door lists / index; keep ownership state for static+dynamic we'll rebuild
	Prop.DoorIndex = {}

	-- Clear previous dynamic defs (ownership rows stay in DB keyed by unit id)
	for id in pairs(Prop.DynamicIds or {}) do
		Prop.List[id] = nil
		Prop.State[id] = nil
	end
	Prop.DynamicIds = {}

	for id, st in pairs(Prop.State) do
		st.doors = {}
	end

	-- Re-ensure static catalog states
	for id, def in pairs(Prop.List) do
		if not def.dynamic then
			ensureState(id, def)
		end
	end

	local doors = collectDoors()
	local assigned = {}
	local linked = 0

	-- Pass 1: name heuristics → reserved buildings
	for i = 1, #doors do
		local door = doors[i]
		local rid = matchNameRule(door)
		if rid and Prop.List[rid] then
			ensureState(rid, Prop.List[rid])
			if linkDoor(door, rid) then
				assigned[door] = true
				linked = linked + 1
			end
		end
	end

	-- Pass 2: city/franchise wide radius (placeholders OK for gov — we just need "reserved")
	for i = 1, #doors do
		local door = doors[i]
		if not assigned[door] then
			local pos = door:GetPos()
			local bestId, bestScore
			for id, def in pairs(Prop.List) do
				if not def.ownable and def.center then
					local r = math.max((def.radius or 300) * 2.2, 700)
					local dist = pos:DistToSqr(def.center)
					if dist <= (r * r) then
						local score = dist + r * 0.1
						if not bestScore or score < bestScore then
							bestScore = score
							bestId = id
						end
					end
				end
			end
			if bestId then
				ensureState(bestId, Prop.List[bestId])
				if linkDoor(door, bestId) then
					assigned[door] = true
					linked = linked + 1
				end
			end
		end
	end

	-- Pass 3: everything else → buyable clustered units (THIS is what makes slums work)
	local orphans = {}
	for i = 1, #doors do
		if not assigned[doors[i]] then
			orphans[#orphans + 1] = doors[i]
		end
	end
	local units = clusterOrphans(orphans)

	local withDoors, buyableLinked = 0, 0
	for id, st in pairs(Prop.State) do
		if #st.doors > 0 then
			withDoors = withDoors + 1
			if Prop.List[id] and Prop.List[id].ownable then
				buyableLinked = buyableLinked + 1
			end
		end
	end

	print(string.format(
		"[MintyRP] Door scan: %d map doors → %d linked, %d buyable units, %d properties with doors (catalog+dynamic %d)",
		#doors, linked + #orphans, units, withDoors, table.Count(Prop.List)
	))

	-- Tellers should sit at real bank/gas doors once we know them
	if MintyRP.Bank and MintyRP.Bank.ResolveFromMap then
		timer.Simple(0.5, MintyRP.Bank.ResolveFromMap)
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
		if st.owner == cid then
			owned[#owned + 1] = id
		end
	end

	net.Start("MintyRP_PropertySync")
		net.WriteUInt(math.min(#owned, 255), 8)
		for i = 1, math.min(#owned, 255) do
			local oid = owned[i]
			local st = Prop.State[oid]
			local def = Prop.List[oid]
			net.WriteString(oid)
			net.WriteString((def and def.name) or oid)
			net.WriteBool(st.locked)
		end
	net.Send(ply)
end

--- Charge cash first, then bank (tutorial money lands in bank)
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
			local msg = ({
				owned = "Already owned.",
				money = "Not enough money (cash + bank).",
				invalid = "Invalid property.",
				reserved = "City / franchise property — not for sale.",
			})[err] or "Purchase failed."
			MintyRP.Util.Notify(ply, msg, 3)
		end

	elseif action == 2 then
		local ok, refund = Prop.Sell(ply, propertyId)
		if ok then
			MintyRP.Util.Notify(ply, "Sold property for $" .. tostring(refund) .. ".", 1)
		else
			MintyRP.Util.Notify(ply, "You don't own that.", 3)
		end

	elseif action == 3 or action == 4 then
		if not Prop.IsOwner(ply, propertyId) then
			MintyRP.Util.Notify(ply, "You don't own that.", 3)
			return
		end
		Prop.ApplyLock(propertyId, action == 3)
		MintyRP.Util.Notify(ply, action == 3 and "Property locked." or "Property unlocked.", 0)
		Prop.SyncPlayer(ply)
	end
end)

hook.Add("InitPostEntity", "MintyRP_PropertyScan", function()
	timer.Simple(3, function()
		if Prop.ScanDoors then Prop.ScanDoors() end
	end)
end)

hook.Add("PostCleanupMap", "MintyRP_PropertyRescan", function()
	timer.Simple(2, function()
		Prop.ScanDoors()
	end)
end)

hook.Add("MintyRP_CharacterApplied", "MintyRP_PropertySyncChar", function(ply)
	timer.Simple(0.2, function()
		if IsValid(ply) then Prop.SyncPlayer(ply) end
	end)
end)

hook.Add("MintyRP_PlayerFirstJoin", "MintyRP_PropertySyncNew", function(ply)
	timer.Simple(0.2, function()
		if IsValid(ply) then Prop.SyncPlayer(ply) end
	end)
end)

concommand.Add("mintyrp_propscan", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Prop.ScanDoors()
	if IsValid(ply) then
		MintyRP.Util.Notify(ply, "Property doors rescanned.", 0)
	end
end)

concommand.Add("mintyrp_propstats", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local buyable, reserved, empty = 0, 0, 0
	for id, def in pairs(Prop.List) do
		local n = Prop.State[id] and #Prop.State[id].doors or 0
		if n == 0 then
			empty = empty + 1
		elseif def.ownable then
			buyable = buyable + 1
		else
			reserved = reserved + 1
		end
	end
	print(string.format("[MintyRP] With doors — buyable:%d reserved:%d empty-catalog:%d total-defs:%d",
		buyable, reserved, empty, table.Count(Prop.List)))
	if IsValid(ply) then
		MintyRP.Util.Notify(ply, buyable .. " buyable units linked. See console.", 0)
	end
end)

concommand.Add("mintyrp_doordump", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if not file.Exists("mintyrp", "DATA") then file.CreateDir("mintyrp") end
	local lines = { "-- MintyRP door dump " .. game.GetMap() .. " " .. os.date("%Y-%m-%d %H:%M") }
	local doors = collectDoors()
	for i = 1, #doors do
		local d = doors[i]
		local pos = d:GetPos()
		lines[#lines + 1] = string.format(
			"mid=%d class=%s name=%q prop=%s pos=Vector(%.1f, %.1f, %.1f)",
			d:MapCreationID() or -1,
			d:GetClass(),
			d:GetName() or "",
			d:GetNWString("MintyRP_Property", ""),
			pos.x, pos.y, pos.z
		)
	end
	file.Write("mintyrp/doors_dump.txt", table.concat(lines, "\n"))
	print("[MintyRP] Wrote " .. #doors .. " doors to data/mintyrp/doors_dump.txt")
	if IsValid(ply) then
		MintyRP.Util.Notify(ply, "Dumped " .. #doors .. " doors to data/mintyrp/doors_dump.txt", 0)
	end
end)

print("[MintyRP] Property server loaded")
