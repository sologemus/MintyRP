--[[-------------------------------------------------------------------------
	MintyRP — Economy / paychecks (shared)
	Realm: SHARED
---------------------------------------------------------------------------]]

MintyRP = MintyRP or {}
MintyRP.Economy = MintyRP.Economy or {}

MintyRP.Economy.PaycheckInterval = 300 -- seconds
MintyRP.Economy.BasePaycheck = 150

MintyRP.Economy.Jobs = {
	unemployed = {
		id = "unemployed",
		name = "Unemployed",
		paycheck = 150,
		desc = "Basic citizen stipend while you figure things out.",
	},
	labourer = {
		id = "labourer",
		name = "Labourer",
		paycheck = 350,
		desc = "General site work around Rockford. Steady pay.",
	},
	courier = {
		id = "courier",
		name = "Courier",
		paycheck = 400,
		desc = "Move packages across town. Slightly better rate.",
	},
	mechanic = {
		id = "mechanic",
		name = "Mechanic",
		paycheck = 500,
		desc = "Garage shifts. Best civilian paycheck for now.",
	},
}

print("[MintyRP] Economy shared loaded")
