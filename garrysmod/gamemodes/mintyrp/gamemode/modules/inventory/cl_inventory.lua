--[[-------------------------------------------------------------------------
	MintyRP — PERP-inspired inventory UI
	Realm: CLIENT

	Layout based on PERP (MIT © Michael Burgess / SkyWalker fork):
	  description + equip (top) · slot grid (bottom)
	  drag-drop between slots · LMB use on short click · RMB drop
	Storage open → dual pane (player | vault) like PERP bank.
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP.Inventory = MintyRP.Inventory or {}
MintyRP.Storage = MintyRP.Storage or {}

local INV = MintyRP.Inventory
local LocalPlayer = LocalPlayer
local IsValid = IsValid

-- Client slot map: [slotNum] = { item_id, amount }
INV.ClientSlots = INV.ClientSlots or {}
INV.ClientWeight = 0
INV.ClientMaxWeight = 100
INV.ClientItems = INV.ClientItems or {} -- legacy list view compatibility

MintyRP.Storage.Open = false
MintyRP.Storage.Id = nil
MintyRP.Storage.Name = "Storage"
MintyRP.Storage.Slots = {}
MintyRP.Storage.Items = {}
MintyRP.Storage.Weight = 0
MintyRP.Storage.MaxWeight = 100

local frame
local dragging -- { slot, item_id, amount, panel }

local function colors()
	return {
		bg = Color(25, 25, 28, 245),
		slot = Color(40, 40, 45, 220),
		slotEmpty = Color(55, 55, 60, 180),
		slotGlow = Color(80, 140, 110, 230),
		text = Color(240, 240, 245),
		dim = Color(150, 150, 160),
		accent = Color(72, 180, 130),
		border = Color(0, 0, 0, 220),
	}
end

net.Receive("MintyRP_InventorySync", function()
	local count = net.ReadUInt(8)
	local slots = {}
	local list = {}
	for i = 1, count do
		local slot = net.ReadUInt(8)
		local id = net.ReadString()
		local amount = net.ReadUInt(16)
		if id ~= "" and amount > 0 then
			slots[slot] = { item_id = id, amount = amount, slot = slot }
			list[#list + 1] = { item_id = id, amount = amount, slot = slot }
		end
	end
	INV.ClientSlots = slots
	INV.ClientItems = list
	INV.ClientWeight = net.ReadFloat()
	INV.ClientMaxWeight = net.ReadFloat()
	if IsValid(frame) and frame.RefreshSlots then frame.RefreshSlots() end
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
	if IsValid(frame) and frame.RefreshSlots then frame.RefreshSlots() end
end)

net.Receive("MintyRP_StorageOpen", function()
	MintyRP.Storage.Open = true
	MintyRP.Storage.Id = net.ReadString()
	MintyRP.Storage.Name = net.ReadString()
	MintyRP.Storage.MaxWeight = net.ReadFloat()
	INV.Open(true)
end)

local function closeStorageSession()
	if MintyRP.Storage.Open then
		net.Start("MintyRP_StorageClose")
		net.SendToServer()
	end
	MintyRP.Storage.Open = false
	MintyRP.Storage.Id = nil
	MintyRP.Storage.Items = {}
end

local function sendAction(action, itemId, amount, slot)
	net.Start("MintyRP_InventoryAction")
		net.WriteUInt(action, 4)
		net.WriteString(itemId)
		net.WriteUInt(math.Clamp(amount or 1, 1, 100), 8)
		net.WriteUInt(math.Clamp(slot or 0, 0, 255), 8)
	net.SendToServer()
end

local function sendSwap(a, b)
	net.Start("MintyRP_InventorySwap")
		net.WriteUInt(a, 8)
		net.WriteUInt(b, 8)
	net.SendToServer()
end

local function sendStorage(dir, itemId, amount)
	net.Start("MintyRP_StorageAction")
		net.WriteUInt(dir, 2)
		net.WriteString(itemId)
		net.WriteUInt(math.Clamp(amount or 1, 1, 100), 8)
	net.SendToServer()
end

-- ─── Slot panel ───────────────────────────────────────────

local function createSlot(parent, slotNum, opts)
	opts = opts or {}
	local c = colors()
	local pnl = vgui.Create("DPanel", parent)
	pnl.SlotNum = slotNum
	pnl.IsEquip = opts.equip == true
	pnl.IsStorage = opts.storage == true
	pnl.SuperGlow = false
	pnl.ourAlpha = 210

	pnl.Paint = function(self, w, h)
		local col = c.slotEmpty
		if self.SuperGlow then
			local pulse = 180 + math.sin(CurTime() * 5) * 40
			col = Color(70, 130, 100, pulse)
		elseif self.Hovered or self.cursorIn then
			col = c.slot
		end
		surface.SetDrawColor(c.border)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		surface.SetDrawColor(col)
		surface.DrawRect(1, 1, w - 2, h - 2)

		local data = self:GetData()
		if data then
			draw.SimpleText(tostring(data.amount), "DermaDefaultBold", 4, 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end

	pnl.GetData = function(self)
		if self.IsStorage then
			-- storage uses linear index in opts.storageIndex
			local items = MintyRP.Storage.Items or {}
			return items[self.StorageIndex]
		end
		return INV.ClientSlots[self.SlotNum]
	end

	pnl.Think = function(self)
		local mx, my = self:CursorPos()
		local inside = mx > 0 and my > 0 and mx < self:GetWide() and my < self:GetTall()
		if inside and not self.cursorIn then
			self.cursorIn = true
			local data = self:GetData()
			if IsValid(frame) and frame.SetDescription then
				frame.SetDescription(data and INV.GetItem(data.item_id) or nil)
			end
		elseif not inside and self.cursorIn then
			self.cursorIn = false
		end
	end

	-- Model preview
	local model = vgui.Create("DModelPanel", pnl)
	model:Dock(FILL)
	model:DockMargin(3, 14, 3, 3)
	function model:LayoutEntity() end
	model.OnMousePressed = function(_, mc) pnl:OnMousePressed(mc) end
	model.OnMouseReleased = function(_, mc) pnl:OnMouseReleased(mc) end

	pnl.Refresh = function(self)
		local data = self:GetData()
		if data then
			local def = INV.GetItem(data.item_id)
			model:SetVisible(true)
			model:SetModel((def and (def.inventoryModel or def.model)) or "models/props_junk/cardboard_box004a.mdl")
			if def then
				model:SetCamPos(def.modelCamPos or Vector(20, 20, 15))
				model:SetLookAt(def.modelLookAt or Vector(0, 0, 0))
				model:SetFOV(def.modelFOV or 45)
			end
			if IsValid(model.Entity) then
				local seq = model.Entity:LookupSequence("idle")
				if seq and seq > 0 then model.Entity:ResetSequence(seq) end
			end
		else
			model:SetVisible(false)
		end
	end

	pnl.downTime = 0
	pnl.OnMousePressed = function(self, mc)
		local data = self:GetData()
		if not data then return end

		if mc == MOUSE_RIGHT then
			if self.IsStorage then
				sendStorage(2, data.item_id, 1)
			else
				sendAction(2, data.item_id, 1, self.SlotNum) -- drop
			end
			surface.PlaySound("UI/buttonclick.wav")
			return
		end

		if mc == MOUSE_LEFT then
			surface.PlaySound("UI/buttonclick.wav")
			self.downTime = CurTime()
			self.dragging = true
			dragging = {
				fromSlot = self.SlotNum,
				fromStorage = self.IsStorage,
				storageIndex = self.StorageIndex,
				item_id = data.item_id,
				amount = data.amount,
				origin = self,
			}
			self.SuperGlow = true
		end
	end

	pnl.OnMouseReleased = function(self, mc)
		if mc ~= MOUSE_LEFT then return end
		local wasDrag = self.dragging
		self.dragging = false
		self.SuperGlow = false

		if not wasDrag or not dragging then return end

		local held = CurTime() - (self.downTime or 0)
		local target
		if IsValid(frame) and frame.GetHoveredSlot then
			target = frame.GetHoveredSlot()
		end

		if IsValid(target) and target ~= self then
			if dragging.fromStorage and not target.IsStorage then
				sendStorage(2, dragging.item_id, 1)
			elseif not dragging.fromStorage and target.IsStorage then
				sendStorage(1, dragging.item_id, 1)
			elseif not dragging.fromStorage and not target.IsStorage then
				sendSwap(dragging.fromSlot, target.SlotNum)
			end
		elseif held < 0.22 and not dragging.fromStorage then
			-- short click = use
			local def = INV.GetItem(dragging.item_id)
			if def and def.usable then
				sendAction(3, dragging.item_id, 1, dragging.fromSlot)
			end
		end

		dragging = nil
	end

	pnl.Refresh()
	return pnl
end

-- ─── Main frame ───────────────────────────────────────────

function INV.Open(forceDual)
	local wantDual = forceDual or MintyRP.Storage.Open

	if IsValid(frame) then
		frame:Close()
		frame = nil
		if not forceDual then
			closeStorageSession()
			return
		end
	end

	local dual = wantDual == true
	local W = INV.GridWidth()
	local H = INV.GridHeight()
	local c = colors()

	local maxW = dual and ScrW() * 0.92 or ScrW() * 0.62
	local maxH = (ScrW() * (10 / 16)) * (dual and 0.72 or 0.78)

	frame = vgui.Create("DFrame")
	frame:SetSize(maxW, maxH)
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:ShowCloseButton(false)
	frame:SetDraggable(true)
	frame.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, c.bg)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
		draw.SimpleText("INVENTORY", "DermaLarge", 12, 8, c.accent)
		if dual then
			draw.SimpleText(string.upper(MintyRP.Storage.Name or "STORAGE"), "DermaLarge", w * 0.55, 8, c.accent)
		end
		draw.SimpleText(
			string.format("%.1f / %.1f kg", INV.ClientWeight, INV.ClientMaxWeight),
			"DermaDefault", w - 12, 14, c.dim, TEXT_ALIGN_RIGHT
		)
	end
	frame.OnClose = function()
		if dual then closeStorageSession() end
		dragging = nil
		frame = nil
	end

	local closeBtn = vgui.Create("DButton", frame)
	closeBtn:SetSize(28, 28)
	closeBtn:SetPos(maxW - 34, 6)
	closeBtn:SetText("X")
	closeBtn.DoClick = function() frame:Close() end

	local buffer = 5
	local bagAreaW = dual and (maxW * 0.48) or (maxW - 20)
	local availableWidth = bagAreaW - ((W + 1) * buffer)
	local block = availableWidth / W

	local slots = {}
	frame.Slots = slots

	-- Description pane (PERP left/top)
	local desc = vgui.Create("DPanel", frame)
	local descW = bagAreaW * 0.48
	local bagTop = maxH - buffer - H * (buffer + block)
	desc:SetPos(buffer + 2, 36)
	desc:SetSize(descW, bagTop - 48)
	desc.Paint = function(self, w, h)
		surface.SetDrawColor(35, 35, 40, 230)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	local descTitle = vgui.Create("DLabel", desc)
	descTitle:SetPos(10, 8)
	descTitle:SetSize(descW - 20, 24)
	descTitle:SetFont("DermaDefaultBold")
	descTitle:SetTextColor(c.text)
	descTitle:SetText("")
	local descBody = vgui.Create("DLabel", desc)
	descBody:SetPos(10, 36)
	descBody:SetSize(descW - 20, desc:GetTall() - 48)
	descBody:SetWrap(true)
	descBody:SetTextColor(c.dim)
	descBody:SetText("Hover an item.")
	frame.SetDescription = function(def)
		if def then
			descTitle:SetText(def.name or "")
			descBody:SetText((def.desc or "") .. "\n\nWeight: " .. tostring(def.weight) .. " kg")
		else
			descTitle:SetText("")
			descBody:SetText("Hover an item.\nLMB drag to move · click to use · RMB drop")
		end
	end
	frame.SetDescription(nil)

	-- Equip slots (PERP main/side)
	local equipY = 36
	local equipH = (bagTop - 48) * 0.42
	local equipW = (bagAreaW - descW - buffer * 3) * 0.5
	local mainEq = createSlot(frame, INV.EQUIP_MAIN, { equip = true })
	mainEq:SetPos(descW + buffer * 2, equipY)
	mainEq:SetSize(equipW, equipH)
	slots[INV.EQUIP_MAIN] = mainEq

	local sideEq = createSlot(frame, INV.EQUIP_SIDE, { equip = true })
	sideEq:SetPos(descW + buffer * 3 + equipW, equipY)
	sideEq:SetSize(equipW, equipH)
	slots[INV.EQUIP_SIDE] = sideEq

	local eqLabel = vgui.Create("DLabel", frame)
	eqLabel:SetPos(descW + buffer * 2, equipY + equipH + 2)
	eqLabel:SetSize(200, 16)
	eqLabel:SetText("MAIN          SIDE")
	eqLabel:SetTextColor(c.dim)

	-- Bag grid
	for y = 1, H do
		for x = 1, W do
			local slotNum = 2 + (y - 1) * W + x
			local s = createSlot(frame, slotNum, {})
			local px = buffer + (x - 1) * (buffer + block)
			local py = maxH - ((H - (y - 1)) * (buffer + block))
			s:SetPos(px, py)
			s:SetSize(block, block)
			slots[slotNum] = s
		end
	end

	-- Storage side (PERP bank dual pane)
	local storSlots = {}
	if dual then
		local sx0 = maxW * 0.52
		local storW = maxW - sx0 - 10
		local sAvail = storW - ((W + 1) * buffer)
		local sBlock = sAvail / W
		local storLabel = vgui.Create("DLabel", frame)
		storLabel:SetPos(sx0, 40)
		storLabel:SetSize(storW, 20)
		storLabel:SetText(string.format("%.1f / %.1f kg  ·  double-click / drag to transfer",
			MintyRP.Storage.Weight or 0, MintyRP.Storage.MaxWeight or 100))
		storLabel:SetTextColor(c.dim)

		-- Storage uses linear visual slots mapped to item list indices
		local maxStor = W * H
		for y = 1, H do
			for x = 1, W do
				local idx = (y - 1) * W + x
				local s = createSlot(frame, 0, { storage = true })
				s.StorageIndex = idx
				local px = sx0 + buffer + (x - 1) * (buffer + sBlock)
				local py = maxH - ((H - (y - 1)) * (buffer + sBlock))
				s:SetPos(px, py)
				s:SetSize(sBlock, sBlock)
				storSlots[idx] = s
			end
		end
		frame.StorageSlots = storSlots
		frame.StorageLabel = storLabel
	end

	frame.GetHoveredSlot = function()
		for _, s in pairs(slots) do
			if IsValid(s) and s.cursorIn then return s end
		end
		if frame.StorageSlots then
			for _, s in pairs(frame.StorageSlots) do
				if IsValid(s) and s.cursorIn then return s end
			end
		end
		return nil
	end

	frame.RefreshSlots = function()
		for _, s in pairs(slots) do
			if IsValid(s) then s:Refresh() end
		end
		if frame.StorageSlots then
			for _, s in pairs(frame.StorageSlots) do
				if IsValid(s) then s:Refresh() end
			end
		end
		if IsValid(frame.StorageLabel) then
			frame.StorageLabel:SetText(string.format("%.1f / %.1f kg  ·  drag to transfer",
				MintyRP.Storage.Weight or 0, MintyRP.Storage.MaxWeight or 100))
		end
	end

	-- Work jobs quick menu
	local work = vgui.Create("DButton", frame)
	work:SetPos(buffer + 2, bagTop - 28)
	work:SetSize(100, 22)
	work:SetText("Jobs")
	work.DoClick = function()
		if not MintyRP.Economy or not MintyRP.Economy.Jobs then return end
		local m = DermaMenu()
		for _, id in ipairs({ "unemployed", "labourer", "courier", "mechanic" }) do
			local j = MintyRP.Economy.Jobs[id]
			if j then
				m:AddOption(j.name .. " ($" .. j.paycheck .. ")", function()
					MintyRP.Economy.RequestJob(j.id)
				end)
			end
		end
		m:Open()
	end

	frame.RefreshSlots()
end

INV.RebuildList = function()
	if IsValid(frame) and frame.RefreshSlots then frame.RefreshSlots() end
end

print("[MintyRP] Inventory client loaded (PERP-inspired)")
