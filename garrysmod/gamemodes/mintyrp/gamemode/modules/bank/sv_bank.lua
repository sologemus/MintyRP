--[[-------------------------------------------------------------------------
	MintyRP — Bank (deposit / withdraw)
	Realm: SERVER
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Bank = MintyRP.Bank or {}

local Bank = MintyRP.Bank
local IsValid = IsValid
local math_floor = math.floor
local CurTime = CurTime

local MAX_BITS = 512
local RATE = 0.35
local MAX_TX = 10000000

local function rateLimited(ply)
	ply.MintyRP = ply.MintyRP or {}
	local now = CurTime()
	if (ply.MintyRP._bankRate or 0) > now then return true end
	ply.MintyRP._bankRate = now + RATE
	return false
end

local function syncMoney(ply)
	local data = ply.MintyRP
	net.Start("MintyRP_BankSync")
		net.WriteUInt(math_floor(data.money or 0), 32)
		net.WriteUInt(math_floor(data.bank or 0), 32)
	net.Send(ply)
end

function Bank.Deposit(ply, amount)
	amount = math_floor(tonumber(amount) or 0)
	if amount < 1 or amount > MAX_TX then return false, "amount" end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return false, "loaded" end

	local cash = MintyRP.Player.GetMoney(ply)
	if cash < amount then return false, "money" end

	MintyRP.Player.AddMoney(ply, -amount)
	ply.MintyRP.bank = math_floor((ply.MintyRP.bank or 0) + amount)
	MintyRP.Player.Save(ply)
	syncMoney(ply)
	return true
end

function Bank.Withdraw(ply, amount)
	amount = math_floor(tonumber(amount) or 0)
	if amount < 1 or amount > MAX_TX then return false, "amount" end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return false, "loaded" end

	local bank = math_floor(ply.MintyRP.bank or 0)
	if bank < amount then return false, "bank" end

	ply.MintyRP.bank = bank - amount
	MintyRP.Player.AddMoney(ply, amount)
	MintyRP.Player.Save(ply)
	syncMoney(ply)
	return true
end

net.Receive("MintyRP_BankAction", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if len > MAX_BITS then return end
	if rateLimited(ply) then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end

	-- Must be near a bank NPC
	local near = false
	for _, ent in ipairs(ents.FindByClass("mintyrp_bank_npc")) do
		if IsValid(ent) and ent:GetPos():DistToSqr(ply:GetPos()) <= (200 * 200) then
			near = true
			break
		end
	end
	if not near then
		MintyRP.Util.Notify(ply, "You need to be at the bank.", 2)
		return
	end

	local action = net.ReadUInt(2) -- 1 deposit, 2 withdraw
	local amount = net.ReadUInt(32)

	if action == 1 then
		local ok, err = Bank.Deposit(ply, amount)
		if ok then
			MintyRP.Util.Notify(ply, "Deposited $" .. amount .. ".", 1)
		else
			local msg = ({ money = "Not enough cash.", amount = "Invalid amount." })[err] or "Deposit failed."
			MintyRP.Util.Notify(ply, msg, 3)
		end
	elseif action == 2 then
		local ok, err = Bank.Withdraw(ply, amount)
		if ok then
			MintyRP.Util.Notify(ply, "Withdrew $" .. amount .. ".", 1)
		else
			local msg = ({ bank = "Not enough in bank.", amount = "Invalid amount." })[err] or "Withdraw failed."
			MintyRP.Util.Notify(ply, msg, 3)
		end
	end
end)

function Bank.SpawnTeller()
	-- Remove old auto-spawned tellers
	for _, ent in ipairs(ents.FindByClass("mintyrp_bank_npc")) do
		if IsValid(ent) and ent.MintyRP_AutoSpawn then
			ent:Remove()
		end
	end

	local loc = MintyRP.Locations and MintyRP.Locations.Get and MintyRP.Locations.Get("bank")
	local pos = loc and loc.pos or Vector(-3200, 400, 80)
	local ang = loc and loc.ang or Angle(0, 90, 0)

	local npc = ents.Create("mintyrp_bank_npc")
	if not IsValid(npc) then
		print("[MintyRP] Failed to create bank NPC")
		return
	end

	npc:SetPos(pos + Vector(0, 0, 10))
	npc:SetAngles(ang)
	npc.MintyRP_AutoSpawn = true
	npc:Spawn()
	npc:Activate()
	print("[MintyRP] Bank teller spawned at " .. tostring(pos))
end

hook.Add("InitPostEntity", "MintyRP_BankSpawn", function()
	timer.Simple(3, Bank.SpawnTeller)
end)

hook.Add("PostCleanupMap", "MintyRP_BankRespawn", function()
	timer.Simple(3, Bank.SpawnTeller)
end)

print("[MintyRP] Bank server loaded")
