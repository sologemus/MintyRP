--[[-------------------------------------------------------------------------
	MintyRP — Inventory client UI skeleton (Perpheads-style dual pane)
	Realm: CLIENT

	F2 opens inventory. Full drag/drop storage UI lands in a later pass;
	this provides category list + weight bar + use/drop actions.
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

	if IsValid(frame) then
		INV.RebuildList()
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

function INV.RebuildList()
	if not IsValid(frame) or not IsValid(frame.List) then return end

	frame.List:Clear()
	frame.WeightLabel:SetText(string.format("Weight: %.1f / %.1f", INV.ClientWeight, INV.ClientMaxWeight))

	-- Sort by category order then name (Perpheads-style)
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
		local line = frame.List:AddLine(label, (def and def.category) or "misc")
		line.ItemId = slot.item_id
		line.Amount = slot.amount
	end
end

function INV.Open()
	if IsValid(frame) then
		frame:Close()
		frame = nil
		return
	end

	frame = vgui.Create("DFrame")
	frame:SetSize(520, 420)
	frame:Center()
	frame:SetTitle("Inventory")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

	frame.WeightLabel = vgui.Create("DLabel", frame)
	frame.WeightLabel:SetPos(12, 30)
	frame.WeightLabel:SetSize(480, 20)
	frame.WeightLabel:SetText("Weight: 0 / 0")

	frame.List = vgui.Create("DListView", frame)
	frame.List:SetPos(12, 55)
	frame.List:SetSize(496, 300)
	frame.List:AddColumn("Item")
	frame.List:AddColumn("Category"):SetFixedWidth(100)
	frame.List:SetMultiSelect(false)

	local btnUse = vgui.Create("DButton", frame)
	btnUse:SetPos(12, 365)
	btnUse:SetSize(100, 28)
	btnUse:SetText("Use")
	btnUse.DoClick = function()
		local line = frame.List:GetSelectedLine()
		if not line then return end
		local row = frame.List:GetLine(line)
		if row and row.ItemId then
			sendAction(ACTION_USE, row.ItemId, 1)
		end
	end

	local btnDrop = vgui.Create("DButton", frame)
	btnDrop:SetPos(122, 365)
	btnDrop:SetSize(100, 28)
	btnDrop:SetText("Drop 1")
	btnDrop.DoClick = function()
		local line = frame.List:GetSelectedLine()
		if not line then return end
		local row = frame.List:GetLine(line)
		if row and row.ItemId then
			sendAction(ACTION_DROP, row.ItemId, 1)
		end
	end

	local hint = vgui.Create("DLabel", frame)
	hint:SetPos(240, 368)
	hint:SetSize(260, 24)
	hint:SetText("F2 toggle  ·  Storage UI coming soon")

	INV.RebuildList()
end

hook.Add("PlayerButtonDown", "MintyRP_InventoryKey", function(ply, button)
	if ply ~= LocalPlayer() then return end
	if button == KEY_F2 then
		INV.Open()
	end
end)

print("[MintyRP] Inventory client loaded")
