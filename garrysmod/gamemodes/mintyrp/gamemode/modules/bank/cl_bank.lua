--[[-------------------------------------------------------------------------
	MintyRP — Bank / ATM client UI (dark RP panel)
	Realm: CLIENT
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP.Bank = MintyRP.Bank or {}

local frame

local function col()
	return (MintyRP.UI and MintyRP.UI.Colors) or {
		bg = Color(18, 18, 20, 250),
		accent = Color(72, 180, 130),
		text = Color(235, 235, 238),
		dim = Color(140, 140, 150),
		panel = Color(28, 28, 32),
		border = Color(55, 55, 62),
	}
end

local function sendBank(action, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount < 1 then return end
	net.Start("MintyRP_BankAction")
		net.WriteUInt(action, 2)
		net.WriteUInt(math.min(amount, 10000000), 32)
	net.SendToServer()
end

local function openBank(cash, bank, isATM)
	if IsValid(frame) then frame:Remove() end
	local c = col()
	local accent = isATM and Color(120, 180, 230) or c.accent
	local title = isATM and "ATM" or "BANK"

	frame = vgui.Create("DFrame")
	frame:SetSize(400, 280)
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:ShowCloseButton(false)
	frame.Paint = function(_, w, h)
		draw.RoundedBox(6, 0, 0, w, h, c.bg)
		surface.SetDrawColor(c.border)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText(title, "DermaLarge", 18, 14, accent)
		local money = MintyRP.Util and MintyRP.Util.FormatMoney or function(n) return "$" .. n end
		draw.SimpleText("Cash " .. money(cash) .. "    Account " .. money(bank), "DermaDefault", 18, 48, c.dim)
	end

	local x = vgui.Create("DButton", frame)
	x:SetPos(368, 10)
	x:SetSize(24, 24)
	x:SetText("✕")
	x:SetTextColor(c.dim)
	x.Paint = function() end
	x.DoClick = function() frame:Close() end

	local entry = vgui.Create("DTextEntry", frame)
	entry:SetPos(18, 84)
	entry:SetSize(364, 32)
	entry:SetPlaceholderText("Amount")
	entry:SetNumeric(true)
	entry:SetPaintBackground(true)

	local function mk(px, py, pw, label, fn)
		local b = vgui.Create("DButton", frame)
		b:SetPos(px, py)
		b:SetSize(pw, 36)
		b:SetText(label)
		b.DoClick = fn
		return b
	end

	mk(18, 132, 176, "Deposit", function()
		sendBank(1, entry:GetValue())
		frame:Close()
	end)
	mk(206, 132, 176, "Withdraw", function()
		sendBank(2, entry:GetValue())
		frame:Close()
	end)
	mk(18, 180, 176, "Deposit all", function()
		sendBank(1, cash)
		frame:Close()
	end)
	mk(206, 180, 176, "Withdraw all", function()
		sendBank(2, bank)
		frame:Close()
	end)
end

net.Receive("MintyRP_BankOpen", function()
	local cash = net.ReadUInt(32)
	local bank = net.ReadUInt(32)
	local isATM = net.ReadBool()
	local ply = LocalPlayer()
	if IsValid(ply) then
		ply.MintyRP = ply.MintyRP or {}
		ply.MintyRP.money = cash
		ply.MintyRP.bank = bank
	end
	openBank(cash, bank, isATM)
end)

net.Receive("MintyRP_BankSync", function()
	local cash = net.ReadUInt(32)
	local bank = net.ReadUInt(32)
	local ply = LocalPlayer()
	if IsValid(ply) then
		ply.MintyRP = ply.MintyRP or {}
		ply.MintyRP.money = cash
		ply.MintyRP.bank = bank
	end
end)

print("[MintyRP] Bank client loaded")
