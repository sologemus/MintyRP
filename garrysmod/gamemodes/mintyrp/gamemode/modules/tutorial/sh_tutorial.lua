--[[-------------------------------------------------------------------------
	MintyRP — Starter tutorial (shared)
	Realm: SHARED
---------------------------------------------------------------------------]]

MintyRP = MintyRP or {}
MintyRP.Tutorial = MintyRP.Tutorial or {}

MintyRP.Tutorial.StarterCash = 20000

MintyRP.Tutorial.Steps = {
	{
		id = "welcome",
		title = "Welcome to Rockford",
		body = "You're new in town. The city runs on cash, property, and work.\n\nFinish this short orientation and you'll get $20,000 starter capital in your bank.",
	},
	{
		id = "bank",
		title = "Bank tellers",
		body = "Bank tellers are placed by the host (green beacon).\n\nPress E to deposit or withdraw.\nIf none exist yet, host: stand at the desk → mintyrp_setteller bank",
	},
	{
		id = "keys",
		title = "Keys & doors",
		body = "Walk up to any residential / shop door — you should see For sale + price.\n\nPress N to buy (uses cash first, then bank).\nKeys: left-click lock / right-click unlock owned doors.",
	},
	{
		id = "menus",
		title = "Menus",
		body = "F2 — Inventory & Work\nF3 — Properties\nN — Buy the door you're looking at\n\nConsole: mintyrp_inventory / mintyrp_properties / mintyrp_buydoor",
	},
	{
		id = "work",
		title = "Making money",
		body = "You earn a paycheck every 5 minutes while online.\n\nOpen F2 → Work tab and clock in as Labourer, Courier, or Mechanic for higher pay.\n\nCity & franchise buildings (PD, hospital, bank, gas…) are not buyable.",
	},
	{
		id = "done",
		title = "You're set",
		body = "Click Claim to deposit $20,000 to your bank.\n\nUse a teller to withdraw cash, buy a place if you want, and clock in for work.\n\nWelcome to MintyRP.",
	},
}

print("[MintyRP] Tutorial shared loaded")
