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
		body = "Look for a green beacon — that's a bank teller.\n\nThere's one at civilian spawn (City Spawn Kiosk) plus desks at the bank and gas stations.\n\nPress E to deposit or withdraw. Console: mintyrp_tpteller",
	},
	{
		id = "keys",
		title = "Keys & doors",
		body = "You spawn with fists, a physgun, and keys.\n\nKeys: left-click lock / right-click unlock owned doors.\nWalk up to a for-sale door and press N to buy the property.",
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
