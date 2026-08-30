--[[-------------------------------------------------------------------------
	MintyRP — Bank client UI
	Realm: CLIENT
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP.Bank = MintyRP.Bank or {}

local frame
local colMint = Color(62, 207, 142)
local colBg = Color(14, 20, 18, 245)
local colText = Color(230, 236, 232)
local colDim = Color(150, 165, 158)

local function sendBank(action, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount < 1 then return end
	net.Start("MintyRP_BankAction")
		net.WriteUInt(action, 2)
		net.WriteUInt(math.min(amount, 10000000), 32)
	net.SendToServer()
end

local function openBank(cash, bank)
	if IsValid(frame) then frame:Remove() end

	frame = vgui.Create("DFrame")
	frame:SetSize(380, 260)
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame.Paint = function(_, w, h)
		draw.RoundedBox(6, 0, 0, w, h, colBg)
		draw.SimpleText("Rockford Bank", "DermaLarge", 16, 12, colMint)
		draw.SimpleText("Cash " .. (MintyRP.Util and MintyRP.Util.FormatMoney(cash) or ("$" .. cash))
			.. "   ·   Bank " .. (MintyRP.Util and MintyRP.Util.FormatMoney(bank) or ("$" .. bank)),
			"DermaDefault", 16, 44, colDim)
	end

	local entry = vgui.Create("DTextEntry", frame)
	entry:SetPos(16, 80)
	entry:SetSize(348, 28)
	entry:SetPlaceholderText("Amount")
	entry:SetNumeric(true)

	local dep = vgui.Create("DButton", frame)
	dep:SetPos(16, 124)
	dep:SetSize(168, 36)
	dep:SetText("Deposit")
	dep.DoClick = function()
		sendBank(1, entry:GetValue())
		frame:Close()
	end

	local wit = vgui.Create("DButton", frame)
	wit:SetPos(196, 124)
	wit:SetSize(168, 36)
	wit:SetText("Withdraw")
	wit.DoClick = function()
		sendBank(2, entry:GetValue())
		frame:Close()
	end

	local allIn = vgui.Create("DButton", frame)
	allIn:SetPos(16, 172)
	allIn:SetSize(168, 28)
	allIn:SetText("Deposit all cash")
	allIn.DoClick = function()
		sendBank(1, cash)
		frame:Close()
	end

	local allOut = vgui.Create("DButton", frame)
	allOut:SetPos(196, 172)
	allOut:SetSize(168, 28)
	allOut:SetText("Withdraw all bank")
	allOut.DoClick = function()
		sendBank(2, bank)
		frame:Close()
	end
end

net.Receive("MintyRP_BankOpen", function()
	local cash = net.ReadUInt(32)
	local bank = net.ReadUInt(32)
	local ply = LocalPlayer()
	if IsValid(ply) then
		ply.MintyRP = ply.MintyRP or {}
		ply.MintyRP.money = cash
		ply.MintyRP.bank = bank
	end
	openBank(cash, bank)
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
