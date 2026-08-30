--[[-------------------------------------------------------------------------
	MintyRP — Starter tutorial (server)
	Realm: SERVER
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP = MintyRP or {}
MintyRP.Tutorial = MintyRP.Tutorial or {}

util.AddNetworkString("MintyRP_TutorialOpen")
util.AddNetworkString("MintyRP_TutorialComplete")
util.AddNetworkString("MintyRP_TutorialSkip")

local function CharID(ply)
	return ply.MintyRP and tonumber(ply.MintyRP.characterId)
end

local function HasCompleted(ply)
	local id = CharID(ply)
	if not id then return true end

	local row = sql.QueryRow("SELECT tutorial_done FROM mintyrp_characters WHERE id = " .. id)
	if not row then return false end
	return tonumber(row.tutorial_done) == 1
end

local function MarkComplete(ply)
	local id = CharID(ply)
	if not id then return end
	sql.Query("UPDATE mintyrp_characters SET tutorial_done = 1 WHERE id = " .. id)
	if ply.MintyRP then
		ply.MintyRP.tutorialDone = true
	end
end

function MintyRP.Tutorial.Offer(ply)
	if not IsValid(ply) then return end
	if not CharID(ply) then return end
	if HasCompleted(ply) then return end

	net.Start("MintyRP_TutorialOpen")
	net.Send(ply)
end

local function GrantStarter(ply)
	if not IsValid(ply) or not CharID(ply) then return false end
	if HasCompleted(ply) then return false end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return false end

	local amount = MintyRP.Tutorial.StarterCash or 20000

	-- Credit bank directly (Deposit requires pocket cash)
	if MintyRP.Bank and MintyRP.Bank.Credit then
		MintyRP.Bank.Credit(ply, amount)
	else
		ply.MintyRP.bank = math.floor((ply.MintyRP.bank or 0) + amount)
		MintyRP.Player.Save(ply)
		net.Start("MintyRP_BankSync")
			net.WriteUInt(math.floor(ply.MintyRP.money or 0), 32)
			net.WriteUInt(math.floor(ply.MintyRP.bank or 0), 32)
		net.Send(ply)
	end

	MarkComplete(ply)

	MintyRP.Util.Notify(ply, ("Tutorial complete — $%s deposited to your bank."):format(
		string.Comma(amount)
	), 0)

	print(("[MintyRP] Tutorial reward $%s → %s (char #%s)"):format(
		amount, ply:Nick(), tostring(CharID(ply))
	))

	return true
end

net.Receive("MintyRP_TutorialComplete", function(_, ply)
	if not IsValid(ply) then return end
	GrantStarter(ply)
end)

net.Receive("MintyRP_TutorialSkip", function(_, ply)
	if not IsValid(ply) then return end
	-- Skipping still grants starter cash once
	GrantStarter(ply)
end)

hook.Add("MintyRP_CharacterApplied", "MintyRP_TutorialOffer", function(ply)
	timer.Simple(1.2, function()
		if not IsValid(ply) then return end
		MintyRP.Tutorial.Offer(ply)
	end)
end)

concommand.Add("mintyrp_tutorial", function(ply)
	if not IsValid(ply) then return end
	net.Start("MintyRP_TutorialOpen")
	net.Send(ply)
end)

print("[MintyRP] Tutorial server loaded")
