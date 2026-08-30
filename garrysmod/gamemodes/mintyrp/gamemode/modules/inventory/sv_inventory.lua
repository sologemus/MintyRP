--[[-------------------------------------------------------------------------
	MintyRP — Inventory server (PERP-inspired slots)
	Realm: SERVER

	Actions via net (not PERP concommands). Slot swap, use, drop, storage move.
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Inventory = MintyRP.Inventory or {}

local INV = MintyRP.Inventory
local IsValid = IsValid
local math_floor = math.floor
local math_min = math.min

util.AddNetworkString("MintyRP_InventorySwap")

local ACTION_MOVE = 1
local ACTION_DROP = 2
local ACTION_USE = 3
local ACTION_SPLIT = 4

local MAX_AMOUNT = 100
local RATE_LIMIT = 0.12

function INV.Initialize()
	print("[MintyRP] Inventory system initialized (PERP slots)")
end

local function getInv(ply)
	if not IsValid(ply) or not ply.MintyRP or not ply.MintyRP.Loaded then
		return nil
	end
	ply.MintyRP.inventory = ply.MintyRP.inventory or {}
	return ply.MintyRP.inventory
end

local function reindexNotNeeded(inv)
	-- slots are identity; nothing to reindex
	return inv
end

function INV.CanCarry(ply, itemId, amount)
	local def = INV.GetItem(itemId)
	if not def then return false, "unknown_item" end
	amount = math_floor(tonumber(amount) or 0)
	if amount < 1 or amount > MAX_AMOUNT then return false, "bad_amount" end
	local inv = getInv(ply)
	if not inv then return false, "not_loaded" end

	local addWeight = INV.GetStackWeight(itemId, amount)
	if INV.CalcWeight(inv) + addWeight > INV.GetMaxWeight(ply) + 0.001 then
		return false, "overweight"
	end

	-- Need stack space or a free bag slot
	local _, existing = INV.FindSlot(inv, itemId)
	if existing and def.maxStack > 1 and existing.amount < def.maxStack then
		return true
	end
	if INV.FindFreeBagSlot(inv) then return true end
	-- Can still fill remaining stack space across stacks
	local space = 0
	for i = 1, #inv do
		if inv[i].item_id == itemId then
			space = space + math.max(0, def.maxStack - inv[i].amount)
		end
	end
	if space >= amount then return true end
	return false, "full"
end

function INV.Give(ply, itemId, amount, meta)
	local ok, err = INV.CanCarry(ply, itemId, amount)
	if not ok then return false, err end

	local def = INV.GetItem(itemId)
	local inv = getInv(ply)
	amount = math_floor(amount)

	-- Fill existing stacks first (bag preferred)
	for i = 1, #inv do
		local slot = inv[i]
		if slot.item_id == itemId and INV.IsBagSlot(slot.slot) and slot.amount < def.maxStack then
			local add = math_min(def.maxStack - slot.amount, amount)
			slot.amount = slot.amount + add
			amount = amount - add
			if amount <= 0 then break end
		end
	end

	while amount > 0 do
		local free = INV.FindFreeBagSlot(inv)
		if not free then break end
		local stack = math_min(amount, def.maxStack)
		inv[#inv + 1] = {
			slot = free,
			item_id = itemId,
			amount = stack,
			meta = meta or "{}",
		}
		amount = amount - stack
	end

	if amount > 0 then
		INV.Sync(ply)
		return false, "full"
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
			if slot.amount <= 0 then table.remove(inv, i) end
			if remaining <= 0 then break end
		end
	end

	if remaining > 0 then return false, "not_enough" end
	INV.Sync(ply)
	return true
end

function INV.TakeFromSlot(ply, slotNum, amount)
	amount = math_floor(tonumber(amount) or 0)
	if amount < 1 then return false, "bad_amount" end
	local inv = getInv(ply)
	if not inv then return false, "not_loaded" end
	local idx, slot = INV.GetAtSlot(inv, slotNum)
	if not slot then return false, "empty" end
	if slot.amount < amount then return false, "not_enough" end
	local itemId = slot.item_id
	slot.amount = slot.amount - amount
	if slot.amount <= 0 then table.remove(inv, idx) end
	INV.Sync(ply)
	return true, itemId
end

function INV.Count(ply, itemId)
	local inv = getInv(ply)
	if not inv then return 0 end
	local total = 0
	for i = 1, #inv do
		if inv[i].item_id == itemId then total = total + inv[i].amount end
	end
	return total
end

function INV.SwapSlots(ply, slotA, slotB)
	local inv = getInv(ply)
	if not inv then return false end
	slotA, slotB = tonumber(slotA), tonumber(slotB)
	if not slotA or not slotB or slotA == slotB then return false end
	if slotA < 1 or slotB < 1 then return false end
	if slotA > INV.LastBagSlot() or slotB > INV.LastBagSlot() then return false end

	local _, a = INV.GetAtSlot(inv, slotA)
	local _, b = INV.GetAtSlot(inv, slotB)

	-- Equip zone rules
	local function canPlace(slotNum, entry)
		if not entry then return true end
		local def = INV.GetItem(entry.item_id)
		if not def then return false end
		if INV.IsEquipSlot(slotNum) then
			if slotNum == INV.EQUIP_MAIN then return def.equipZone == INV.EQUIP_MAIN end
			if slotNum == INV.EQUIP_SIDE then return def.equipZone == INV.EQUIP_SIDE end
		end
		return true
	end

	if not canPlace(slotA, b) or not canPlace(slotB, a) then
		MintyRP.Util.Notify(ply, "Can't equip that there.", 2)
		return false
	end

	-- Same item stack merge into B
	if a and b and a.item_id == b.item_id then
		local def = INV.GetItem(a.item_id)
		local space = def.maxStack - b.amount
		if space > 0 then
			local move = math_min(space, a.amount)
			b.amount = b.amount + move
			a.amount = a.amount - move
			if a.amount <= 0 then
				local idx = INV.GetAtSlot(inv, slotA)
				if idx then table.remove(inv, idx) end
			end
			INV.Sync(ply)
			return true
		end
	end

	if a then a.slot = slotB end
	if b then b.slot = slotA end
	INV.Sync(ply)
	return true
end

function INV.Sync(ply)
	local inv = getInv(ply)
	if not inv then return end
	local count = math_min(#inv, 128)
	net.Start("MintyRP_InventorySync")
		net.WriteUInt(count, 8)
		for i = 1, count do
			local slot = inv[i]
			net.WriteUInt(math_min(slot.slot or i, 255), 8)
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
	if (ply.MintyRP._invNext or 0) > now then return true end
	ply.MintyRP._invNext = now + RATE_LIMIT
	return false
end

net.Receive("MintyRP_InventorySwap", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if len > 64 then return end
	if rateLimited(ply) then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end
	local a = net.ReadUInt(8)
	local b = net.ReadUInt(8)
	INV.SwapSlots(ply, a, b)
end)

net.Receive("MintyRP_InventoryAction", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if len > 2048 then return end
	if rateLimited(ply) then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end

	local action = net.ReadUInt(4)
	local itemId = net.ReadString()
	local amount = net.ReadUInt(8)
	local slotNum = net.ReadUInt(8)

	if type(itemId) ~= "string" or #itemId < 1 or #itemId > 64 then return end
	if not INV.GetItem(itemId) then return end
	if amount < 1 or amount > MAX_AMOUNT then return end

	if action == ACTION_DROP then
		local def = INV.GetItem(itemId)
		if not def.droppable then
			MintyRP.Util.Notify(ply, "You cannot drop that.", 2)
			return
		end
		local ok
		if slotNum and slotNum > 0 then
			ok = INV.TakeFromSlot(ply, slotNum, amount)
		else
			ok = INV.Take(ply, itemId, amount)
		end
		if not ok then
			MintyRP.Util.Notify(ply, "You don't have enough.", 3)
			return
		end
		MintyRP.Util.Notify(ply, "Dropped " .. amount .. "x " .. def.name .. ".", 0)

	elseif action == ACTION_USE then
		local def = INV.GetItem(itemId)
		if not def.usable then
			MintyRP.Util.Notify(ply, "You cannot use that.", 2)
			return
		end
		local ok
		if slotNum and slotNum > 0 then
			ok = INV.TakeFromSlot(ply, slotNum, 1)
		else
			ok = INV.Take(ply, itemId, 1)
		end
		if not ok then
			MintyRP.Util.Notify(ply, "You don't have that item.", 3)
			return
		end
		hook.Run("MintyRP_ItemUsed", ply, itemId, def)
		MintyRP.Util.Notify(ply, "Used " .. def.name .. ".", 1)

	elseif action == ACTION_MOVE then
		-- Handled by storage module via MintyRP_StorageAction
		MintyRP.Util.Notify(ply, "Open a storage crate to transfer.", 2)

	elseif action == ACTION_SPLIT then
		MintyRP.Util.Notify(ply, "Split coming soon.", 2)
	end
end)

hook.Add("MintyRP_PlayerFirstJoin", "MintyRP_StarterItems", function(ply)
	INV.Give(ply, "water_bottle", 1)
	INV.Give(ply, "sandwich", 1)
	INV.Give(ply, "phone", 1)
end)

print("[MintyRP] Inventory server loaded")
