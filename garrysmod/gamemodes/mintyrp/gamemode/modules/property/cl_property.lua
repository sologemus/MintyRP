--[[-------------------------------------------------------------------------
	MintyRP — Property client (door HUD + F3 owned list)
	Realm: CLIENT
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP.Property = MintyRP.Property or {}

local Prop = MintyRP.Property
local LocalPlayer = LocalPlayer
local IsValid = IsValid
local draw = draw
local ScrW, ScrH = ScrW, ScrH

Prop.Owned = Prop.Owned or {}
Prop.OwnedNames = Prop.OwnedNames or {}

local menuFrame

local function col()
	return (MintyRP.UI and MintyRP.UI.Colors) or {
		bg = Color(18, 18, 20, 250),
		accent = Color(72, 180, 130),
		text = Color(235, 235, 238),
		dim = Color(140, 140, 150),
		panel = Color(28, 28, 32),
		warn = Color(220, 160, 90),
		border = Color(55, 55, 62),
	}
end

local function sendAction(action, propertyId)
	net.Start("MintyRP_PropertyAction")
		net.WriteUInt(action, 3)
		net.WriteString(propertyId)
	net.SendToServer()
end

function Prop.DoorInfo(door)
	if not IsValid(door) then return nil end
	local id = door:GetNWString("MintyRP_Property", "")
	if id == "" then return nil end
	local def = Prop.Get(id)
	local ownable = door:GetNWBool("MintyRP_Ownable", def and def.ownable)
	local name = door:GetNWString("MintyRP_PropName", "")
	if name == "" then name = Prop.OwnedNames[id] or (def and def.name) or id end
	local price = door:GetNWInt("MintyRP_PropPrice", 0)
	if price <= 0 and def then price = def.price or 0 end
	return { id = id, name = name, ownable = ownable, price = price, def = def }
end

net.Receive("MintyRP_PropertySync", function()
	local count = net.ReadUInt(8)
	Prop.Owned = {}
	Prop.OwnedNames = {}
	for i = 1, count do
		local id = net.ReadString()
		local name = net.ReadString()
		local locked = net.ReadBool()
		Prop.Owned[id] = locked
		Prop.OwnedNames[id] = name
	end
end)

local function tracedDoor()
	local ply = LocalPlayer()
	if not IsValid(ply) then return nil end
	local tr = ply:GetEyeTrace()
	if not tr or not IsValid(tr.Entity) then return nil end
	if tr.HitPos:DistToSqr(ply:EyePos()) > (180 * 180) then return nil end
	if not Prop.IsDoor(tr.Entity) then return nil end
	return tr.Entity
end

hook.Add("HUDPaint", "MintyRP_PropertyDoorHint", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end

	local door = tracedDoor()
	if not door then return end
	local info = Prop.DoorInfo(door)
	local c = col()
	local x, y = ScrW() * 0.5, ScrH() * 0.58

	-- Dark pill behind text
	surface.SetFont("DermaDefaultBold")
	local title = info and info.name or "Door"
	local tw = surface.GetTextSize(title)
	draw.RoundedBox(4, x - math.max(tw, 180) * 0.5 - 16, y - 8, math.max(tw, 180) + 32, 48, Color(12, 12, 14, 210))

	if not info then
		draw.SimpleText(title, "DermaDefaultBold", x, y, c.dim, TEXT_ALIGN_CENTER)
		draw.SimpleText("Not linked — host: mintyrp_propscan", "DermaDefault", x, y + 18, c.dim, TEXT_ALIGN_CENTER)
		return
	end

	draw.SimpleText(info.name, "DermaDefaultBold", x, y, c.accent, TEXT_ALIGN_CENTER)
	local owned = Prop.Owned[info.id] ~= nil
	if owned then
		draw.SimpleText(
			(Prop.Owned[info.id] and "Locked" or "Unlocked") .. "  ·  F3 manage  ·  Keys LMB/RMB",
			"DermaDefault", x, y + 18, c.text, TEXT_ALIGN_CENTER
		)
	elseif not info.ownable then
		draw.SimpleText(
			(info.def and Prop.GetOwnerLabel(info.def)) or "Not for sale",
			"DermaDefault", x, y + 18, c.warn, TEXT_ALIGN_CENTER
		)
	else
		local price = MintyRP.Util and MintyRP.Util.FormatMoney(info.price) or ("$" .. info.price)
		draw.SimpleText("For sale " .. price .. "  ·  Press N", "DermaDefault", x, y + 18, c.text, TEXT_ALIGN_CENTER)
	end
end)

function Prop.OpenMenu()
	if IsValid(menuFrame) then
		menuFrame:Remove()
		menuFrame = nil
		return
	end

	local c = col()
	menuFrame = vgui.Create("DFrame")
	menuFrame:SetSize(480, 400)
	menuFrame:Center()
	menuFrame:SetTitle("")
	menuFrame:MakePopup()
	menuFrame:ShowCloseButton(true)
	menuFrame.Paint = function(_, w, h)
		draw.RoundedBox(6, 0, 0, w, h, c.bg)
		surface.SetDrawColor(c.border)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText("OWNED DOORS", "DermaLarge", 16, 12, c.accent)
		draw.SimpleText("Buy doors with N  ·  Keys to lock", "DermaDefault", 16, 42, c.dim)
	end

	local list = vgui.Create("DScrollPanel", menuFrame)
	list:Dock(FILL)
	list:DockMargin(12, 64, 12, 12)

	local count = 0
	for id, locked in pairs(Prop.Owned) do
		count = count + 1
		local title = Prop.OwnedNames[id] or id
		local row = list:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(56)
		row:DockMargin(0, 0, 0, 6)
		row.Paint = function(_, w, h)
			draw.RoundedBox(4, 0, 0, w, h, c.panel)
			draw.SimpleText(title, "DermaDefaultBold", 12, 10, c.text)
			draw.SimpleText(locked and "Locked" or "Unlocked", "DermaDefault", 12, 32, c.dim)
		end

		local lockBtn = vgui.Create("DButton", row)
		lockBtn:SetPos(280, 14)
		lockBtn:SetSize(80, 28)
		lockBtn:SetText(locked and "Unlock" or "Lock")
		lockBtn.DoClick = function()
			sendAction(locked and 4 or 3, id)
			timer.Simple(0.2, function()
				if IsValid(menuFrame) then menuFrame:Remove() menuFrame = nil Prop.OpenMenu() end
			end)
		end

		local sellBtn = vgui.Create("DButton", row)
		sellBtn:SetPos(368, 14)
		sellBtn:SetSize(80, 28)
		sellBtn:SetText("Sell 50%")
		sellBtn.DoClick = function()
			sendAction(2, id)
			timer.Simple(0.25, function()
				if IsValid(menuFrame) then menuFrame:Remove() menuFrame = nil Prop.OpenMenu() end
			end)
		end
	end

	if count == 0 then
		local empty = list:Add("DLabel")
		empty:Dock(TOP)
		empty:SetTall(40)
		empty:SetTextColor(c.dim)
		empty:SetText("No doors owned. Look at a door and press N.")
	end
end

print("[MintyRP] Property client loaded")
