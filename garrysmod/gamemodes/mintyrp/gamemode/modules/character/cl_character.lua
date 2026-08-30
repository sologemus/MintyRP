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

local menuFrame
local cachedChars = {}
local maxSlots = 3

local colBg = Color(14, 20, 18, 245)
local colMint = Color(62, 207, 142)
local colText = Color(230, 236, 232)
local colDim = Color(150, 165, 158)

local function closeMenu()
	if IsValid(menuFrame) then
		menuFrame:Close()
		menuFrame = nil
	end
end

local function requestSelect(id)
	net.Start("MintyRP_CharacterSelect")
		net.WriteUInt(id, 32)
	net.SendToServer()
end

local function requestCreate(name, model)
	net.Start("MintyRP_CharacterCreate")
		net.WriteString(name)
		net.WriteString(model)
	net.SendToServer()
end

local function openCreatePanel(parent)
	local panel = vgui.Create("DPanel", parent)
	panel:Dock(FILL)
	panel:DockPadding(20, 16, 20, 16)
	panel.Paint = function(self, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(20, 28, 24, 230))
	end

	local title = vgui.Create("DLabel", panel)
	title:Dock(TOP)
	title:SetTall(28)
	title:SetFont("DermaLarge")
	title:SetTextColor(colMint)
	title:SetText("Create Character")

	local hint = vgui.Create("DLabel", panel)
	hint:Dock(TOP)
	hint:SetTall(22)
	hint:DockMargin(0, 4, 0, 8)
	hint:SetTextColor(colDim)
	hint:SetText("First and last name · serious RP appearance")

	local nameEntry = vgui.Create("DTextEntry", panel)
	nameEntry:Dock(TOP)
	nameEntry:SetTall(28)
	nameEntry:SetPlaceholderText("e.g. Jordan Hale")
	nameEntry:SetUpdateOnType(true)

	local modelLabel = vgui.Create("DLabel", panel)
	modelLabel:Dock(TOP)
	modelLabel:SetTall(22)
	modelLabel:DockMargin(0, 12, 0, 4)
	modelLabel:SetTextColor(colText)
	modelLabel:SetText("Model")

	local modelList = vgui.Create("DComboBox", panel)
	modelList:Dock(TOP)
	modelList:SetTall(28)

	local models = Char.Models or {}
	local selectedModel = Char.DefaultModel or models[1]
	for i = 1, #models do
		modelList:AddChoice(models[i], models[i], models[i] == selectedModel)
	end
	modelList.OnSelect = function(_, _, _, data)
		selectedModel = data
	end

	local preview = vgui.Create("DModelPanel", panel)
	preview:Dock(TOP)
	preview:SetTall(180)
	preview:DockMargin(0, 12, 0, 8)
	preview:SetModel(selectedModel)
	preview:SetFOV(40)
	function preview:LayoutEntity(ent)
		if IsValid(ent) then
			ent:SetAngles(Angle(0, 45, 0))
		end
	end

	modelList.OnSelect = function(_, _, _, data)
		selectedModel = data
		preview:SetModel(data)
	end

	local createBtn = vgui.Create("DButton", panel)
	createBtn:Dock(BOTTOM)
	createBtn:SetTall(36)
	createBtn:SetText("Create & Enter Rockford")
	createBtn:SetTextColor(Color(10, 20, 14))
	createBtn.Paint = function(self, w, h)
		draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(80, 220, 160) or colMint)
	end
	createBtn.DoClick = function()
		local name = nameEntry:GetValue() or ""
		local clean, err = Char.ValidateName(name)
		if not clean then
			local messages = {
				length = "Name must be 3–24 characters.",
				chars = "Letters, spaces, hyphens, apostrophes only.",
				fullname = "Use a first and last name.",
				caps = "Don't use all caps.",
			}
			notification.AddLegacy(messages[err] or "Invalid name.", NOTIFY_ERROR, 4)
			return
		end
		requestCreate(clean, selectedModel)
	end

	return panel
end

function Char.OpenMenu()
	closeMenu()

	menuFrame = vgui.Create("DFrame")
	menuFrame:SetSize(math.min(720, ScrW() * 0.9), math.min(520, ScrH() * 0.85))
	menuFrame:Center()
	menuFrame:SetTitle("")
	menuFrame:ShowCloseButton(false)
	menuFrame:SetDraggable(false)
	menuFrame:MakePopup()
	menuFrame:SetKeyboardInputEnabled(true)
	menuFrame.Paint = function(self, w, h)
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
	left:SetWide(260)
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
			draw.SimpleText("Slot " .. c.slot .. "  ·  $" .. string.Comma(c.money), "DermaDefault", 14, 36, colDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
		btn.DoClick = function()
			requestSelect(c.id)
		end
	end

	if #cachedChars < maxSlots then
		local newBtn = left:Add("DButton")
		newBtn:Dock(TOP)
		newBtn:SetTall(40)
		newBtn:SetText("＋  New Character")
		newBtn:SetTextColor(colMint)
		newBtn.Paint = function(self, w, h)
			draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(28, 48, 38) or Color(18, 28, 24))
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
	-- List packet may arrive same tick; defer one frame
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

	closeMenu()
end)

print("[MintyRP] Character client loaded")
