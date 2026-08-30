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
		body = "Bank tellers are at the bank (green beacon).\nGas stations have ATMs (blue beacon) — same deposit/withdraw.\n\nPress E on either. Host places them:\nmintyrp_setteller bank   ·   mintyrp_setatm gas1",
	},
	{
		id = "keys",
		title = "Keys & doors",
		body = "Walk up to any housing door — HUD shows For sale + price.\nPress N to buy that door (cash or bank).\nEach door is its own property. Keys lock/unlock what you own.",
	},
	{
		id = "menus",
		title = "Menus",
		body = "F2 — Inventory (Use / Drop / Work jobs)\nE on a crate — dual-pane storage transfer\nF3 — Properties\nN — Buy the door you're looking at",
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
