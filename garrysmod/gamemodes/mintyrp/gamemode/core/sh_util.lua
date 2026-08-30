--[[-------------------------------------------------------------------------
	MintyRP — Shared utilities
	Realm: SHARED
---------------------------------------------------------------------------]]

MintyRP.Util = MintyRP.Util or {}

local Util = MintyRP.Util
local math_floor = math.floor
local math_Clamp = math.Clamp
local string_format = string.format
local IsValid = IsValid

function Util.FormatMoney(amount)
	amount = math_floor(tonumber(amount) or 0)
	local negative = amount < 0
	amount = math.abs(amount)

	local formatted = tostring(amount)
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end

	return (negative and "-$" or "$") .. formatted
end

function Util.ClampWeight(weight)
	return math_Clamp(tonumber(weight) or 0, 0, 9999)
end

--- Server → client notification helper (safe string length)
function Util.Notify(ply, message, ntype)
	if not SERVER then return end
	if not IsValid(ply) then return end

	message = tostring(message or "")
	if #message > 256 then
		message = string.sub(message, 1, 256)
	end

	ntype = math_Clamp(tonumber(ntype) or 0, 0, 7)

	net.Start("MintyRP_Notify")
		net.WriteString(message)
		net.WriteUInt(ntype, 3)
	net.Send(ply)
end

function Util.SteamID64(ply)
	if not IsValid(ply) then return nil end
	return ply:SteamID64()
end

print("[MintyRP] Util loaded")
