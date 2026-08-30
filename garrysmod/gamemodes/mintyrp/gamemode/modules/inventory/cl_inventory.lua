--[[-------------------------------------------------------------------------
	MintyRP — Perpheads-leaning inventory / storage UI
	Realm: CLIENT

	Dark dual-pane, category rail, icon grid, weight bars.
	F2 = pocket. E on storage = dual pane transfer.
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
local C = function()
	return (MintyRP.UI and MintyRP.UI.Colors) or {
		bg = Color(18, 18, 20, 250),
		panel = Color(28, 28, 32),
		slot = Color(42, 42, 48),
		slotHov = Color(55, 55, 64),
		slotSel = Color(62, 90, 78),
		accent = Color(72, 180, 130),
		text = Color(235, 235, 238),
		dim = Color(140, 140, 150),
		barBg = Color(20, 20, 24),
		barFill = Color(72, 180, 130, 220),
		border = Color(55, 55, 62),
	}
end

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
	if IsValid(frame) and frame.Rebuild then frame.Rebuild() end
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
	if IsValid(frame) and frame.Rebuild then frame.Rebuild() end
end)

net.Receive("MintyRP_StorageOpen", function()
	MintyRP.Storage.Open = true
	MintyRP.Storage.Id = net.ReadString()
	MintyRP.Storage.Name = net.ReadString()
	MintyRP.Storage.MaxWeight = net.ReadFloat()
	INV.Open(true)
end)

local ACTION_DROP, ACTION_USE = 2, 3

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

local function closeStorageSession()
	if MintyRP.Storage.Open then
		net.Start("MintyRP_StorageClose")
		net.SendToServer()
	end
	MintyRP.Storage.Open = false
	MintyRP.Storage.Id = nil
	MintyRP.Storage.Items = {}
end

local function sortedItems(items, catFilter)
	local out = {}
	for i = 1, #(items or {}) do
		local slot = items[i]
		local def = INV.GetItem(slot.item_id)
		local cat = (def and def.category) or "misc"
		if not catFilter or catFilter == "all" or cat == catFilter then
			out[#out + 1] = slot
		end
	end
	table.sort(out, function(a, b)
		local da, db = INV.GetItem(a.item_id), INV.GetItem(b.item_id)
		local ca = (da and INV.Categories[da.category] and INV.Categories[da.category].order) or 99
		local cb = (db and INV.Categories[db.category] and INV.Categories[db.category].order) or 99
		if ca ~= cb then return ca < cb end
		return ((da and da.name) or a.item_id) < ((db and db.name) or b.item_id)
	end)
	return out
end

local function makeWeightBar(parent, getVals)
	local bar = vgui.Create("DPanel", parent)
	bar:SetTall(18)
	bar.Paint = function(_, w, h)
		local col = C()
		local cur, max = getVals()
		max = math.max(max or 1, 0.01)
		local frac = math.Clamp((cur or 0) / max, 0, 1)
		draw.RoundedBox(3, 0, 0, w, h, col.barBg)
		draw.RoundedBox(3, 0, 0, w * frac, h, col.barFill)
		draw.SimpleText(
			string.format("%.1f / %.1f kg", cur or 0, max),
			"DermaDefault",
			w * 0.5, h * 0.5,
			col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)
	end
	return bar
end

local function makeItemGrid(parent, opts)
	local col = C()
	local scroll = vgui.Create("DScrollPanel", parent)
	local grid = vgui.Create("DIconLayout", scroll)
	grid:Dock(FILL)
	grid:SetSpaceX(6)
	grid:SetSpaceY(6)
	grid:DockMargin(4, 4, 4, 4)

	local selected = { id = nil, amount = 1 }

	function scroll:Rebuild(items)
		grid:Clear()
		selected.id = nil
		local list = sortedItems(items, opts.getCategory and opts.getCategory())
		for i = 1, #list do
			local slot = list[i]
			local def = INV.GetItem(slot.item_id)
			local tile = grid:Add("DButton")
			tile:SetSize(74, 86)
			tile:SetText("")
			tile.ItemId = slot.item_id
			tile.Amount = slot.amount
			tile.Paint = function(self, w, h)
				local c = C()
				local bg = (selected.id == self.ItemId) and c.slotSel or (self:IsHovered() and c.slotHov or c.slot)
				draw.RoundedBox(4, 0, 0, w, h, bg)
				surface.SetDrawColor(c.border)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText(
					"x" .. tostring(self.Amount),
					"DermaDefaultBold",
					w - 6, 4,
					c.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
				)
				local name = (def and def.name) or self.ItemId
				if #name > 10 then name = string.sub(name, 1, 9) .. "…" end
				draw.SimpleText(name, "DermaDefault", w * 0.5, h - 12, c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			local icon = vgui.Create("SpawnIcon", tile)
			icon:SetPos(11, 14)
			icon:SetSize(52, 52)
			icon:SetModel((def and def.model) or "models/props_junk/cardboard_box004a.mdl")
			icon:SetTooltip((def and def.name or slot.item_id) .. "\n" .. ((def and def.desc) or ""))
			icon.DoClick = function()
				selected.id = slot.item_id
				selected.amount = slot.amount
				if opts.onSelect then opts.onSelect(slot) end
			end
			icon.DoDoubleClick = function()
				selected.id = slot.item_id
				selected.amount = slot.amount
				if opts.onDouble then opts.onDouble(slot) end
			end
			tile.DoClick = icon.DoClick
			tile.DoDoubleClick = icon.DoDoubleClick
		end
		grid:InvalidateLayout(true)
	end

	scroll.GetSelected = function()
		return selected.id, selected.amount
	end

	return scroll
end

local function makeCategoryRail(parent, onChange)
	local col = C()
	local rail = vgui.Create("DPanel", parent)
	rail:SetWide(110)
	rail.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, C().panel)
	end

	local cats = { { id = "all", name = "All" } }
	local order = { "weapons", "ammo", "food", "medical", "materials", "utilities", "misc" }
	for _, id in ipairs(order) do
		local c = INV.Categories and INV.Categories[id]
		if c then cats[#cats + 1] = c end
	end

	local active = "all"
	local y = 6
	for i = 1, #cats do
		local cat = cats[i]
		local btn = vgui.Create("DButton", rail)
		btn:SetPos(6, y)
		btn:SetSize(98, 26)
		btn:SetText("")
		btn.Paint = function(self, w, h)
			local c = C()
			local on = active == cat.id
			draw.RoundedBox(3, 0, 0, w, h, on and c.slotSel or (self:IsHovered() and c.slotHov or c.slot))
			draw.SimpleText(cat.name, "DermaDefault", w * 0.5, h * 0.5, c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		btn.DoClick = function()
			active = cat.id
			if onChange then onChange(active) end
		end
		y = y + 30
	end

	rail.GetActive = function() return active end
	return rail
end

function INV.Open(forceDual)
	local wantDual = forceDual or MintyRP.Storage.Open

	if IsValid(frame) then
		local wasDual = frame.IsDual
		frame:Close()
		frame = nil
		if not forceDual then
			closeStorageSession()
			if not wantDual or wasDual then return end
		end
	end

	local dual = wantDual == true
	local sw, sh = ScrW(), ScrH()
	local w = dual and math.min(980, sw * 0.82) or math.min(620, sw * 0.55)
	local h = math.min(560, sh * 0.72)

	frame = vgui.Create("DFrame")
	frame:SetSize(w, h)
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:ShowCloseButton(false)
	frame:SetDraggable(true)
	frame.IsDual = dual
	frame.Paint = function(_, fw, fh)
		local c = C()
		draw.RoundedBox(6, 0, 0, fw, fh, c.bg)
		surface.SetDrawColor(c.border)
		surface.DrawOutlinedRect(0, 0, fw, fh, 1)
		draw.SimpleText(dual and "INVENTORY  /  STORAGE" or "INVENTORY", "DermaLarge", 18, 14, c.accent)
		draw.SimpleText("F2 close", "DermaDefault", fw - 18, 20, c.dim, TEXT_ALIGN_RIGHT)
	end
	frame.OnClose = function()
		if dual then closeStorageSession() end
		frame = nil
	end

	local closeBtn = vgui.Create("DButton", frame)
	closeBtn:SetPos(w - 36, 10)
	closeBtn:SetSize(24, 24)
	closeBtn:SetText("✕")
	closeBtn:SetTextColor(C().dim)
	closeBtn.Paint = function() end
	closeBtn.DoClick = function() frame:Close() end

	local body = vgui.Create("DPanel", frame)
	body:Dock(FILL)
	body:DockMargin(12, 44, 12, 12)
	body.Paint = function() end

	local catFilter = "all"
	local leftPane = vgui.Create("DPanel", body)
	leftPane.Paint = function(_, pw, ph)
		draw.RoundedBox(4, 0, 0, pw, ph, C().panel)
	end

	local rightPane
	if dual then
		leftPane:Dock(LEFT)
		leftPane:SetWide(w * 0.42)
		leftPane:DockMargin(0, 0, 8, 0)

		rightPane = vgui.Create("DPanel", body)
		rightPane:Dock(FILL)
		rightPane.Paint = function(_, pw, ph)
			draw.RoundedBox(4, 0, 0, pw, ph, C().panel)
		end
	else
		leftPane:Dock(FILL)
	end

	-- Left: categories + grid
	local rail = makeCategoryRail(leftPane, function(id)
		catFilter = id
		if frame.Rebuild then frame.Rebuild() end
	end)
	rail:Dock(LEFT)
	rail:DockMargin(6, 36, 0, 40)

	local leftHead = vgui.Create("DLabel", leftPane)
	leftHead:SetPos(122, 8)
	leftHead:SetSize(280, 20)
	leftHead:SetText("YOU")
	leftHead:SetTextColor(C().accent)
	leftHead:SetFont("DermaDefaultBold")

	local youGrid
	youGrid = makeItemGrid(leftPane, {
		getCategory = function() return catFilter end,
		onSelect = function() end,
		onDouble = function(slot)
			if dual then
				sendStorage(1, slot.item_id, 1)
			else
				sendInvAction(ACTION_USE, slot.item_id, 1)
			end
		end,
	})
	youGrid:Dock(FILL)
	youGrid:DockMargin(4, 32, 6, 44)

	local youBar = makeWeightBar(leftPane, function()
		return INV.ClientWeight, INV.ClientMaxWeight
	end)
	youBar:Dock(BOTTOM)
	youBar:DockMargin(122, 0, 8, 8)

	local leftActions = vgui.Create("DPanel", leftPane)
	leftActions:Dock(BOTTOM)
	leftActions:SetTall(30)
	leftActions:DockMargin(122, 0, 8, 4)
	leftActions.Paint = function() end

	local useBtn = vgui.Create("DButton", leftActions)
	useBtn:Dock(LEFT)
	useBtn:SetWide(70)
	useBtn:SetText("Use")
	useBtn.DoClick = function()
		local id = youGrid:GetSelected()
		if id then sendInvAction(ACTION_USE, id, 1) end
	end

	local dropBtn = vgui.Create("DButton", leftActions)
	dropBtn:Dock(LEFT)
	dropBtn:SetWide(70)
	dropBtn:DockMargin(4, 0, 0, 0)
	dropBtn:SetText("Drop")
	dropBtn.DoClick = function()
		local id = youGrid:GetSelected()
		if id then sendInvAction(ACTION_DROP, id, 1) end
	end

	if dual then
		local depBtn = vgui.Create("DButton", leftActions)
		depBtn:Dock(LEFT)
		depBtn:SetWide(90)
		depBtn:DockMargin(4, 0, 0, 0)
		depBtn:SetText("Deposit →")
		depBtn.DoClick = function()
			local id, amt = youGrid:GetSelected()
			if id then sendStorage(1, id, 1) end
		end
		local depStack = vgui.Create("DButton", leftActions)
		depStack:Dock(LEFT)
		depStack:SetWide(80)
		depStack:DockMargin(4, 0, 0, 0)
		depStack:SetText("Dep. all")
		depStack.DoClick = function()
			local id, amt = youGrid:GetSelected()
			if id then sendStorage(1, id, amt or 1) end
		end

		local rightHead = vgui.Create("DLabel", rightPane)
		rightHead:Dock(TOP)
		rightHead:SetTall(24)
		rightHead:DockMargin(10, 8, 10, 0)
		rightHead:SetTextColor(C().accent)
		rightHead:SetFont("DermaDefaultBold")
		rightHead:SetText(string.upper(MintyRP.Storage.Name or "STORAGE"))

		local storGrid = makeItemGrid(rightPane, {
			getCategory = function() return "all" end,
			onDouble = function(slot)
				sendStorage(2, slot.item_id, 1)
			end,
		})
		storGrid:Dock(FILL)
		storGrid:DockMargin(6, 4, 6, 4)

		local storBar = makeWeightBar(rightPane, function()
			return MintyRP.Storage.Weight, MintyRP.Storage.MaxWeight
		end)
		storBar:Dock(BOTTOM)
		storBar:DockMargin(10, 0, 10, 8)

		local rightActions = vgui.Create("DPanel", rightPane)
		rightActions:Dock(BOTTOM)
		rightActions:SetTall(30)
		rightActions:DockMargin(10, 0, 10, 4)
		rightActions.Paint = function() end

		local witBtn = vgui.Create("DButton", rightActions)
		witBtn:Dock(LEFT)
		witBtn:SetWide(100)
		witBtn:SetText("← Withdraw")
		witBtn.DoClick = function()
			local id = storGrid:GetSelected()
			if id then sendStorage(2, id, 1) end
		end
		local witStack = vgui.Create("DButton", rightActions)
		witStack:Dock(LEFT)
		witStack:SetWide(90)
		witStack:DockMargin(4, 0, 0, 0)
		witStack:SetText("Wit. all")
		witStack.DoClick = function()
			local id, amt = storGrid:GetSelected()
			if id then sendStorage(2, id, amt or 1) end
		end

		frame.Rebuild = function()
			rightHead:SetText(string.upper(MintyRP.Storage.Name or "STORAGE"))
			youGrid:Rebuild(INV.ClientItems)
			storGrid:Rebuild(MintyRP.Storage.Items)
		end
	else
		-- Work strip when not in storage
		local workHint = vgui.Create("DButton", leftActions)
		workHint:Dock(RIGHT)
		workHint:SetWide(100)
		workHint:SetText("Work jobs")
		workHint.DoClick = function()
			if MintyRP.Economy and MintyRP.Economy.RequestJob then
				-- Quick open: cycle isn't ideal; notify to use F2 work — keep simple paycheck open via chat
				local jobs = MintyRP.Economy.Jobs or {}
				local menu = DermaMenu()
				for _, id in ipairs({ "unemployed", "labourer", "courier", "mechanic" }) do
					local j = jobs[id]
					if j then
						menu:AddOption(j.name .. " ($" .. j.paycheck .. ")", function()
							MintyRP.Economy.RequestJob(j.id)
						end)
					end
				end
				menu:Open()
			end
		end

		frame.Rebuild = function()
			youGrid:Rebuild(INV.ClientItems)
		end
	end

	INV.RebuildList = frame.Rebuild
	frame.Rebuild()
end

print("[MintyRP] Inventory client loaded")
