--[[-------------------------------------------------------------------------
	MintyRP — Inventory client UI (items + Work tab)
	Realm: CLIENT
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP.Inventory = MintyRP.Inventory or {}

local INV = MintyRP.Inventory
local LocalPlayer = LocalPlayer
local IsValid = IsValid
local math_Round = math.Round

INV.ClientItems = INV.ClientItems or {}
INV.ClientWeight = 0
INV.ClientMaxWeight = 50

local frame

net.Receive("MintyRP_InventorySync", function()
	local count = net.ReadUInt(8)
	local items = {}

	for i = 1, count do
		local id = net.ReadString()
		local amount = net.ReadUInt(16)
		if id ~= "" and amount > 0 then
			items[#items + 1] = { item_id = id, amount = amount }
		end
	end

	INV.ClientItems = items
	INV.ClientWeight = net.ReadFloat()
	INV.ClientMaxWeight = net.ReadFloat()

	local ply = LocalPlayer()
	if IsValid(ply) then
		ply.MintyRP = ply.MintyRP or {}
		ply.MintyRP.inventory = items
	end

	if IsValid(frame) and frame.RebuildItems then
		frame.RebuildItems()
	end
end)

local ACTION_DROP = 2
local ACTION_USE = 3

local function sendAction(action, itemId, amount)
	if type(itemId) ~= "string" or itemId == "" then return end
	amount = math.Clamp(math.floor(tonumber(amount) or 1), 1, 100)

	net.Start("MintyRP_InventoryAction")
		net.WriteUInt(action, 4)
		net.WriteString(itemId)
		net.WriteUInt(amount, 8)
	net.SendToServer()
end

local function BuildWorkPanel(parent)
	local panel = vgui.Create("DPanel", parent)
	panel:Dock(FILL)
	panel.Paint = function() end

	local header = vgui.Create("DLabel", panel)
	header:Dock(TOP)
	header:DockMargin(8, 8, 8, 4)
	header:SetTall(24)
	header:SetText("Clock in for a higher paycheck (paid to bank every 5 min)")

	local current = vgui.Create("DLabel", panel)
	current:Dock(TOP)
	current:DockMargin(8, 0, 8, 8)
	current:SetTall(20)
	current:SetText("Current job: …")

	local list = vgui.Create("DListView", panel)
	list:Dock(FILL)
	list:DockMargin(8, 0, 8, 8)
	list:AddColumn("Job")
	list:AddColumn("Pay / check"):SetFixedWidth(100)
	list:AddColumn("Description")
	list:SetMultiSelect(false)

	local order = { "unemployed", "labourer", "courier", "mechanic" }
	local jobs = (MintyRP.Economy and MintyRP.Economy.Jobs) or {}

	local function refresh()
		list:Clear()
		local my = (MintyRP.Economy and MintyRP.Economy.MyJob) or "unemployed"
		local mine = jobs[my]
		current:SetText("Current job: " .. ((mine and mine.name) or my))

		for i = 1, #order do
			local j = jobs[order[i]]
			if j then
				local line = list:AddLine(j.name, "$" .. string.Comma(j.paycheck), j.desc or "")
				line.JobId = j.id
			end
		end
	end

	local btn = vgui.Create("DButton", panel)
	btn:Dock(BOTTOM)
	btn:DockMargin(8, 0, 8, 8)
	btn:SetTall(32)
	btn:SetText("Clock In")
	btn.DoClick = function()
		local idx = list:GetSelectedLine()
		if not idx then return end
		local row = list:GetLine(idx)
		if row and row.JobId and MintyRP.Economy and MintyRP.Economy.RequestJob then
			MintyRP.Economy.RequestJob(row.JobId)
			timer.Simple(0.4, refresh)
		end
	end

	panel.RefreshWork = refresh
	refresh()
	return panel
end

function INV.Open()
	if IsValid(frame) then
		frame:Close()
		frame = nil
		return
	end

	frame = vgui.Create("DFrame")
	frame:SetSize(560, 440)
	frame:Center()
	frame:SetTitle("Inventory")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

	local sheet = vgui.Create("DPropertySheet", frame)
	sheet:Dock(FILL)
	sheet:DockMargin(4, 4, 4, 4)

	-- Items tab
	local itemsPanel = vgui.Create("DPanel", sheet)
	itemsPanel.Paint = function() end

	local weightLabel = vgui.Create("DLabel", itemsPanel)
	weightLabel:SetPos(12, 8)
	weightLabel:SetSize(480, 20)
	weightLabel:SetText("Weight: 0 / 0")

	local list = vgui.Create("DListView", itemsPanel)
	list:SetPos(12, 32)
	list:SetSize(516, 300)
	list:AddColumn("Item")
	list:AddColumn("Category"):SetFixedWidth(100)
	list:SetMultiSelect(false)

	local btnUse = vgui.Create("DButton", itemsPanel)
	btnUse:SetPos(12, 342)
	btnUse:SetSize(100, 28)
	btnUse:SetText("Use")
	btnUse.DoClick = function()
		local line = list:GetSelectedLine()
		if not line then return end
		local row = list:GetLine(line)
		if row and row.ItemId then
			sendAction(ACTION_USE, row.ItemId, 1)
		end
	end

	local btnDrop = vgui.Create("DButton", itemsPanel)
	btnDrop:SetPos(122, 342)
	btnDrop:SetSize(100, 28)
	btnDrop:SetText("Drop 1")
	btnDrop.DoClick = function()
		local line = list:GetSelectedLine()
		if not line then return end
		local row = list:GetLine(line)
		if row and row.ItemId then
			sendAction(ACTION_DROP, row.ItemId, 1)
		end
	end

	local hint = vgui.Create("DLabel", itemsPanel)
	hint:SetPos(240, 346)
	hint:SetSize(280, 24)
	hint:SetText("F2 toggle  ·  Work tab for paychecks")

	frame.List = list
	frame.WeightLabel = weightLabel

	frame.RebuildItems = function()
		if not IsValid(list) then return end
		list:Clear()
		weightLabel:SetText(string.format("Weight: %.1f / %.1f", INV.ClientWeight, INV.ClientMaxWeight))

		local sorted = table.Copy(INV.ClientItems)
		table.sort(sorted, function(a, b)
			local da = INV.GetItem(a.item_id)
			local db = INV.GetItem(b.item_id)
			local ca = (da and INV.Categories[da.category] and INV.Categories[da.category].order) or 99
			local cb = (db and INV.Categories[db.category] and INV.Categories[db.category].order) or 99
			if ca ~= cb then return ca < cb end
			local na = (da and da.name) or a.item_id
			local nb = (db and db.name) or b.item_id
			return na < nb
		end)

		for i = 1, #sorted do
			local slot = sorted[i]
			local def = INV.GetItem(slot.item_id)
			local label = string.format("%s  x%d", (def and def.name) or slot.item_id, slot.amount)
			local line = list:AddLine(label, (def and def.category) or "misc")
			line.ItemId = slot.item_id
			line.Amount = slot.amount
		end
	end

	INV.RebuildList = frame.RebuildItems

	sheet:AddSheet("Items", itemsPanel, "icon16/box.png")

	local workPanel = BuildWorkPanel(sheet)
	sheet:AddSheet("Work", workPanel, "icon16/money.png")

	frame.RebuildItems()
end

print("[MintyRP] Inventory client loaded")
