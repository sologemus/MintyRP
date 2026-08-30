--[[-------------------------------------------------------------------------
	MintyRP — Property catalog (rp_rockford_v2b)
	Realm: SHARED

	Organized like serious-RP (Perpheads-style) tiers:
	  studio / affordable apt < nice apt < house < shop < warehouse

	Door linking uses center + radius until MapCreationIDs are pinned.
	Tune with mintyrp_dumppos + mintyrp_propscan.
---------------------------------------------------------------------------]]

MintyRP.Property = MintyRP.Property or {}

local Prop = MintyRP.Property
local Vector = Vector

Prop.DoorClasses = {
	prop_door_rotating = true,
	func_door = true,
	func_door_rotating = true,
}

-- Display order for menus
Prop.CategoryOrder = {
	studio = 1,
	apartment = 2,
	house = 3,
	shop = 4,
	warehouse = 5,
}

Prop.DistrictOrder = {
	downtown = 1,
	commercial = 2,
	civic = 3,
	residential = 4,
	industrial = 5,
	outskirts = 6,
}

--[[
	Pricing philosophy (cash on hand, early economy):
	- Studio / cheap apt:   1.5k–4k
	- Standard apartment:   4k–8k
	- Nice apartment:       8k–14k
	- Suburban house:       15k–35k
	- Small shop:           20k–40k
	- Strip / retail:       35k–60k
	- Warehouse / industrial: 50k–120k
]]

local function P(id, data)
	data.id = id
	data.doors = data.doors or {}
	Prop.List = Prop.List or {}
	Prop.List[id] = data
end

Prop.List = {}

-- ═══════════════════════════════════════════
-- DOWNTOWN — studios & walk-ups
-- ═══════════════════════════════════════════
P("dt_studio_01", {
	name = "Downtown Studio 01",
	category = "studio",
	district = "downtown",
	price = 1500,
	center = Vector(-2700, -1100, 80),
	radius = 160,
})
P("dt_studio_02", {
	name = "Downtown Studio 02",
	category = "studio",
	district = "downtown",
	price = 1750,
	center = Vector(-2620, -1180, 80),
	radius = 160,
})
P("dt_walkup_01", {
	name = "Downtown Walk-up 1A",
	category = "apartment",
	district = "downtown",
	price = 4000,
	center = Vector(-2400, -900, 80),
	radius = 180,
})
P("dt_walkup_02", {
	name = "Downtown Walk-up 1B",
	category = "apartment",
	district = "downtown",
	price = 4250,
	center = Vector(-2320, -980, 80),
	radius = 180,
})
P("dt_walkup_03", {
	name = "Downtown Walk-up 2A",
	category = "apartment",
	district = "downtown",
	price = 4500,
	center = Vector(-2400, -900, 200),
	radius = 180,
})

-- ═══════════════════════════════════════════
-- RESIDENTIAL — apartments & suburb homes
-- ═══════════════════════════════════════════
P("res_apt_afford_01", {
	name = "Affordable Apartments 01",
	category = "apartment",
	district = "residential",
	price = 3500,
	center = Vector(-900, -1400, 80),
	radius = 200,
})
P("res_apt_afford_02", {
	name = "Affordable Apartments 02",
	category = "apartment",
	district = "residential",
	price = 3500,
	center = Vector(-820, -1480, 80),
	radius = 200,
})
P("res_apt_afford_03", {
	name = "Affordable Apartments 03",
	category = "apartment",
	district = "residential",
	price = 3750,
	center = Vector(-740, -1400, 80),
	radius = 200,
})
P("res_apt_nice_01", {
	name = "Nice Apartments 01",
	category = "apartment",
	district = "residential",
	price = 9000,
	center = Vector(-800, -1200, 80),
	radius = 220,
})
P("res_apt_nice_02", {
	name = "Nice Apartments 02",
	category = "apartment",
	district = "residential",
	price = 9500,
	center = Vector(-720, -1280, 80),
	radius = 220,
})
P("res_apt_nice_03", {
	name = "Nice Apartments 03",
	category = "apartment",
	district = "residential",
	price = 10000,
	center = Vector(-640, -1200, 200),
	radius = 220,
})
P("res_apt_nice_04", {
	name = "Nice Apartments 04",
	category = "apartment",
	district = "residential",
	price = 10500,
	center = Vector(-880, -1120, 200),
	radius = 220,
})

P("res_house_01", {
	name = "Suburban House 01",
	category = "house",
	district = "residential",
	price = 18000,
	center = Vector(-6200, -2800, 72),
	radius = 380,
})
P("res_house_02", {
	name = "Suburban House 02",
	category = "house",
	district = "residential",
	price = 20000,
	center = Vector(-6000, -3000, 72),
	radius = 380,
})
P("res_house_03", {
	name = "Suburban House 03",
	category = "house",
	district = "residential",
	price = 22000,
	center = Vector(-5800, -2800, 72),
	radius = 380,
})
P("res_house_04", {
	name = "Suburban House 04",
	category = "house",
	district = "residential",
	price = 25000,
	center = Vector(-6400, -2600, 72),
	radius = 400,
})
P("res_house_05", {
	name = "Suburban House 05",
	category = "house",
	district = "residential",
	price = 28000,
	center = Vector(-5600, -3200, 72),
	radius = 400,
})
P("res_house_06", {
	name = "Country Home",
	category = "house",
	district = "outskirts",
	price = 35000,
	center = Vector(-7000, -4000, 64),
	radius = 450,
})

-- ═══════════════════════════════════════════
-- COMMERCIAL — strip mall & retail
-- ═══════════════════════════════════════════
P("com_strip_a", {
	name = "Strip Mall Unit A",
	category = "shop",
	district = "commercial",
	price = 35000,
	center = Vector(-1580, 2200, 72),
	radius = 170,
})
P("com_strip_b", {
	name = "Strip Mall Unit B",
	category = "shop",
	district = "commercial",
	price = 38000,
	center = Vector(-1680, 2200, 72),
	radius = 170,
})
P("com_strip_c", {
	name = "Strip Mall Unit C",
	category = "shop",
	district = "commercial",
	price = 40000,
	center = Vector(-1780, 2200, 72),
	radius = 170,
})
P("com_strip_d", {
	name = "Strip Mall Unit D",
	category = "shop",
	district = "commercial",
	price = 42000,
	center = Vector(-1880, 2200, 72),
	radius = 170,
})
P("com_corner_store", {
	name = "Corner Convenience",
	category = "shop",
	district = "commercial",
	price = 28000,
	center = Vector(-1400, 1800, 72),
	radius = 200,
})
P("com_office_01", {
	name = "Downtown Office Suite",
	category = "shop",
	district = "downtown",
	price = 45000,
	center = Vector(-3000, 200, 120),
	radius = 220,
})
P("com_dealership_office", {
	name = "Dealership Office",
	category = "shop",
	district = "commercial",
	price = 55000,
	center = Vector(2100, 1600, 72),
	radius = 250,
})

-- ═══════════════════════════════════════════
-- CIVIC / NEAR HOSPITAL — clinics & small units
-- ═══════════════════════════════════════════
P("civic_clinic_apt", {
	name = "Clinic Row Apartment",
	category = "apartment",
	district = "civic",
	price = 6000,
	center = Vector(1100, -3000, 80),
	radius = 180,
})
P("civic_side_shop", {
	name = "EMS District Storefront",
	category = "shop",
	district = "civic",
	price = 32000,
	center = Vector(900, -2700, 72),
	radius = 180,
})

-- ═══════════════════════════════════════════
-- INDUSTRIAL
-- ═══════════════════════════════════════════
P("ind_warehouse_01", {
	name = "Warehouse Unit 01",
	category = "warehouse",
	district = "industrial",
	price = 55000,
	center = Vector(4200, -800, 64),
	radius = 420,
})
P("ind_warehouse_02", {
	name = "Warehouse Unit 02",
	category = "warehouse",
	district = "industrial",
	price = 65000,
	center = Vector(4500, -600, 64),
	radius = 420,
})
P("ind_garage_01", {
	name = "Industrial Garage",
	category = "warehouse",
	district = "industrial",
	price = 40000,
	center = Vector(3900, -1000, 64),
	radius = 300,
})
P("ind_lot_office", {
	name = "Yard Office",
	category = "shop",
	district = "industrial",
	price = 22000,
	center = Vector(4100, -500, 72),
	radius = 160,
})

-- ═══════════════════════════════════════════
-- OUTSKIRTS / BEACH
-- ═══════════════════════════════════════════
P("out_cabin_01", {
	name = "Beach Cabin 01",
	category = "house",
	district = "outskirts",
	price = 30000,
	center = Vector(6000, -4100, 24),
	radius = 280,
})
P("out_cabin_02", {
	name = "Beach Cabin 02",
	category = "house",
	district = "outskirts",
	price = 32000,
	center = Vector(6300, -4300, 24),
	radius = 280,
})

function Prop.Get(id)
	return Prop.List[id]
end

function Prop.IsDoor(ent)
	return IsValid(ent) and Prop.DoorClasses[ent:GetClass()] == true
end

function Prop.GetSorted()
	local out = {}
	for id, def in pairs(Prop.List) do
		out[#out + 1] = def
	end
	table.sort(out, function(a, b)
		local da = Prop.DistrictOrder[a.district] or 99
		local db = Prop.DistrictOrder[b.district] or 99
		if da ~= db then return da < db end
		local ca = Prop.CategoryOrder[a.category] or 99
		local cb = Prop.CategoryOrder[b.category] or 99
		if ca ~= cb then return ca < cb end
		return (a.price or 0) < (b.price or 0)
	end)
	return out
end

print("[MintyRP] Property catalog loaded (" .. table.Count(Prop.List) .. " properties)")
