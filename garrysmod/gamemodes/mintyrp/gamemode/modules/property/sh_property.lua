--[[-------------------------------------------------------------------------
	MintyRP — Property definitions (rp_rockford_v2b)
	Realm: SHARED

	Doors are claimed at runtime by scanning map door entities near each
	property center (MapCreationIDs cached on server). Replace centers with
	mintyrp_dumppos values as you walk Rockford.
---------------------------------------------------------------------------]]

MintyRP.Property = MintyRP.Property or {}

local Prop = MintyRP.Property

Prop.DoorClasses = {
	prop_door_rotating = true,
	func_door = true,
	func_door_rotating = true,
}

Prop.List = {
	apt_downtown_1a = {
		id = "apt_downtown_1a",
		name = "Downtown Apartment 1A",
		category = "apartment",
		district = "residential",
		price = 2500,
		center = Vector(-800, -1200, 80),
		radius = 220,
		doors = {}, -- filled server-side
	},
	apt_downtown_1b = {
		id = "apt_downtown_1b",
		name = "Downtown Apartment 1B",
		category = "apartment",
		district = "residential",
		price = 2500,
		center = Vector(-720, -1280, 80),
		radius = 200,
		doors = {},
	},
	apt_suburb_01 = {
		id = "apt_suburb_01",
		name = "Suburban House 01",
		category = "house",
		district = "residential",
		price = 8000,
		center = Vector(-6200, -2800, 72),
		radius = 350,
		doors = {},
	},
	shop_strip_a = {
		id = "shop_strip_a",
		name = "Strip Mall Unit A",
		category = "shop",
		district = "commercial",
		price = 12000,
		center = Vector(-1580, 2200, 72),
		radius = 180,
		doors = {},
	},
	shop_strip_b = {
		id = "shop_strip_b",
		name = "Strip Mall Unit B",
		category = "shop",
		district = "commercial",
		price = 12000,
		center = Vector(-1780, 2200, 72),
		radius = 180,
		doors = {},
	},
	warehouse_01 = {
		id = "warehouse_01",
		name = "Industrial Warehouse",
		category = "warehouse",
		district = "industrial",
		price = 20000,
		center = Vector(4200, -800, 64),
		radius = 400,
		doors = {},
	},
}

function Prop.Get(id)
	return Prop.List[id]
end

function Prop.IsDoor(ent)
	return IsValid(ent) and Prop.DoorClasses[ent:GetClass()] == true
end

print("[MintyRP] Property definitions loaded (" .. table.Count(Prop.List) .. ")")
