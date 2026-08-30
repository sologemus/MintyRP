--[[-------------------------------------------------------------------------
	MintyRP — Inventory definitions (Perpheads-style weight + categories)
	Realm: SHARED

	Mechanics inspired by serious-RP inventories:
	- Weight-limited personal inventory
	- Category sorting (Weapons, Food, Medical, Materials, Utilities, Misc)
	- Stackable amounts with max stack
	- Storage transfer actions handled server-side only
---------------------------------------------------------------------------]]

MintyRP.Inventory = MintyRP.Inventory or {}

local INV = MintyRP.Inventory
local math_floor = math.floor
local IsValid = IsValid

INV.Categories = {
	weapons   = { id = "weapons",   name = "Weapons",   order = 1 },
	ammo      = { id = "ammo",      name = "Ammo",      order = 2 },
	food      = { id = "food",      name = "Food",      order = 3 },
	medical   = { id = "medical",   name = "Medical",   order = 4 },
	materials = { id = "materials", name = "Materials", order = 5 },
	utilities = { id = "utilities", name = "Utilities", order = 6 },
	misc      = { id = "misc",      name = "Misc",      order = 7 },
}

--- Item registry. Add items via MintyRP.Inventory.RegisterItem
INV.Items = INV.Items or {}

function INV.RegisterItem(id, def)
	if type(id) ~= "string" or id == "" then return end
	if type(def) ~= "table" then return end

	INV.Items[id] = {
		id          = id,
		name        = def.name or id,
		desc        = def.desc or "",
		category    = def.category or "misc",
		weight      = tonumber(def.weight) or 0.1,
		maxStack    = tonumber(def.maxStack) or MintyRP.Config.MaxStackSize or 100,
		model       = def.model or "models/props_junk/cardboard_box004a.mdl",
		illegal     = def.illegal == true,
		droppable   = def.droppable ~= false,
		usable      = def.usable == true,
	}
end

function INV.GetItem(id)
	return INV.Items[id]
end

function INV.GetMaxWeight(ply)
	local base = MintyRP.Config.MaxInventoryWeight or 50
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

function INV.FindSlot(inventory, itemId)
	for i = 1, #inventory do
		local slot = inventory[i]
		if slot and slot.item_id == itemId then
			return i, slot
		end
	end
	return nil, nil
end

function INV.FromDBRows(rows)
	local inv = {}
	if type(rows) ~= "table" then return inv end

	for i = 1, #rows do
		local row = rows[i]
		inv[#inv + 1] = {
			slot = row.slot or (#inv + 1),
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

-- Starter item definitions (expand in later modules)
INV.RegisterItem("cash_roll", {
	name = "Cash Roll",
	desc = "A small roll of bills.",
	category = "misc",
	weight = 0.05,
	maxStack = 50,
})

INV.RegisterItem("water_bottle", {
	name = "Water Bottle",
	desc = "Clean bottled water.",
	category = "food",
	weight = 0.4,
	maxStack = 10,
	usable = true,
	model = "models/props/cs_office/Water_bottle.mdl",
})

INV.RegisterItem("sandwich", {
	name = "Sandwich",
	desc = "A simple sandwich. Keeps you going.",
	category = "food",
	weight = 0.3,
	maxStack = 10,
	usable = true,
})

INV.RegisterItem("bandage", {
	name = "Bandage",
	desc = "Basic first-aid wrap.",
	category = "medical",
	weight = 0.15,
	maxStack = 20,
	usable = true,
})

INV.RegisterItem("phone", {
	name = "Phone",
	desc = "A basic mobile phone.",
	category = "utilities",
	weight = 0.25,
	maxStack = 1,
})

INV.RegisterItem("scrap_metal", {
	name = "Scrap Metal",
	desc = "Reusable metal scraps for crafting.",
	category = "materials",
	weight = 0.5,
	maxStack = 50,
})

INV.RegisterItem("pistol_ammo", {
	name = "Pistol Ammo",
	desc = "A box of pistol rounds.",
	category = "ammo",
	weight = 0.8,
	maxStack = 10,
})

print("[MintyRP] Inventory shared definitions loaded")
