--[[-------------------------------------------------------------------------
	MintyRP — Economy / paychecks (server)
	Realm: SERVER
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP = MintyRP or {}
MintyRP.Economy = MintyRP.Economy or {}

util.AddNetworkString("MintyRP_SetJob")
util.AddNetworkString("MintyRP_Paycheck")
util.AddNetworkString("MintyRP_JobSync")

local function CharID(ply)
	return ply.MintyRP and tonumber(ply.MintyRP.characterId)
end

local function GetJobID(ply)
	return (ply.MintyRP and ply.MintyRP.job) or "unemployed"
end

local function GetJob(ply)
	local id = GetJobID(ply)
	return MintyRP.Economy.Jobs[id] or MintyRP.Economy.Jobs.unemployed
end

function MintyRP.Economy.SetJob(ply, jobID)
	if not IsValid(ply) or not CharID(ply) then return false end
	local job = MintyRP.Economy.Jobs[jobID]
	if not job then return false end

	ply.MintyRP.job = jobID
	sql.Query(string.format(
		"UPDATE mintyrp_characters SET job = %s WHERE id = %d",
		sql.SQLStr(jobID),
		CharID(ply)
	))

	net.Start("MintyRP_JobSync")
		net.WriteString(jobID)
	net.Send(ply)

	MintyRP.Util.Notify(ply, ("Clocked in as %s ($%s / paycheck)."):format(
		job.name, string.Comma(job.paycheck)
	), 0)

	return true
end

function MintyRP.Economy.LoadJob(ply)
	if not IsValid(ply) or not CharID(ply) then return end
	local row = sql.QueryRow(
		"SELECT job, last_paycheck FROM mintyrp_characters WHERE id = " .. CharID(ply)
	)
	ply.MintyRP.job = (row and row.job and row.job ~= "" and row.job) or "unemployed"
	ply.MintyRP.lastPaycheck = (row and tonumber(row.last_paycheck)) or 0

	net.Start("MintyRP_JobSync")
		net.WriteString(ply.MintyRP.job)
	net.Send(ply)
end

function MintyRP.Economy.Pay(ply)
	if not IsValid(ply) or not CharID(ply) then return end
	if not ply:Alive() then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end

	local job = GetJob(ply)
	local amount = job.paycheck or MintyRP.Economy.BasePaycheck or 150
	if amount <= 0 then return end

	if MintyRP.Bank and MintyRP.Bank.Credit then
		MintyRP.Bank.Credit(ply, amount)
	else
		ply.MintyRP.bank = math.floor((ply.MintyRP.bank or 0) + amount)
		MintyRP.Player.Save(ply)
	end

	local now = os.time()
	ply.MintyRP.lastPaycheck = now
	sql.Query(string.format(
		"UPDATE mintyrp_characters SET last_paycheck = %d WHERE id = %d",
		now,
		CharID(ply)
	))

	net.Start("MintyRP_Paycheck")
		net.WriteUInt(amount, 32)
		net.WriteString(job.name or "Paycheck")
	net.Send(ply)

	MintyRP.Util.Notify(ply, ("Paycheck: +$%s (%s) → bank"):format(
		string.Comma(amount), job.name
	), 0)
end

net.Receive("MintyRP_SetJob", function(_, ply)
	if not IsValid(ply) then return end
	local jobID = net.ReadString()
	if not jobID or jobID == "" then return end

	ply.MintyRP = ply.MintyRP or {}
	ply.MintyRP._lastJobSwitch = ply.MintyRP._lastJobSwitch or 0
	if CurTime() - ply.MintyRP._lastJobSwitch < 3 then return end
	ply.MintyRP._lastJobSwitch = CurTime()

	MintyRP.Economy.SetJob(ply, jobID)
end)

hook.Add("MintyRP_CharacterApplied", "MintyRP_EconomyLoadJob", function(ply)
	timer.Simple(0.1, function()
		if IsValid(ply) then
			MintyRP.Economy.LoadJob(ply)
		end
	end)
end)

timer.Create("MintyRP_Paychecks", 30, 0, function()
	local interval = MintyRP.Economy.PaycheckInterval or 300
	local now = os.time()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply.MintyRP and ply.MintyRP.Loaded and ply.MintyRP.characterId then
			local last = ply.MintyRP.lastPaycheck or 0
			if last == 0 then
				-- First paycheck after load starts the clock (no instant double-pay)
				ply.MintyRP.lastPaycheck = now
				sql.Query(string.format(
					"UPDATE mintyrp_characters SET last_paycheck = %d WHERE id = %d",
					now,
					tonumber(ply.MintyRP.characterId)
				))
			elseif now - last >= interval then
				MintyRP.Economy.Pay(ply)
			end
		end
	end
end)

concommand.Add("mintyrp_paycheck", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then
		MintyRP.Util.Notify(ply, "Admin only.", 3)
		return
	end
	if IsValid(ply) then
		MintyRP.Economy.Pay(ply)
	end
end)

print("[MintyRP] Economy server loaded")
