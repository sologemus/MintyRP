--[[-------------------------------------------------------------------------
	MintyRP — Property client UI / door hints
	Realm: CLIENT

	F3  — manage owned properties
	Look at a door — buy / lock hints
	Dynamic units sync name/price via NW vars (not in shared catalog).
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP.Property = MintyRP.Property or {}

local Prop = MintyRP.Property
local LocalPlayer = LocalPlayer
local IsValid = IsValid
local draw = draw
local ScrW, ScrH = ScrW, ScrH

Prop.Owned = Prop.Owned or {} -- id → locked bool
Prop.OwnedNames = Prop.OwnedNames or {}

local menuFrame
local colMint = Color(62, 207, 142)
local colText = Color(230, 236, 232)
local colDim = Color(150, 165, 158)
local colBg = Color(14, 20, 18, 245)

local function sendAction(action, propertyId)
	net.Start("MintyRP_PropertyAction")
		net.WriteUInt(action, 3)
		net.WriteString(propertyId)
	net.SendToServer()
end

--- Resolve display info from catalog OR door NW vars (dynamic units)
function Prop.DoorInfo(door)
	if not IsValid(door) then return nil end
	local id = door:GetNWString("MintyRP_Property", "")
	if id == "" then return nil end

	local def = Prop.Get(id)
	local ownable = door:GetNWBool("MintyRP_Ownable", def and def.ownable)
	local name = door:GetNWString("MintyRP_PropName", "")
	if name == "" then
		name = Prop.OwnedNames[id] or (def and def.name) or id
	end
	local price = door:GetNWInt("MintyRP_PropPrice", 0)
	if price <= 0 and def then
		price = def.price or 0
	end

	return {
		id = id,
		name = name,
		ownable = ownable,
		price = price,
		def = def,
	}
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
	if not info then
		local x, y = ScrW() * 0.5, ScrH() * 0.62
		draw.SimpleText("Door", "DermaDefaultBold", x, y, colDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText("Not linked — host: mintyrp_propscan", "DermaDefault", x, y + 18, colDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		return
	end

	local owned = Prop.Owned[info.id] ~= nil
	local locked = Prop.Owned[info.id]
	local x, y = ScrW() * 0.5, ScrH() * 0.62

	draw.SimpleText(info.name, "DermaDefaultBold", x, y, colMint, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	if owned then
		draw.SimpleText(
			(locked and "Locked" or "Unlocked") .. "  ·  [F3] Manage  ·  Keys: LMB/RMB",
			"DermaDefault",
			x, y + 18, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
		)
	elseif not info.ownable then
		local label = "City / franchise — not for sale"
		if info.def then
			label = Prop.GetOwnerLabel(info.def)
		end
		draw.SimpleText(label, "DermaDefault", x, y + 18, Color(220, 160, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	else
		local price = MintyRP.Util and MintyRP.Util.FormatMoney(info.price) or ("$" .. info.price)
		draw.SimpleText(
			"For sale: " .. price .. "  ·  Press [N] to buy (cash or bank)",
			"DermaDefault",
			x, y + 18, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
		)
	end
end)

function Prop.OpenMenu()
	if IsValid(menuFrame) then
		menuFrame:Remove()
		menuFrame = nil
		return
	end

	menuFrame = vgui.Create("DFrame")
	menuFrame:SetSize(520, 420)
	menuFrame:Center()
	menuFrame:SetTitle("")
	menuFrame:MakePopup()
	menuFrame:ShowCloseButton(true)
	menuFrame.Paint = function(_, w, h)
		draw.RoundedBox(6, 0, 0, w, h, colBg)
		draw.SimpleText("Properties", "DermaLarge", 16, 12, colMint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("Owned units  ·  Buy at doors with [N]", "DermaDefault", 16, 42, colDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local sheet = vgui.Create("DPropertySheet", menuFrame)
	sheet:Dock(FILL)
	sheet:DockMargin(12, 64, 12, 12)

	local ownedPanel = vgui.Create("DScrollPanel", sheet)
	local count = 0
	for id, locked in pairs(Prop.Owned) do
		count = count + 1
		local def = Prop.Get(id)
		local title = Prop.OwnedNames[id] or (def and def.name) or id
		local row = ownedPanel:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(72)
		row:DockMargin(0, 0, 0, 8)
		row.Paint = function(_, w, h)
			draw.RoundedBox(4, 0, 0, w, h, Color(22, 32, 28))
			draw.SimpleText(title, "DermaDefaultBold", 12, 10, colText)
			local meta = def and ((def.district or "?") .. " · " .. (def.category or "?")) or "dynamic unit"
			draw.SimpleText(meta .. "  ·  " .. (locked and "Locked" or "Unlocked"), "DermaDefault", 12, 32, colDim)
		end

		local lockBtn = vgui.Create("DButton", row)
		lockBtn:SetPos(300, 20)
		lockBtn:SetSize(80, 28)
		lockBtn:SetText(locked and "Unlock" or "Lock")
		lockBtn.DoClick = function()
			sendAction(locked and 4 or 3, id)
			timer.Simple(0.2, function()
				if IsValid(menuFrame) then
					menuFrame:Remove()
					menuFrame = nil
					Prop.OpenMenu()
				end
			end)
		end

		local sellBtn = vgui.Create("DButton", row)
		sellBtn:SetPos(390, 20)
		sellBtn:SetSize(80, 28)
		sellBtn:SetText("Sell 50%")
		sellBtn.DoClick = function()
			sendAction(2, id)
			timer.Simple(0.25, function()
				if IsValid(menuFrame) then
					menuFrame:Remove()
					menuFrame = nil
					Prop.OpenMenu()
				end
			end)
		end
	end
	if count == 0 then
		local empty = ownedPanel:Add("DLabel")
		empty:Dock(TOP)
		empty:SetTall(40)
		empty:SetTextColor(colDim)
		empty:SetText("No owned properties. Look at a door and press N.")
	end
	sheet:AddSheet("Owned", ownedPanel, "icon16/key.png")

	local catalog = vgui.Create("DScrollPanel", sheet)
	local sorted = Prop.GetSorted and Prop.GetSorted(function(d) return not d.dynamic end) or {}
	local lastDistrict = ""
	local section = ""
	for i = 1, #sorted do
		local def = sorted[i]
		local sec = def.ownable and "FOR SALE (catalog)" or "CITY / FRANCHISE"
		if sec ~= section then
			section = sec
			lastDistrict = ""
			local sh = catalog:Add("DLabel")
			sh:Dock(TOP)
			sh:SetTall(26)
			sh:DockMargin(0, 10, 0, 2)
			sh:SetTextColor(colMint)
			sh:SetFont("DermaLarge")
			sh:SetText(section)
		end
		if def.district ~= lastDistrict then
			lastDistrict = def.district
			local header = catalog:Add("DLabel")
			header:Dock(TOP)
			header:SetTall(22)
			header:DockMargin(0, 6, 0, 2)
			header:SetTextColor(colDim)
			header:SetFont("DermaDefaultBold")
			header:SetText(string.upper(lastDistrict or "other"))
		end

		local owned = Prop.Owned[def.id] ~= nil
		local row = catalog:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(34)
		row:DockMargin(0, 0, 0, 3)
		row.Paint = function(_, w, h)
			draw.RoundedBox(3, 0, 0, w, h, Color(22, 32, 28))
			draw.SimpleText(def.name, "DermaDefault", 10, h * 0.5, colText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local right
			if owned then
				right = "OWNED"
			elseif not def.ownable then
				right = def.ownerType == "franchise" and "FRANCHISE" or "CITY"
			else
				right = MintyRP.Util and MintyRP.Util.FormatMoney(def.price) or ("$" .. def.price)
			end
			local rc = owned and colMint or (def.ownable and colDim or Color(220, 160, 90))
			draw.SimpleText(right, "DermaDefault", w - 10, h * 0.5, rc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
	local note = catalog:Add("DLabel")
	note:Dock(TOP)
	note:SetTall(40)
	note:DockMargin(0, 12, 0, 0)
	note:SetTextColor(colDim)
	note:SetWrap(true)
	note:SetText("Street doors auto-link into buyable units. Look at any door for price + [N].")
	sheet:AddSheet("Catalog", catalog, "icon16/house.png")
end

print("[MintyRP] Property client loaded")
