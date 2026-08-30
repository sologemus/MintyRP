--[[-------------------------------------------------------------------------
	MintyRP — Inventory + dual-pane storage UI (Perpheads-style)
	Realm: CLIENT

	F2 — personal inventory (single pane)
	E on storage — dual pane: You | Storage
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP.Inventory = MintyRP.Inventory or {}
MintyRP.Storage = MintyRP.Storage or {}

local INV = MintyRP.Inventory
local LocalPlayer = LocalPlayer
local IsValid = IsValid

INV.ClientItems = INV.ClientItems or {}
INV.ClientWeight = 0
INV.ClientMaxWeight = 50

MintyRP.Storage.Open = false
MintyRP.Storage.Id = nil
MintyRP.Storage.Name = "Storage"
MintyRP.Storage.Items = {}
MintyRP.Storage.Weight = 0
MintyRP.Storage.MaxWeight = 100

local frame
local colMint = Color(62, 207, 142)
local colBg = Color(14, 20, 18, 245)
local colPane = Color(22, 32, 28)
local colText = Color(230, 236, 232)
local colDim = Color(150, 165, 158)

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

	if IsValid(frame) and frame.Rebuild then
		frame.Rebuild()
	end
end)

net.Receive("MintyRP_StorageSync", function()
	MintyRP.Storage.Id = net.ReadString()
	MintyRP.Storage.Name = net.ReadString()
	MintyRP.Storage.MaxWeight = net.ReadFloat()
	MintyRP.Storage.Weight = net.ReadFloat()
	local count = net.ReadUInt(8)
	local items = {}
	for i = 1, count do
		local id = net.ReadString()
		local amount = net.ReadUInt(16)
		if id ~= "" and amount > 0 then
			items[#items + 1] = { item_id = id, amount = amount }
		end
	end
	MintyRP.Storage.Items = items
	if IsValid(frame) and frame.Rebuild then
		frame.Rebuild()
	end
end)

net.Receive("MintyRP_StorageOpen", function()
	MintyRP.Storage.Open = true
	MintyRP.Storage.Id = net.ReadString()
	MintyRP.Storage.Name = net.ReadString()
	MintyRP.Storage.MaxWeight = net.ReadFloat()
	INV.Open(true)
end)

local ACTION_DROP = 2
local ACTION_USE = 3

local function sendInvAction(action, itemId, amount)
	if type(itemId) ~= "string" or itemId == "" then return end
	amount = math.Clamp(math.floor(tonumber(amount) or 1), 1, 100)
	net.Start("MintyRP_InventoryAction")
		net.WriteUInt(action, 4)
		net.WriteString(itemId)
		net.WriteUInt(amount, 8)
	net.SendToServer()
end

local function sendStorage(dir, itemId, amount)
	if type(itemId) ~= "string" or itemId == "" then return end
	amount = math.Clamp(math.floor(tonumber(amount) or 1), 1, 100)
	net.Start("MintyRP_StorageAction")
		net.WriteUInt(dir, 2)
		net.WriteString(itemId)
		net.WriteUInt(amount, 8)
	net.SendToServer()
end

local function fillList(list, items)
	list:Clear()
	local sorted = table.Copy(items or {})
	table.sort(sorted, function(a, b)
		local da = INV.GetItem(a.item_id)
		local db = INV.GetItem(b.item_id)
		local ca = (da and INV.Categories[da.category] and INV.Categories[da.category].order) or 99
		local cb = (db and INV.Categories[db.category] and INV.Categories[db.category].order) or 99
		if ca ~= cb then return ca < cb end
		return ((da and da.name) or a.item_id) < ((db and db.name) or b.item_id)
	end)
	for i = 1, #sorted do
		local slot = sorted[i]
		local def = INV.GetItem(slot.item_id)
		local w = INV.GetStackWeight and INV.GetStackWeight(slot.item_id, slot.amount) or 0
		local label = string.format("%s  x%d", (def and def.name) or slot.item_id, slot.amount)
		local line = list:AddLine(label, string.format("%.1f", w), (def and def.category) or "misc")
		line.ItemId = slot.item_id
		line.Amount = slot.amount
	end
end

local function closeStorageSession()
	if MintyRP.Storage.Open then
		net.Start("MintyRP_StorageClose")
		net.SendToServer()
	end
	MintyRP.Storage.Open = false
	MintyRP.Storage.Id = nil
	MintyRP.Storage.Items = {}
end

function INV.Open(forceDual)
	local wantDual = forceDual or MintyRP.Storage.Open

	if IsValid(frame) then
		local wasDual = frame.IsDual
		frame:Close()
		frame = nil
		if not forceDual and wasDual then
			closeStorageSession()
			return
		end
		if not forceDual and not wantDual then
			closeStorageSession()
			return
		end
	end

	local dual = wantDual == true
	local w, h = dual and 820 or 560, dual and 460 or 440

	frame = vgui.Create("DFrame")
	frame:SetSize(w, h)
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.IsDual = dual
	frame.Paint = function(_, fw, fh)
		draw.RoundedBox(6, 0, 0, fw, fh, colBg)
		draw.SimpleText(dual and "Inventory  ·  Storage" or "Inventory", "DermaLarge", 16, 10, colMint)
	end
	frame.OnClose = function()
		if dual then closeStorageSession() end
		frame = nil
	end

	local sheet = vgui.Create("DPropertySheet", frame)
	sheet:Dock(FILL)
	sheet:DockMargin(8, 40, 8, 8)

	-- ── Items / dual pane ─────────────────────────────────
	local itemsPanel = vgui.Create("DPanel", sheet)
	itemsPanel.Paint = function() end

	local leftW = dual and 360 or 520

	local youLabel = vgui.Create("DLabel", itemsPanel)
	youLabel:SetPos(8, 4)
	youLabel:SetSize(leftW, 18)
	youLabel:SetTextColor(colDim)

	local youList = vgui.Create("DListView", itemsPanel)
	youList:SetPos(8, 24)
	youList:SetSize(leftW, dual and 300 or 280)
	youList:AddColumn("Item")
	youList:AddColumn("Wt"):SetFixedWidth(48)
	youList:AddColumn("Cat"):SetFixedWidth(72)
	youList:SetMultiSelect(false)

	local storList, storLabel
	if dual then
		storLabel = vgui.Create("DLabel", itemsPanel)
		storLabel:SetPos(400, 4)
		storLabel:SetSize(380, 18)
		storLabel:SetTextColor(colDim)

		storList = vgui.Create("DListView", itemsPanel)
		storList:SetPos(400, 24)
		storList:SetSize(380, 300)
		storList:AddColumn("Item")
		storList:AddColumn("Wt"):SetFixedWidth(48)
		storList:AddColumn("Cat"):SetFixedWidth(72)
		storList:SetMultiSelect(false)

		local dep = vgui.Create("DButton", itemsPanel)
		dep:SetPos(290, 332)
		dep:SetSize(90, 28)
		dep:SetText("Deposit →")
		dep.DoClick = function()
			local idx = youList:GetSelectedLine()
			if not idx then return end
			local row = youList:GetLine(idx)
			if row and row.ItemId then
				sendStorage(1, row.ItemId, 1)
			end
		end

		local wit = vgui.Create("DButton", itemsPanel)
		wit:SetPos(400, 332)
		wit:SetSize(90, 28)
		wit:SetText("← Withdraw")
		wit.DoClick = function()
			local idx = storList:GetSelectedLine()
			if not idx then return end
			local row = storList:GetLine(idx)
			if row and row.ItemId then
				sendStorage(2, row.ItemId, 1)
			end
		end

		local depAll = vgui.Create("DButton", itemsPanel)
		depAll:SetPos(290, 364)
		depAll:SetSize(90, 24)
		depAll:SetText("Dep. stack")
		depAll.DoClick = function()
			local idx = youList:GetSelectedLine()
			if not idx then return end
			local row = youList:GetLine(idx)
			if row and row.ItemId then
				sendStorage(1, row.ItemId, row.Amount or 1)
			end
		end

		local witAll = vgui.Create("DButton", itemsPanel)
		witAll:SetPos(400, 364)
		witAll:SetSize(90, 24)
		witAll:SetText("Wit. stack")
		witAll.DoClick = function()
			local idx = storList:GetSelectedLine()
			if not idx then return end
			local row = storList:GetLine(idx)
			if row and row.ItemId then
				sendStorage(2, row.ItemId, row.Amount or 1)
			end
		end
	end

	local btnUse = vgui.Create("DButton", itemsPanel)
	btnUse:SetPos(8, dual and 332 or 314)
	btnUse:SetSize(80, 28)
	btnUse:SetText("Use")
	btnUse.DoClick = function()
		local idx = youList:GetSelectedLine()
		if not idx then return end
		local row = youList:GetLine(idx)
		if row and row.ItemId then sendInvAction(ACTION_USE, row.ItemId, 1) end
	end

	local btnDrop = vgui.Create("DButton", itemsPanel)
	btnDrop:SetPos(96, dual and 332 or 314)
	btnDrop:SetSize(80, 28)
	btnDrop:SetText("Drop 1")
	btnDrop.DoClick = function()
		local idx = youList:GetSelectedLine()
		if not idx then return end
		local row = youList:GetLine(idx)
		if row and row.ItemId then sendInvAction(ACTION_DROP, row.ItemId, 1) end
	end

	if not dual then
		local hint = vgui.Create("DLabel", itemsPanel)
		hint:SetPos(190, 318)
		hint:SetSize(300, 24)
		hint:SetTextColor(colDim)
		hint:SetText("F2 toggle  ·  E on a crate for storage")
	end

	frame.Rebuild = function()
		if not IsValid(youList) then return end
		youLabel:SetText(string.format("You  ·  %.1f / %.1f kg", INV.ClientWeight, INV.ClientMaxWeight))
		fillList(youList, INV.ClientItems)
		if dual and IsValid(storList) then
			storLabel:SetText(string.format("%s  ·  %.1f / %.1f kg",
				MintyRP.Storage.Name or "Storage",
				MintyRP.Storage.Weight or 0,
				MintyRP.Storage.MaxWeight or 100
			))
			fillList(storList, MintyRP.Storage.Items)
		end
	end

	INV.RebuildList = frame.Rebuild
	sheet:AddSheet(dual and "Transfer" or "Items", itemsPanel, "icon16/box.png")

	-- Work tab (economy)
	if MintyRP.Economy and MintyRP.Economy.Jobs then
		local work = vgui.Create("DPanel", sheet)
		work.Paint = function() end
		local header = vgui.Create("DLabel", work)
		header:Dock(TOP)
		header:DockMargin(8, 8, 8, 4)
		header:SetTall(22)
		header:SetText("Clock in for a higher paycheck (every 5 min → bank)")

		local current = vgui.Create("DLabel", work)
		current:Dock(TOP)
		current:DockMargin(8, 0, 8, 8)
		current:SetTall(18)

		local list = vgui.Create("DListView", work)
		list:Dock(FILL)
		list:DockMargin(8, 0, 8, 8)
		list:AddColumn("Job")
		list:AddColumn("Pay"):SetFixedWidth(80)
		list:AddColumn("Description")

		local order = { "unemployed", "labourer", "courier", "mechanic" }
		local function refreshWork()
			list:Clear()
			local my = MintyRP.Economy.MyJob or "unemployed"
			local mine = MintyRP.Economy.Jobs[my]
			current:SetText("Current: " .. ((mine and mine.name) or my))
			for _, id in ipairs(order) do
				local j = MintyRP.Economy.Jobs[id]
				if j then
					local line = list:AddLine(j.name, "$" .. string.Comma(j.paycheck), j.desc or "")
					line.JobId = j.id
				end
			end
		end
		local btn = vgui.Create("DButton", work)
		btn:Dock(BOTTOM)
		btn:DockMargin(8, 0, 8, 8)
		btn:SetTall(30)
		btn:SetText("Clock In")
		btn.DoClick = function()
			local idx = list:GetSelectedLine()
			if not idx then return end
			local row = list:GetLine(idx)
			if row and row.JobId then
				MintyRP.Economy.RequestJob(row.JobId)
				timer.Simple(0.35, refreshWork)
			end
		end
		refreshWork()
		sheet:AddSheet("Work", work, "icon16/money.png")
	end

	frame.Rebuild()
end

print("[MintyRP] Inventory client loaded")
