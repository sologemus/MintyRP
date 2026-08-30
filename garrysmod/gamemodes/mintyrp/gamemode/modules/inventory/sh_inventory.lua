--[[-------------------------------------------------------------------------
	MintyRP — Inventory (PERP-inspired slot grid)
	Realm: SHARED

	Design reference: PERP (MIT, msburgess3200/PERP)
	  · Fixed slot grid + main/side equip
	  · Weight + stacks
	  · 3D inventory models with camera hints
---------------------------------------------------------------------------]]

MintyRP.Inventory = MintyRP.Inventory or {}

local INV = MintyRP.Inventory
local math_floor = math.floor
local IsValid = IsValid

INV.EQUIP_MAIN = 1
INV.EQUIP_SIDE = 2

INV.Categories = {
	weapons   = { id = "weapons",   name = "Weapons",   order = 1 },
	ammo      = { id = "ammo",      name = "Ammo",      order = 2 },
	food      = { id = "food",      name = "Food",      order = 3 },
	medical   = { id = "medical",   name = "Medical",   order = 4 },
	materials = { id = "materials", name = "Materials", order = 5 },
	utilities = { id = "utilities", name = "Utilities", order = 6 },
	misc      = { id = "misc",      name = "Misc",      order = 7 },
}

INV.Items = INV.Items or {}

function INV.GridWidth()
	return (MintyRP.Config and MintyRP.Config.InventoryWidth) or 10
end

function INV.GridHeight()
	return (MintyRP.Config and MintyRP.Config.InventoryHeight) or 5
end

function INV.BagSlotCount()
	return INV.GridWidth() * INV.GridHeight()
end

function INV.FirstBagSlot()
	return 3
end

function INV.LastBagSlot()
	return 2 + INV.BagSlotCount()
end

function INV.IsEquipSlot(slot)
	return slot == INV.EQUIP_MAIN or slot == INV.EQUIP_SIDE
end

function INV.IsBagSlot(slot)
	return slot >= INV.FirstBagSlot() and slot <= INV.LastBagSlot()
end

function INV.RegisterItem(id, def)
	if type(id) ~= "string" or id == "" then return end
	if type(def) ~= "table" then return end

	INV.Items[id] = {
		id = id,
		name = def.name or id,
		desc = def.desc or "",
		category = def.category or "misc",
		weight = tonumber(def.weight) or 0.1,
		maxStack = tonumber(def.maxStack) or MintyRP.Config.MaxStackSize or 100,
		model = def.model or "models/props_junk/cardboard_box004a.mdl",
		inventoryModel = def.inventoryModel or def.model or "models/props_junk/cardboard_box004a.mdl",
		modelCamPos = def.modelCamPos or Vector(20, 20, 15),
		modelLookAt = def.modelLookAt or Vector(0, 0, 0),
		modelFOV = def.modelFOV or 45,
		illegal = def.illegal == true,
		droppable = def.droppable ~= false,
		usable = def.usable == true,
		equipZone = def.equipZone, -- EQUIP_MAIN / EQUIP_SIDE / nil
	}
end

function INV.GetItem(id)
	return INV.Items[id]
end

function INV.GetMaxWeight(ply)
	local base = MintyRP.Config.MaxInventoryWeight or 100
	if IsValid(ply) and ply.MintyRP and ply.MintyRP.invBonus then
		return base + (tonumber(ply.MintyRP.invBonus) or 0)
	end
	return base
end

function INV.GetStackWeight(itemId, amount)
	local def = INV.GetItem(itemId)
	if not def then return 0 end
	return (def.weight or 0) * (tonumber(amount) or 0)
end

function INV.CalcWeight(inventory)
	if type(inventory) ~= "table" then return 0 end
	local total = 0
	for i = 1, #inventory do
		local slot = inventory[i]
		if slot and slot.item_id then
			total = total + INV.GetStackWeight(slot.item_id, slot.amount)
		end
	end
	return total
end

function INV.GetAtSlot(inventory, slotNum)
	if type(inventory) ~= "table" then return nil, nil end
	slotNum = tonumber(slotNum)
	for i = 1, #inventory do
		if inventory[i] and inventory[i].slot == slotNum then
			return i, inventory[i]
		end
	end
	return nil, nil
end

function INV.FindSlot(inventory, itemId)
	for i = 1, #inventory do
		local slot = inventory[i]
		if slot and slot.item_id == itemId then
			return i, slot
		end
	end
	return nil, nil
end

function INV.FindFreeBagSlot(inventory)
	local used = {}
	for i = 1, #inventory do
		if inventory[i] and inventory[i].slot then
			used[inventory[i].slot] = true
		end
	end
	for s = INV.FirstBagSlot(), INV.LastBagSlot() do
		if not used[s] then return s end
	end
	return nil
end

function INV.FromDBRows(rows)
	local inv = {}
	if type(rows) ~= "table" then return inv end
	for i = 1, #rows do
		local row = rows[i]
		local slot = math_floor(tonumber(row.slot) or (#inv + INV.FirstBagSlot()))
		inv[#inv + 1] = {
			slot = slot,
			item_id = row.item_id,
			amount = math_floor(tonumber(row.amount) or 1),
			meta = row.meta or "{}",
		}
	end
	return inv
end

function INV.ToDBRows(inventory)
	local rows = {}
	if type(inventory) ~= "table" then return rows end
	for i = 1, #inventory do
		local slot = inventory[i]
		if slot and slot.item_id and (slot.amount or 0) > 0 then
			rows[#rows + 1] = {
				slot = slot.slot or i,
				item_id = slot.item_id,
				amount = math_floor(slot.amount),
				meta = slot.meta or "{}",
			}
		end
	end
	return rows
end

-- ─── items (PERP-style camera fields) ─────────────────────

INV.RegisterItem("cash_roll", {
	name = "Cash Roll",
	desc = "A small roll of bills.",
	category = "misc",
	weight = 0.05,
	maxStack = 50,
	model = "models/props/cs_assault/money.mdl",
	inventoryModel = "models/props/cs_assault/money.mdl",
	modelCamPos = Vector(10, 10, 8),
	modelFOV = 40,
})

INV.RegisterItem("water_bottle", {
	name = "Water Bottle",
	desc = "Clean bottled water.",
	category = "food",
	weight = 0.4,
	maxStack = 10,
	usable = true,
	model = "models/props/cs_office/Water_bottle.mdl",
	inventoryModel = "models/props/cs_office/Water_bottle.mdl",
	modelCamPos = Vector(12, 12, 8),
	modelFOV = 35,
})

INV.RegisterItem("sandwich", {
	name = "Sandwich",
	desc = "A simple sandwich. Keeps you going.",
	category = "food",
	weight = 0.3,
	maxStack = 10,
	usable = true,
	model = "models/props_junk/garbage_takeoutcarton001a.mdl",
	inventoryModel = "models/props_junk/garbage_takeoutcarton001a.mdl",
	modelCamPos = Vector(14, 14, 10),
	modelFOV = 40,
})

INV.RegisterItem("bandage", {
	name = "Bandage",
	desc = "Basic first-aid wrap.",
	category = "medical",
	weight = 0.15,
	maxStack = 20,
	usable = true,
	model = "models/props_lab/box01a.mdl",
	inventoryModel = "models/props_lab/box01a.mdl",
	modelCamPos = Vector(16, 16, 10),
	modelFOV = 40,
})

INV.RegisterItem("phone", {
	name = "Phone",
	desc = "A basic mobile phone.",
	category = "utilities",
	weight = 0.25,
	maxStack = 1,
	model = "models/props_lab/reciever01b.mdl",
	inventoryModel = "models/props_lab/reciever01b.mdl",
	modelCamPos = Vector(10, 10, 6),
	modelFOV = 35,
})

INV.RegisterItem("scrap_metal", {
	name = "Scrap Metal",
	desc = "Reusable metal scraps for crafting.",
	category = "materials",
	weight = 0.5,
	maxStack = 50,
	model = "models/props_junk/garbage_metalcan001a.mdl",
	inventoryModel = "models/props_junk/garbage_metalcan001a.mdl",
	modelCamPos = Vector(14, 14, 10),
	modelFOV = 40,
})

INV.RegisterItem("pistol_ammo", {
	name = "Pistol Ammo",
	desc = "A box of pistol rounds.",
	category = "ammo",
	weight = 0.8,
	maxStack = 10,
	model = "models/Items/BoxSRounds.mdl",
	inventoryModel = "models/Items/BoxSRounds.mdl",
	modelCamPos = Vector(18, 18, 12),
	modelFOV = 45,
})

print("[MintyRP] Inventory shared definitions loaded (PERP-style slots)")
