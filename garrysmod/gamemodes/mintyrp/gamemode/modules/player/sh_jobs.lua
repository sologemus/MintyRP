--[[-------------------------------------------------------------------------
	MintyRP — Faction / duty job stubs (not DarkRP jobs)
	Realm: SHARED

	Civilian paycheck jobs live in modules/economy (F2 → Work).
	These stubs are for future PD / medic / FD duty systems.
---------------------------------------------------------------------------]]

MintyRP.Jobs = MintyRP.Jobs or {}

local Jobs = MintyRP.Jobs

Jobs.List = {
	citizen = {
		id = "citizen",
		name = "Citizen",
		salary = 0,
		color = Color(180, 180, 180),
		loadout = {},
	},
	police = {
		id = "police",
		name = "Police Officer",
		salary = 80,
		color = Color(40, 80, 160),
		spawn = "police_station",
		loadout = {},
	},
	medic = {
		id = "medic",
		name = "Paramedic",
		salary = 70,
		color = Color(200, 60, 60),
		spawn = "hospital",
		loadout = {},
	},
	firefighter = {
		id = "firefighter",
		name = "Firefighter",
		salary = 70,
		color = Color(200, 100, 40),
		spawn = "fire_ems",
		loadout = {},
	},
}

function Jobs.Get(id)
	return Jobs.List[id]
end

print("[MintyRP] Jobs stub loaded")
