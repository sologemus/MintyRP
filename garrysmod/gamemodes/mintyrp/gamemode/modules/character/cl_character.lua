--[[-------------------------------------------------------------------------
	MintyRP — Character select / create UI
	Realm: CLIENT
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP.Character = MintyRP.Character or {}

local Char = MintyRP.Character
local LocalPlayer = LocalPlayer
local IsValid = IsValid
local vgui = vgui
local ScrW = ScrW
local ScrH = ScrH
local draw = draw
local surface = surface

local menuFrame
local cachedChars = {}
local maxSlots = 3
local creating = false

local colBg = Color(14, 20, 18, 245)
local colMint = Color(62, 207, 142)
local colText = Color(230, 236, 232)
local colDim = Color(150, 165, 158)

local function closeMenu()
	if IsValid(menuFrame) then
		menuFrame:Remove()
		menuFrame = nil
	end
	creating = false
end

local function requestSelect(id)
	net.Start("MintyRP_CharacterSelect")
		net.WriteUInt(id, 32)
	net.SendToServer()
end

local function requestCreate(name, model, skin, bodygroups)
	net.Start("MintyRP_CharacterCreate")
		net.WriteString(name)
		net.WriteString(model)
		net.WriteUInt(math.Clamp(math.floor(skin or 0), 0, 63), 6)

		local pairsList = {}
		for id, val in pairs(bodygroups or {}) do
			pairsList[#pairsList + 1] = { id = tonumber(id) or 0, val = tonumber(val) or 0 }
		end
		table.sort(pairsList, function(a, b) return a.id < b.id end)

		local count = math.min(#pairsList, Char.MaxBodygroups or 8)
		net.WriteUInt(count, 4)
		for i = 1, count do
			net.WriteUInt(math.Clamp(pairsList[i].id, 0, 15), 4)
			net.WriteUInt(math.Clamp(pairsList[i].val, 0, 31), 5)
		end
	net.SendToServer()
end

local function fitModelPanel(pnl)
	if not IsValid(pnl) or not IsValid(pnl.Entity) then return end

	local ent = pnl.Entity
	local mn, mx = ent:GetRenderBounds()
	local center = (mn + mx) * 0.5
	local size = 0
	size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
	size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
	size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
	size = math.max(size, 1)

	pnl:SetFOV(36)
	pnl:SetLookAt(center + Vector(0, 0, 2))
	pnl:SetCamPos(center + Vector(size * 0.85, size * 0.85, size * 0.35))
end

local function refreshClothingControls(container, preview, state)
	container:Clear()

	if not IsValid(preview) or not IsValid(preview.Entity) then
		local missing = vgui.Create("DLabel", container)
		missing:Dock(TOP)
		missing:SetText("Model has no clothing options.")
		missing:SetTextColor(colDim)
		return
	end

	local ent = preview.Entity
	state.skin = math.Clamp(state.skin or 0, 0, math.max(ent:SkinCount() - 1, 0))
	ent:SetSkin(state.skin)

	if ent:SkinCount() > 1 then
		local skinRow = vgui.Create("DPanel", container)
		skinRow:Dock(TOP)
		skinRow:SetTall(28)
		skinRow:DockMargin(0, 0, 0, 6)
		skinRow.Paint = nil

		local lbl = vgui.Create("DLabel", skinRow)
		lbl:Dock(LEFT)
		lbl:SetWide(70)
		lbl:SetText("Skin")
		lbl:SetTextColor(colText)

		local slider = vgui.Create("DNumSlider", skinRow)
		slider:Dock(FILL)
		slider:SetMin(0)
		slider:SetMax(ent:SkinCount() - 1)
		slider:SetDecimals(0)
		slider:SetValue(state.skin)
		slider:SetText("")
		slider.OnValueChanged = function(_, val)
			state.skin = math.floor(val + 0.5)
			if IsValid(preview.Entity) then
				preview.Entity:SetSkin(state.skin)
			end
		end
	end

	local bgCount = ent:GetNumBodyGroups() or 0
	state.bodygroups = state.bodygroups or {}

	for i = 0, bgCount - 1 do
		local submodels = ent:GetBodygroupCount(i) or 0
		if submodels > 1 then
			local bgName = ent:GetBodygroupName(i) or ("Part " .. i)
			local row = vgui.Create("DPanel", container)
			row:Dock(TOP)
			row:SetTall(28)
			row:DockMargin(0, 0, 0, 4)
			row.Paint = nil

			local lbl = vgui.Create("DLabel", row)
			lbl:Dock(LEFT)
			lbl:SetWide(70)
			lbl:SetText(bgName)
			lbl:SetTextColor(colText)

			local cur = state.bodygroups[i] or ent:GetBodygroup(i) or 0
			state.bodygroups[i] = cur
			ent:SetBodygroup(i, cur)

			local slider = vgui.Create("DNumSlider", row)
			slider:Dock(FILL)
			slider:SetMin(0)
			slider:SetMax(submodels - 1)
			slider:SetDecimals(0)
			slider:SetValue(cur)
			slider:SetText("")
			slider.OnValueChanged = function(_, val)
				local v = math.floor(val + 0.5)
				state.bodygroups[i] = v
				if IsValid(preview.Entity) then
					preview.Entity:SetBodygroup(i, v)
				end
			end
		end
	end
end

local function openCreatePanel(parent)
	local panel = vgui.Create("DPanel", parent)
	panel:Dock(FILL)
	panel:DockPadding(16, 12, 16, 12)
	panel.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(20, 28, 24, 230))
	end

	local title = vgui.Create("DLabel", panel)
	title:Dock(TOP)
	title:SetTall(26)
	title:SetFont("DermaLarge")
	title:SetTextColor(colMint)
	title:SetText("Create Character")

	local hint = vgui.Create("DLabel", panel)
	hint:Dock(TOP)
	hint:SetTall(18)
	hint:DockMargin(0, 2, 0, 6)
	hint:SetTextColor(colDim)
	hint:SetText("First + last name · model · clothes (skin / bodygroups)")

	local nameEntry = vgui.Create("DTextEntry", panel)
	nameEntry:Dock(TOP)
	nameEntry:SetTall(28)
	nameEntry:SetPlaceholderText("e.g. Jordan Hale")
	nameEntry:SetUpdateOnType(true)

	local modelLabel = vgui.Create("DLabel", panel)
	modelLabel:Dock(TOP)
	modelLabel:SetTall(20)
	modelLabel:DockMargin(0, 8, 0, 2)
	modelLabel:SetTextColor(colText)
	modelLabel:SetText("Model")

	local modelList = vgui.Create("DComboBox", panel)
	modelList:Dock(TOP)
	modelList:SetTall(26)

	local state = {
		model = Char.DefaultModel or (Char.Models and Char.Models[1]),
		skin = 0,
		bodygroups = {},
	}

	local models = Char.Models or {}
	for i = 1, #models do
		local path = models[i]
		local label = (Char.ModelLabels and Char.ModelLabels[path]) or path
		modelList:AddChoice(label, path, path == state.model)
	end

	local mid = vgui.Create("DPanel", panel)
	mid:Dock(FILL)
	mid:DockMargin(0, 8, 0, 8)
	mid.Paint = nil

	local preview = vgui.Create("DModelPanel", mid)
	preview:Dock(LEFT)
	preview:SetWide(200)
	preview:SetModel(state.model)
	preview:SetFOV(36)
	function preview:LayoutEntity(ent)
		if not IsValid(ent) then return end
		ent:SetAngles(Angle(0, RealTime() * 20 % 360, 0))
	end
	timer.Simple(0, function()
		fitModelPanel(preview)
		Char.ApplyAppearance(preview.Entity, state)
	end)

	local clothesScroll = vgui.Create("DScrollPanel", mid)
	clothesScroll:Dock(FILL)
	clothesScroll:DockMargin(10, 0, 0, 0)

	local clothesInner = vgui.Create("DPanel", clothesScroll)
	clothesInner:Dock(TOP)
	clothesInner:SetTall(220)
	clothesInner.Paint = nil

	local clothesTitle = vgui.Create("DLabel", clothesInner)
	clothesTitle:Dock(TOP)
	clothesTitle:SetTall(18)
	clothesTitle:SetTextColor(colMint)
	clothesTitle:SetText("Clothes")

	local clothesHost = vgui.Create("DPanel", clothesInner)
	clothesHost:Dock(TOP)
	clothesHost:SetTall(190)
	clothesHost.Paint = nil

	local function reloadModel(path)
		state.model = path
		state.skin = 0
		state.bodygroups = {}
		preview:SetModel(path)
		timer.Simple(0, function()
			if not IsValid(preview) then return end
			fitModelPanel(preview)
			refreshClothingControls(clothesHost, preview, state)
		end)
	end

	modelList.OnSelect = function(_, _, _, data)
		reloadModel(data)
	end

	timer.Simple(0.05, function()
		if IsValid(clothesHost) and IsValid(preview) then
			refreshClothingControls(clothesHost, preview, state)
		end
	end)

	local status = vgui.Create("DLabel", panel)
	status:Dock(BOTTOM)
	status:SetTall(18)
	status:DockMargin(0, 4, 0, 0)
	status:SetTextColor(colDim)
	status:SetText("")

	local createBtn = vgui.Create("DButton", panel)
	createBtn:Dock(BOTTOM)
	createBtn:SetTall(36)
	createBtn:SetText("")
	createBtn.Paint = function(self, w, h)
		local col = self:IsHovered() and Color(80, 220, 160) or colMint
		if creating then col = Color(40, 90, 70) end
		draw.RoundedBox(4, 0, 0, w, h, col)
		draw.SimpleText(
			creating and "Creating…" or "Create & Enter Rockford",
			"DermaDefaultBold",
			w * 0.5,
			h * 0.5,
			Color(10, 20, 14),
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER
		)
	end
	createBtn.DoClick = function()
		if creating then return end

		local name = nameEntry:GetValue() or ""
		local clean, err = Char.ValidateName(name)
		if not clean then
			local messages = {
				length = "Name must be 3–24 characters.",
				chars = "Letters, spaces, hyphens, apostrophes only.",
				fullname = "Use a first and last name.",
				caps = "Don't use all caps.",
			}
			status:SetTextColor(Color(220, 90, 90))
			status:SetText(messages[err] or "Invalid name.")
			notification.AddLegacy(messages[err] or "Invalid name.", NOTIFY_ERROR, 4)
			surface.PlaySound("buttons/button10.wav")
			return
		end

		if not Char.IsAllowedModel(state.model) then
			status:SetTextColor(Color(220, 90, 90))
			status:SetText("Pick a valid model.")
			return
		end

		creating = true
		status:SetTextColor(colDim)
		status:SetText("Sending character to server…")
		requestCreate(clean, state.model, state.skin, state.bodygroups)

		-- Safety unlock if server never answers
		timer.Simple(5, function()
			if creating then
				creating = false
				if IsValid(status) then
					status:SetTextColor(Color(220, 160, 60))
					status:SetText("No response — check console for Lua errors.")
				end
			end
		end)
	end

	return panel
end

function Char.OpenMenu()
	closeMenu()

	menuFrame = vgui.Create("DFrame")
	menuFrame:SetSize(math.min(780, ScrW() * 0.92), math.min(560, ScrH() * 0.88))
	menuFrame:Center()
	menuFrame:SetTitle("")
	menuFrame:ShowCloseButton(false)
	menuFrame:SetDraggable(false)
	menuFrame:MakePopup()
	menuFrame:SetKeyboardInputEnabled(true)
	menuFrame.Paint = function(_, w, h)
		draw.RoundedBox(6, 0, 0, w, h, colBg)
		draw.SimpleText("MINTYRP", "DermaLarge", 24, 18, colMint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("Choose or create a character", "DermaDefault", 24, 48, colDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local body = vgui.Create("DPanel", menuFrame)
	body:Dock(FILL)
	body:DockMargin(16, 64, 16, 16)
	body.Paint = nil

	local left = vgui.Create("DScrollPanel", body)
	left:Dock(LEFT)
	left:SetWide(240)
	left:DockMargin(0, 0, 12, 0)

	local right = vgui.Create("DPanel", body)
	right:Dock(FILL)
	right.Paint = nil

	local function showCreate()
		right:Clear()
		openCreatePanel(right)
	end

	for i = 1, #cachedChars do
		local c = cachedChars[i]
		local btn = left:Add("DButton")
		btn:Dock(TOP)
		btn:SetTall(64)
		btn:DockMargin(0, 0, 0, 8)
		btn:SetText("")
		btn.Paint = function(self, w, h)
			draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(30, 44, 38) or Color(22, 32, 28))
			surface.SetDrawColor(colMint)
			surface.DrawRect(0, 0, 3, h)
			draw.SimpleText(c.name, "DermaDefaultBold", 14, 14, colText, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			local moneyStr = string.Comma and string.Comma(c.money) or tostring(c.money)
			draw.SimpleText("Slot " .. c.slot .. "  ·  $" .. moneyStr, "DermaDefault", 14, 36, colDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
		btn.DoClick = function()
			requestSelect(c.id)
		end
	end

	if #cachedChars < maxSlots then
		local newBtn = left:Add("DButton")
		newBtn:Dock(TOP)
		newBtn:SetTall(40)
		newBtn:SetText("")
		newBtn.Paint = function(self, w, h)
			draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(28, 48, 38) or Color(18, 28, 24))
			draw.SimpleText("+  New Character", "DermaDefaultBold", w * 0.5, h * 0.5, colMint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		newBtn.DoClick = showCreate
	end

	if #cachedChars == 0 then
		showCreate()
	else
		local placeholder = vgui.Create("DLabel", right)
		placeholder:Dock(FILL)
		placeholder:SetContentAlignment(5)
		placeholder:SetTextColor(colDim)
		placeholder:SetText("Select a character on the left\nor create a new one.")
	end
end

net.Receive("MintyRP_CharacterList", function()
	local count = net.ReadUInt(3)
	cachedChars = {}
	for i = 1, count do
		cachedChars[#cachedChars + 1] = {
			id = net.ReadUInt(32),
			slot = net.ReadUInt(3),
			name = net.ReadString(),
			model = net.ReadString(),
			money = net.ReadUInt(32),
		}
	end
	maxSlots = net.ReadUInt(3)
end)

net.Receive("MintyRP_OpenCharacterMenu", function()
	timer.Simple(0, function()
		Char.OpenMenu()
	end)
end)

net.Receive("MintyRP_CharacterReady", function()
	local money = net.ReadUInt(32)
	local bank = net.ReadUInt(32)
	local rpName = net.ReadString()

	local ply = LocalPlayer()
	if IsValid(ply) then
		ply.MintyRP = ply.MintyRP or {}
		ply.MintyRP.money = money
		ply.MintyRP.bank = bank
		ply.MintyRP.rpName = rpName
		ply.MintyRP.Loaded = true
	end

	creating = false
	closeMenu()
end)

print("[MintyRP] Character client loaded")
