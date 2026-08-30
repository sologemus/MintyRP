--[[-------------------------------------------------------------------------
	MintyRP — Property ownership / doors (server)
	Realm: SERVER
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Property = MintyRP.Property or {}

local Prop = MintyRP.Property
local IsValid = IsValid
local math_floor = math.floor
local CurTime = CurTime

-- Runtime: mapCreationId → propertyId ; propertyId → { ownerCharId, locked, doorEnts }
Prop.State = Prop.State or {}
Prop.DoorIndex = Prop.DoorIndex or {}

local MAX_BITS = 2048
local RATE = 0.4

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

function Prop.Initialize()
	Prop.State = {}
	Prop.DoorIndex = {}

	for id, def in pairs(Prop.List) do
		local row = MintyRP.Database.GetProperty(id)
		local locked = true
		local owner = nil
		if row then
			owner = tonumber(row.owner_character_id) or nil
			locked = (tonumber(row.locked) or 1) == 1
		end
		Prop.State[id] = {
			owner = owner,
			locked = locked,
			doors = {},
		}
	end

	timer.Simple(2, function()
		Prop.ScanDoors()
	end)

	print("[MintyRP] Property system initialized")
end

function Prop.ScanDoors()
	Prop.DoorIndex = {}
	for id, def in pairs(Prop.List) do
		if Prop.State[id] then
			Prop.State[id].doors = {}
		end
	end

	local doors = ents.FindByClass("prop_door_rotating")
	table.Add(doors, ents.FindByClass("func_door"))
	table.Add(doors, ents.FindByClass("func_door_rotating"))

	local linked = 0
	for _, door in ipairs(doors) do
		if IsValid(door) then
			local pos = door:GetPos()
			local bestId, bestDist

			for id, def in pairs(Prop.List) do
				local dist = pos:DistToSqr(def.center)
				local r = def.radius or 200
				if dist <= (r * r) and (not bestDist or dist < bestDist) then
					bestDist = dist
					bestId = id
				end
			end

			if bestId and Prop.State[bestId] then
				local mid = door:MapCreationID()
				Prop.State[bestId].doors[#Prop.State[bestId].doors + 1] = door
				if mid and mid > 0 then
					Prop.DoorIndex[mid] = bestId
				end
				door:SetNWString("MintyRP_Property", bestId)
				linked = linked + 1

				if Prop.State[bestId].locked then
					door:Fire("Lock", "", 0)
				else
					door:Fire("Unlock", "", 0)
				end
			end
		end
	end

	print(string.format("[MintyRP] Linked %d doors across %d properties", linked, table.Count(Prop.List)))
end

function Prop.GetByDoor(ent)
	if not Prop.IsDoor(ent) then return nil end
	local id = ent:GetNWString("MintyRP_Property", "")
	if id ~= "" and Prop.List[id] then return id, Prop.List[id], Prop.State[id] end

	local mid = ent:MapCreationID()
	id = Prop.DoorIndex[mid]
	if id then return id, Prop.List[id], Prop.State[id] end
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
		net.WriteUInt(#owned, 8)
		for i = 1, #owned do
			net.WriteString(owned[i])
			local st = Prop.State[owned[i]]
			net.WriteBool(st.locked)
		end
	net.Send(ply)
end

function Prop.Buy(ply, propertyId)
	local def = Prop.Get(propertyId)
	local st = Prop.State[propertyId]
	local cid = charId(ply)
	if not def or not st or not cid then return false, "invalid" end
	if st.owner then return false, "owned" end

	local price = math_floor(def.price or 0)
	if MintyRP.Player.GetMoney(ply) < price then return false, "money" end

	MintyRP.Player.AddMoney(ply, -price)
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

-- Block non-owners from using locked doors
hook.Add("PlayerUse", "MintyRP_PropertyDoorUse", function(ply, ent)
	local id, def, st = Prop.GetByDoor(ent)
	if not id or not st then return end
	if not st.locked then return end
	if Prop.IsOwner(ply, id) then return end

	-- Government doors later; for now deny
	if (ply.MintyRP._doorNotify or 0) < CurTime() then
		ply.MintyRP._doorNotify = CurTime() + 1.5
		MintyRP.Util.Notify(ply, "Locked — " .. (def and def.name or "property") .. ".", 2)
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

	-- 1 buy, 2 sell, 3 lock, 4 unlock
	if action == 1 then
		local ok, err = Prop.Buy(ply, propertyId)
		if ok then
			MintyRP.Util.Notify(ply, "Purchased " .. Prop.Get(propertyId).name .. ".", 1)
		else
			local msg = ({
				owned = "Already owned.",
				money = "Not enough cash.",
				invalid = "Invalid property.",
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

-- Looking at a door: press R (reload bind) is awkward; use +use info via client.
-- Own-door toggle while aiming: hold Walk+Use handled client → action lock toggle

hook.Add("InitPostEntity", "MintyRP_PropertyScan", function()
	timer.Simple(1, function()
		if Prop.ScanDoors then Prop.ScanDoors() end
	end)
end)

hook.Add("PostCleanupMap", "MintyRP_PropertyRescan", function()
	timer.Simple(1, function()
		Prop.ScanDoors()
	end)
end)

-- After character ready, sync owned props
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

print("[MintyRP] Property server loaded")
