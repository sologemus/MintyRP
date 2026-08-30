--[[-------------------------------------------------------------------------
	MintyRP — rp_rockford_v2b location tables
	Realm: SHARED

	Coordinates are PLACEHOLDERS keyed for Rockford v2b landmarks.
	Replace Vector/Angle values in-game with `getpos` / `lua_run print(Entity(1):GetPos())`
	once the map is loaded, then commit corrected values.
---------------------------------------------------------------------------]]

MintyRP.Locations = MintyRP.Locations or {}

local Loc = MintyRP.Locations
local Vector = Vector
local Angle = Angle
local game_GetMap = game.GetMap
local string_StartWith = string.StartWith

--[[
	Rockford layout reference (approximate districts):
	- Downtown / commercial: PD, bank, strip mall, offices
	- Civic: hospital, combined FD/EMS
	- Residential: suburbs + apartments
	- Industrial / outskirts: warehouses, beach, trails

	These placeholder positions sit near typical Rockford spawn / city grid
	origins so the gamemode boots without error. They are NOT final.
]]

Loc.Map = "rp_rockford_v2b"

Loc.Points = {
	spawn_civilian = {
		name = "Civilian Spawn",
		pos = Vector(-2890,  -1420,  72),
		ang = Angle(0, 90, 0),
		district = "downtown",
	},

	police_station = {
		name = "Rockford Police Department",
		pos = Vector(-4520,  980,  80),
		ang = Angle(0, 0, 0),
		district = "downtown",
		jobs = { "police", "dispatcher" },
	},

	police_garage = {
		name = "PD Garage",
		pos = Vector(-4780,  1120,  72),
		ang = Angle(0, 180, 0),
		district = "downtown",
	},

	police_cells = {
		name = "PD Holding Cells",
		pos = Vector(-4600,  860,  48),
		ang = Angle(0, 90, 0),
		district = "downtown",
	},

	hospital = {
		name = "Rockford Hospital",
		pos = Vector(1240,  -3180,  80),
		ang = Angle(0, 180, 0),
		district = "civic",
		jobs = { "medic", "doctor" },
	},

	hospital_helipad = {
		name = "Hospital Helipad",
		pos = Vector(1180,  -3400,  320),
		ang = Angle(0, 90, 0),
		district = "civic",
	},

	fire_ems = {
		name = "Fire & EMS Station",
		pos = Vector(980,  -2900,  72),
		ang = Angle(0, 0, 0),
		district = "civic",
		jobs = { "firefighter", "ems" },
	},

	strip_mall = {
		name = "Strip Mall",
		pos = Vector(-1680,  2140,  72),
		ang = Angle(0, 270, 0),
		district = "commercial",
	},

	strip_mall_store_a = {
		name = "Strip Mall — Storefront A",
		pos = Vector(-1580,  2200,  72),
		ang = Angle(0, 180, 0),
		district = "commercial",
	},

	strip_mall_store_b = {
		name = "Strip Mall — Storefront B",
		pos = Vector(-1780,  2200,  72),
		ang = Angle(0, 180, 0),
		district = "commercial",
	},

	bank = {
		name = "Rockford Bank",
		pos = Vector(-3200,  400,  80),
		ang = Angle(0, 90, 0),
		district = "downtown",
	},

	city_hall = {
		name = "City Hall",
		pos = Vector(-2500,  600,  88),
		ang = Angle(0, 0, 0),
		district = "downtown",
	},

	impound = {
		name = "Vehicle Impound",
		pos = Vector(-5100,  1400,  64),
		ang = Angle(0, 45, 0),
		district = "downtown",
	},

	dealership = {
		name = "Vehicle Dealership",
		pos = Vector(2100,  1600,  72),
		ang = Angle(0, 180, 0),
		district = "commercial",
	},

	industrial_warehouse = {
		name = "Industrial Warehouse",
		pos = Vector(4200,  -800,  64),
		ang = Angle(0, 270, 0),
		district = "industrial",
	},

	beach = {
		name = "Rockford Beach",
		pos = Vector(6200,  -4200,  16),
		ang = Angle(0, 135, 0),
		district = "outskirts",
	},

	apartments_nice = {
		name = "Nice Apartments",
		pos = Vector(-800,  -1200,  80),
		ang = Angle(0, 0, 0),
		district = "residential",
	},

	suburb_spawn = {
		name = "Suburban Housing",
		pos = Vector(-6200,  -2800,  72),
		ang = Angle(0, 90, 0),
		district = "residential",
	},
}

function Loc.IsRockford()
	local map = string.lower(game_GetMap() or "")
	return string_StartWith(map, "rp_rockford")
end

function Loc.Get(id)
	return Loc.Points[id]
end

function Loc.GetPos(id)
	local p = Loc.Points[id]
	return p and p.pos or nil
end

function Loc.GetDefaultSpawn()
	return Loc.Points.spawn_civilian
end

function Loc.GetByDistrict(district)
	local out = {}
	for id, data in pairs(Loc.Points) do
		if data.district == district then
			out[id] = data
		end
	end
	return out
end

if SERVER then
	concommand.Add("mintyrp_dumppos", function(ply)
		if IsValid(ply) and not ply:IsSuperAdmin() then return end

		local ent = IsValid(ply) and ply or nil
		if not ent then
			print("[MintyRP] No player to read position from")
			return
		end

		local pos, ang = ent:GetPos(), ent:EyeAngles()
		local msg = string.format(
			"Vector(%.0f, %.0f, %.0f)  Angle(%.0f, %.0f, %.0f)",
			pos.x, pos.y, pos.z, ang.p, ang.y, ang.r
		)
		print("[MintyRP] " .. msg)
		MintyRP.Util.Notify(ply, msg, 0)
	end)
end

print("[MintyRP] Rockford location tables loaded (" .. table.Count(Loc.Points) .. " points)")
