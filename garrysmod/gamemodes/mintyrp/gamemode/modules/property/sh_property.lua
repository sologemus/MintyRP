--[[-------------------------------------------------------------------------
	MintyRP — Full Rockford v2b property catalog
	Realm: SHARED

	Every major building is registered so doors can be claimed.
	  ownable = true  → players may buy / sell / key-lock
	  ownable = false → city, franchise, or reserved (not for sale)

	Door linking still uses center+radius until MapCreationIDs are pinned.
---------------------------------------------------------------------------]]

MintyRP.Property = MintyRP.Property or {}

local Prop = MintyRP.Property
local Vector = Vector

Prop.DoorClasses = {
	prop_door_rotating = true,
	func_door = true,
	func_door_rotating = true,
}

Prop.CategoryOrder = {
	city = 0,
	franchise = 0,
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
	ownable false reasons:
	  city      — government / municipal
	  franchise — premade chain / venue (gas, club, cinema, bank, etc.)
	  reserved  — staff / system

	doorPolicy:
	  public  — never block +use (lobbies, bank floor, dealership floor)
	  secure  — locked; no civilian buy; job access later
	  owner   — normal owned-door rules (default for ownable)
]]

Prop.List = {}

local function P(id, data)
	data.id = id
	data.ownable = data.ownable ~= false -- default true unless set false
	if data.ownable then
		data.ownerType = data.ownerType or "private"
		data.doorPolicy = data.doorPolicy or "owner"
		data.price = data.price or 5000
	else
		data.ownerType = data.ownerType or "city"
		data.doorPolicy = data.doorPolicy or "secure"
		data.price = 0
	end
	data.doors = {}
	Prop.List[id] = data
end

-- ═══════════════════════════════════════════════════════════
-- CITY / GOVERNMENT — not ownable
-- ═══════════════════════════════════════════════════════════
P("city_police_station", {
	name = "Rockford Police Department",
	category = "city", district = "downtown",
	ownable = false, ownerType = "city", doorPolicy = "secure",
	center = Vector(-4520, 980, 80), radius = 520,
})
P("city_police_garage", {
	name = "PD Garage",
	category = "city", district = "downtown",
	ownable = false, ownerType = "city", doorPolicy = "secure",
	center = Vector(-4780, 1120, 72), radius = 280,
})
P("city_police_cells", {
	name = "PD Holding Cells",
	category = "city", district = "downtown",
	ownable = false, ownerType = "city", doorPolicy = "secure",
	center = Vector(-4600, 860, 48), radius = 220,
})
P("city_hall", {
	name = "City Hall",
	category = "city", district = "downtown",
	ownable = false, ownerType = "city", doorPolicy = "public",
	center = Vector(-2500, 600, 88), radius = 400,
})
P("city_bank", {
	name = "Rockford Bank",
	category = "franchise", district = "downtown",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(-3200, 400, 80), radius = 320,
})
P("city_impound", {
	name = "Vehicle Impound",
	category = "city", district = "downtown",
	ownable = false, ownerType = "city", doorPolicy = "secure",
	center = Vector(-5100, 1400, 64), radius = 350,
})
P("city_hospital", {
	name = "Rockford Hospital",
	category = "city", district = "civic",
	ownable = false, ownerType = "city", doorPolicy = "public",
	center = Vector(1240, -3180, 80), radius = 480,
})
P("city_hospital_secure", {
	name = "Hospital Staff Wing",
	category = "city", district = "civic",
	ownable = false, ownerType = "city", doorPolicy = "secure",
	center = Vector(1320, -3300, 80), radius = 220,
})
P("city_fire_ems", {
	name = "Fire & EMS Station",
	category = "city", district = "civic",
	ownable = false, ownerType = "city", doorPolicy = "secure",
	center = Vector(980, -2900, 72), radius = 400,
})
P("city_transit", {
	name = "Rockford Transit Authority",
	category = "city", district = "downtown",
	ownable = false, ownerType = "city", doorPolicy = "public",
	center = Vector(-2000, 900, 72), radius = 300,
})

-- ═══════════════════════════════════════════════════════════
-- FRANCHISE / PREMADE VENUES — not ownable
-- ═══════════════════════════════════════════════════════════
P("fran_gas_downtown", {
	name = "Downtown Gas Station",
	category = "franchise", district = "downtown",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(-3600, -200, 72), radius = 280,
})
P("fran_gas_industrial", {
	name = "Industrial Gas Station",
	category = "franchise", district = "industrial",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(3800, -200, 64), radius = 280,
})
P("fran_gas_suburb", {
	name = "Suburban Gas Station",
	category = "franchise", district = "residential",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(-5500, -2200, 72), radius = 260,
})
P("fran_nightclub", {
	name = "Rockford Nightclub",
	category = "franchise", district = "commercial",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(-1200, 1600, 72), radius = 320,
})
P("fran_pub", {
	name = "Ol' Stool Pub",
	category = "franchise", district = "downtown",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(-2800, 200, 72), radius = 260,
})
P("fran_cinema", {
	name = "Rockford Cinema",
	category = "franchise", district = "commercial",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(-1000, 2400, 72), radius = 340,
})
P("fran_dealership", {
	name = "Vehicle Dealership",
	category = "franchise", district = "commercial",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(2100, 1600, 72), radius = 420,
})
P("fran_repair_garage", {
	name = "Repair Garage",
	category = "franchise", district = "industrial",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(3600, -400, 64), radius = 300,
})
P("fran_fastfood", {
	name = "Fast Food Restaurant",
	category = "franchise", district = "commercial",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(-1900, 1900, 72), radius = 240,
})
P("fran_convenience", {
	name = "Convenience Store",
	category = "franchise", district = "commercial",
	ownable = false, ownerType = "franchise", doorPolicy = "public",
	center = Vector(-1400, 1800, 72), radius = 220,
})

-- ═══════════════════════════════════════════════════════════
-- DOWNTOWN — ownable studios / walk-ups / offices
-- ═══════════════════════════════════════════════════════════
P("dt_studio_01", { name = "Downtown Studio 01", category = "studio", district = "downtown", price = 1500, center = Vector(-2700, -1100, 80), radius = 150 })
P("dt_studio_02", { name = "Downtown Studio 02", category = "studio", district = "downtown", price = 1600, center = Vector(-2620, -1180, 80), radius = 150 })
P("dt_studio_03", { name = "Downtown Studio 03", category = "studio", district = "downtown", price = 1700, center = Vector(-2540, -1100, 80), radius = 150 })
P("dt_studio_04", { name = "Downtown Studio 04", category = "studio", district = "downtown", price = 1800, center = Vector(-2700, -1100, 200), radius = 150 })

P("dt_walkup_1a", { name = "Downtown Walk-up 1A", category = "apartment", district = "downtown", price = 4000, center = Vector(-2400, -900, 80), radius = 160 })
P("dt_walkup_1b", { name = "Downtown Walk-up 1B", category = "apartment", district = "downtown", price = 4100, center = Vector(-2320, -980, 80), radius = 160 })
P("dt_walkup_1c", { name = "Downtown Walk-up 1C", category = "apartment", district = "downtown", price = 4200, center = Vector(-2240, -900, 80), radius = 160 })
P("dt_walkup_2a", { name = "Downtown Walk-up 2A", category = "apartment", district = "downtown", price = 4500, center = Vector(-2400, -900, 200), radius = 160 })
P("dt_walkup_2b", { name = "Downtown Walk-up 2B", category = "apartment", district = "downtown", price = 4600, center = Vector(-2320, -980, 200), radius = 160 })
P("dt_walkup_2c", { name = "Downtown Walk-up 2C", category = "apartment", district = "downtown", price = 4700, center = Vector(-2240, -900, 200), radius = 160 })

P("dt_office_01", { name = "Downtown Office 01", category = "shop", district = "downtown", price = 28000, center = Vector(-3000, 200, 120), radius = 180 })
P("dt_office_02", { name = "Downtown Office 02", category = "shop", district = "downtown", price = 30000, center = Vector(-3100, 280, 120), radius = 180 })
P("dt_office_03", { name = "Downtown Office 03", category = "shop", district = "downtown", price = 32000, center = Vector(-2900, 120, 200), radius = 180 })
P("dt_shop_01", { name = "Downtown Storefront 01", category = "shop", district = "downtown", price = 24000, center = Vector(-2600, -400, 72), radius = 170 })
P("dt_shop_02", { name = "Downtown Storefront 02", category = "shop", district = "downtown", price = 26000, center = Vector(-2500, -480, 72), radius = 170 })

-- ═══════════════════════════════════════════════════════════
-- RESIDENTIAL — 6 affordable + 12 nice apts + 6 suburb + country
-- (matches Rockford housing counts)
-- ═══════════════════════════════════════════════════════════
for i = 1, 6 do
	local col = (i - 1) % 3
	local row = math.floor((i - 1) / 3)
	P(string.format("res_afford_%02d", i), {
		name = string.format("Affordable Apartment %02d", i),
		category = "apartment", district = "residential",
		price = 3200 + (i * 150),
		center = Vector(-900 + col * 90, -1450 - row * 90, 80 + (i > 3 and 120 or 0)),
		radius = 140,
	})
end

for i = 1, 12 do
	local col = (i - 1) % 4
	local row = math.floor((i - 1) / 4)
	local floor = row -- 0,1,2 as floors
	P(string.format("res_nice_%02d", i), {
		name = string.format("Nice Apartment %02d", i),
		category = "apartment", district = "residential",
		price = 8500 + (i * 250),
		center = Vector(-850 + col * 100, -1250 - (row % 2) * 100, 80 + floor * 120),
		radius = 145,
	})
end

P("res_house_01", { name = "Suburban House 01", category = "house", district = "residential", price = 18000, center = Vector(-6200, -2800, 72), radius = 360 })
P("res_house_02", { name = "Suburban House 02", category = "house", district = "residential", price = 19500, center = Vector(-6000, -3000, 72), radius = 360 })
P("res_house_03", { name = "Suburban House 03", category = "house", district = "residential", price = 21000, center = Vector(-5800, -2800, 72), radius = 360 })
P("res_house_04", { name = "Suburban House 04", category = "house", district = "residential", price = 22500, center = Vector(-6400, -2600, 72), radius = 360 })
P("res_house_05", { name = "Suburban House 05", category = "house", district = "residential", price = 24000, center = Vector(-5600, -3200, 72), radius = 360 })
P("res_house_06", { name = "Suburban House 06", category = "house", district = "residential", price = 26000, center = Vector(-6100, -3100, 72), radius = 360 })
P("res_country_01", { name = "Country Home", category = "house", district = "outskirts", price = 35000, center = Vector(-7000, -4000, 64), radius = 450 })

-- ═══════════════════════════════════════════════════════════
-- COMMERCIAL — strip mall private units (ownable)
-- ═══════════════════════════════════════════════════════════
P("com_strip_a", { name = "Strip Mall Unit A", category = "shop", district = "commercial", price = 35000, center = Vector(-1520, 2200, 72), radius = 140 })
P("com_strip_b", { name = "Strip Mall Unit B", category = "shop", district = "commercial", price = 37000, center = Vector(-1620, 2200, 72), radius = 140 })
P("com_strip_c", { name = "Strip Mall Unit C", category = "shop", district = "commercial", price = 39000, center = Vector(-1720, 2200, 72), radius = 140 })
P("com_strip_d", { name = "Strip Mall Unit D", category = "shop", district = "commercial", price = 41000, center = Vector(-1820, 2200, 72), radius = 140 })
P("com_strip_e", { name = "Strip Mall Unit E", category = "shop", district = "commercial", price = 43000, center = Vector(-1920, 2200, 72), radius = 140 })
P("com_strip_f", { name = "Strip Mall Unit F", category = "shop", district = "commercial", price = 45000, center = Vector(-2020, 2200, 72), radius = 140 })
P("com_retail_01", { name = "Commercial Retail 01", category = "shop", district = "commercial", price = 30000, center = Vector(-1300, 2000, 72), radius = 160 })
P("com_retail_02", { name = "Commercial Retail 02", category = "shop", district = "commercial", price = 32000, center = Vector(-1200, 2080, 72), radius = 160 })

-- ═══════════════════════════════════════════════════════════
-- CIVIC — private units near hospital (not the hospital itself)
-- ═══════════════════════════════════════════════════════════
P("civic_apt_01", { name = "Clinic Row Apt 01", category = "apartment", district = "civic", price = 5500, center = Vector(1100, -3000, 80), radius = 150 })
P("civic_apt_02", { name = "Clinic Row Apt 02", category = "apartment", district = "civic", price = 5750, center = Vector(1180, -2920, 80), radius = 150 })
P("civic_shop_01", { name = "Civic Storefront 01", category = "shop", district = "civic", price = 27000, center = Vector(900, -2700, 72), radius = 160 })
P("civic_shop_02", { name = "Civic Storefront 02", category = "shop", district = "civic", price = 29000, center = Vector(820, -2620, 72), radius = 160 })

-- ═══════════════════════════════════════════════════════════
-- INDUSTRIAL — ownable warehouses / garages / yard offices
-- ═══════════════════════════════════════════════════════════
P("ind_wh_01", { name = "Warehouse 01", category = "warehouse", district = "industrial", price = 55000, center = Vector(4200, -800, 64), radius = 380 })
P("ind_wh_02", { name = "Warehouse 02", category = "warehouse", district = "industrial", price = 62000, center = Vector(4550, -650, 64), radius = 380 })
P("ind_wh_03", { name = "Warehouse 03", category = "warehouse", district = "industrial", price = 70000, center = Vector(4900, -900, 64), radius = 380 })
P("ind_garage_01", { name = "Industrial Garage 01", category = "warehouse", district = "industrial", price = 38000, center = Vector(3900, -1000, 64), radius = 260 })
P("ind_garage_02", { name = "Industrial Garage 02", category = "warehouse", district = "industrial", price = 40000, center = Vector(4050, -1150, 64), radius = 260 })
P("ind_yard_office", { name = "Yard Office", category = "shop", district = "industrial", price = 18000, center = Vector(4100, -500, 72), radius = 150 })

-- ═══════════════════════════════════════════════════════════
-- OUTSKIRTS / BEACH — cabins
-- ═══════════════════════════════════════════════════════════
P("out_cabin_01", { name = "Beach Cabin 01", category = "house", district = "outskirts", price = 30000, center = Vector(6000, -4100, 24), radius = 260 })
P("out_cabin_02", { name = "Beach Cabin 02", category = "house", district = "outskirts", price = 32000, center = Vector(6300, -4300, 24), radius = 260 })

-- ─── helpers ───────────────────────────────────────────────

function Prop.Get(id)
	return Prop.List[id]
end

function Prop.IsDoor(ent)
	return IsValid(ent) and Prop.DoorClasses[ent:GetClass()] == true
end

function Prop.IsOwnable(id)
	local def = Prop.List[id]
	if not def then return false end
	if def.ownable == nil then return true end
	return def.ownable == true
end

function Prop.GetOwnerLabel(def)
	if not def then return "Unknown property" end
	if def.ownable ~= false then return "For sale" end
	if def.ownerType == "franchise" then return "Franchise — not for sale" end
	return "City property — not for sale"
end

function Prop.GetSorted()
	return def and def.ownable == true
end

function Prop.GetOwnerLabel(def)
	if not def then return "" end
	if def.ownable then return "For sale" end
	if def.ownerType == "franchise" then return "Franchise — not for sale" end
	if def.ownerType == "city" then return "City property — not for sale" end
	return "Not for sale"
end

function Prop.GetSorted(filter)
	local out = {}
	for _, def in pairs(Prop.List) do
		if not filter or filter(def) then
			out[#out + 1] = def
		end
	end
	table.sort(out, function(a, b)
		-- For-sale first, then reserved
		local oa = a.ownable and 0 or 1
		local ob = b.ownable and 0 or 1
		if oa ~= ob then return oa < ob end
		local da = Prop.DistrictOrder[a.district] or 99
		local db = Prop.DistrictOrder[b.district] or 99
		if da ~= db then return da < db end
		local ca = Prop.CategoryOrder[a.category] or 99
		local cb = Prop.CategoryOrder[b.category] or 99
		if ca ~= cb then return ca < cb end
		return (a.name or "") < (b.name or "")
	end)
	return out
end

local ownable, reserved = 0, 0
for _, def in pairs(Prop.List) do
	if def.ownable then ownable = ownable + 1 else reserved = reserved + 1 end
end
print(string.format("[MintyRP] Property catalog: %d ownable, %d city/franchise (%d total)",
	ownable, reserved, ownable + reserved))
