--[[-------------------------------------------------------------------------
	MintyRP — Inventory server logic
	Realm: SERVER

	All mutations are authoritative. net.Receive validates player state,
	item IDs, amounts, and weight before applying changes.
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Inventory = MintyRP.Inventory or {}

local INV = MintyRP.Inventory
local IsValid = IsValid
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local util_TableToJSON = util.TableToJSON

local ACTION_MOVE   = 1 -- personal ↔ storage (storage stub)
local ACTION_DROP   = 2
local ACTION_USE    = 3
local ACTION_SPLIT  = 4

local MAX_AMOUNT = 100
local RATE_LIMIT = 0.15

function INV.Initialize()
	print("[MintyRP] Inventory system initialized")
end

local function getInv(ply)
	if not IsValid(ply) or not ply.MintyRP or not ply.MintyRP.Loaded then
		return nil
	end
	ply.MintyRP.inventory = ply.MintyRP.inventory or {}
	return ply.MintyRP.inventory
end

function INV.CanCarry(ply, itemId, amount)
	local def = INV.GetItem(itemId)
	if not def then return false, "unknown_item" end

	amount = math_floor(tonumber(amount) or 0)
	if amount < 1 or amount > MAX_AMOUNT then return false, "bad_amount" end

	local inv = getInv(ply)
	if not inv then return false, "not_loaded" end

	local addWeight = INV.GetStackWeight(itemId, amount)
	local curWeight = INV.CalcWeight(inv)
	local maxWeight = INV.GetMaxWeight(ply)

	if curWeight + addWeight > maxWeight + 0.001 then
		return false, "overweight"
	end

	return true
end

function INV.Give(ply, itemId, amount, meta)
	local ok, err = INV.CanCarry(ply, itemId, amount)
	if not ok then return false, err end

	local def = INV.GetItem(itemId)
	local inv = getInv(ply)
	amount = math_floor(amount)

	local idx, slot = INV.FindSlot(inv, itemId)
	if idx and slot and def.maxStack > 1 then
		local space = def.maxStack - slot.amount
		if space > 0 then
			local add = math_min(space, amount)
			slot.amount = slot.amount + add
			amount = amount - add
		end
	end

	while amount > 0 do
		local stack = math_min(amount, def.maxStack)
		inv[#inv + 1] = {
			slot = #inv + 1,
			item_id = itemId,
			amount = stack,
			meta = meta or "{}",
		}
		amount = amount - stack
	end

	INV.Sync(ply)
	return true
end

function INV.Take(ply, itemId, amount)
	amount = math_floor(tonumber(amount) or 0)
	if amount < 1 then return false, "bad_amount" end

	local inv = getInv(ply)
	if not inv then return false, "not_loaded" end

	local remaining = amount
	for i = #inv, 1, -1 do
		local slot = inv[i]
		if slot and slot.item_id == itemId then
			local take = math_min(slot.amount, remaining)
			slot.amount = slot.amount - take
			remaining = remaining - take
			if slot.amount <= 0 then
				table.remove(inv, i)
			end
			if remaining <= 0 then break end
		end
	end

	-- Reindex slots
	for i = 1, #inv do
		inv[i].slot = i
	end

	if remaining > 0 then
		return false, "not_enough"
	end

	INV.Sync(ply)
	return true
end

function INV.Count(ply, itemId)
	local inv = getInv(ply)
	if not inv then return 0 end

	local total = 0
	for i = 1, #inv do
		local slot = inv[i]
		if slot and slot.item_id == itemId then
			total = total + slot.amount
		end
	end
	return total
end

function INV.Sync(ply)
	local inv = getInv(ply)
	if not inv then return end

	-- Compact payload: count + repeating (item index hash via string, amount)
	local count = math_min(#inv, 128)

	net.Start("MintyRP_InventorySync")
		net.WriteUInt(count, 8)
		for i = 1, count do
			local slot = inv[i]
			net.WriteString(slot.item_id or "")
			net.WriteUInt(math_min(slot.amount or 1, 65535), 16)
		end
		net.WriteFloat(INV.CalcWeight(inv))
		net.WriteFloat(INV.GetMaxWeight(ply))
	net.Send(ply)
end

local function rateLimited(ply)
	local now = CurTime()
	ply.MintyRP = ply.MintyRP or {}
	if (ply.MintyRP._invNext or 0) > now then
		return true
	end
	ply.MintyRP._invNext = now + RATE_LIMIT
	return false
end

net.Receive("MintyRP_InventoryAction", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if len > 128 then return end -- reject oversized packets
	if rateLimited(ply) then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end

	local action = net.ReadUInt(4)
	local itemId = net.ReadString()
	local amount = net.ReadUInt(8)

	if type(itemId) ~= "string" or #itemId < 1 or #itemId > 64 then return end
	if not INV.GetItem(itemId) then return end
	if amount < 1 or amount > MAX_AMOUNT then return end

	if action == ACTION_DROP then
		local def = INV.GetItem(itemId)
		if not def.droppable then
			MintyRP.Util.Notify(ply, "You cannot drop that.", 2)
			return
		end

		local ok = INV.Take(ply, itemId, amount)
		if not ok then
			MintyRP.Util.Notify(ply, "You don't have enough.", 3)
			return
		end

		-- Placeholder: world drop entity comes in a later module
		MintyRP.Util.Notify(ply, "Dropped " .. amount .. "x " .. def.name .. ".", 0)

	elseif action == ACTION_USE then
		local def = INV.GetItem(itemId)
		if not def.usable then
			MintyRP.Util.Notify(ply, "You cannot use that.", 2)
			return
		end

		local ok = INV.Take(ply, itemId, 1)
		if not ok then
			MintyRP.Util.Notify(ply, "You don't have that item.", 3)
			return
		end

		-- Hook for consumable effects
		hook.Run("MintyRP_ItemUsed", ply, itemId, def)
		MintyRP.Util.Notify(ply, "Used " .. def.name .. ".", 1)

	elseif action == ACTION_MOVE then
		-- Storage units / property boxes — skeleton only
		MintyRP.Util.Notify(ply, "Storage transfer is not available yet.", 2)

	elseif action == ACTION_SPLIT then
		MintyRP.Util.Notify(ply, "Split stacks coming soon.", 2)
	end
end)

-- Starter kit for brand-new characters (no inventory rows)
hook.Add("MintyRP_PlayerFirstJoin", "MintyRP_StarterItems", function(ply)
	INV.Give(ply, "water_bottle", 1)
	INV.Give(ply, "sandwich", 1)
	INV.Give(ply, "phone", 1)
end)

-- Detect first join after load
local oldLoad = MintyRP.Player and MintyRP.Player.Load
if oldLoad then
	-- Fired from player module via empty inventory + new flag; also check in Load hook
end

hook.Add("PlayerInitialSpawn", "MintyRP_InventorySpawnHook", function(ply)
	-- Actual give happens after DB load; see timer in player load path
end)

-- After character ready: grant starter if inventory empty and brand new
hook.Add("PlayerSpawn", "MintyRP_CheckStarterKit", function(ply)
	if not IsValid(ply) or ply:IsBot() then return end
	timer.Simple(1, function()
		if not IsValid(ply) or not ply.MintyRP or not ply.MintyRP.Loaded then return end
		if ply.MintyRP._starterChecked then return end
		ply.MintyRP._starterChecked = true

		local inv = ply.MintyRP.inventory
		if type(inv) == "table" and #inv == 0 then
			hook.Run("MintyRP_PlayerFirstJoin", ply)
		end
	end)
end)

print("[MintyRP] Inventory server loaded")
