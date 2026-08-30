--[[-------------------------------------------------------------------------
	MintyRP — Economy / paychecks (client)
	Realm: CLIENT
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP = MintyRP or {}
MintyRP.Economy = MintyRP.Economy or {}

MintyRP.Economy.MyJob = MintyRP.Economy.MyJob or "unemployed"

net.Receive("MintyRP_JobSync", function()
	MintyRP.Economy.MyJob = net.ReadString() or "unemployed"
end)

net.Receive("MintyRP_Paycheck", function()
	local amount = net.ReadUInt(32)
	local jobName = net.ReadString()
	chat.AddText(
		Color(80, 200, 120), "[Paycheck] ",
		color_white, ("+$%s from %s (bank)"):format(string.Comma(amount), jobName)
	)
end)

function MintyRP.Economy.RequestJob(jobID)
	net.Start("MintyRP_SetJob")
		net.WriteString(jobID)
	net.SendToServer()
end

print("[MintyRP] Economy client loaded")
