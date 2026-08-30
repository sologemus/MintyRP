--[[-------------------------------------------------------------------------
	MintyRP — Bank tellers + ATMs (manual placement)
	Realm: SERVER

	Tellers (NPC): bank lobby — mintyrp_setteller bank
	ATMs (machine): gas stations / streets — mintyrp_setatm gas1

	Saved separately:
	  data/mintyrp/teller_stations.json
	  data/mintyrp/atm_stations.json
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Bank = MintyRP.Bank or {}

local Bank = MintyRP.Bank
local IsValid = IsValid
local math_floor = math.floor
local CurTime = CurTime
local file = file
local util = util

local MAX_BITS = 512
local RATE = 0.35
local MAX_TX = 10000000
local TELLER_FILE = "mintyrp/teller_stations.json"
local ATM_FILE = "mintyrp/atm_stations.json"

local TELLER_SLOTS = {
	bank = { id = "bank_main", name = "Rockford Bank" },
	bank_main = { id = "bank_main", name = "Rockford Bank" },
	spawn = { id = "spawn_kiosk", name = "City Spawn Kiosk" },
	spawn_kiosk = { id = "spawn_kiosk", name = "City Spawn Kiosk" },
	kiosk = { id = "spawn_kiosk", name = "City Spawn Kiosk" },
}

local ATM_SLOTS = {
	gas = { id = "atm_gas_1", name = "Gas Station ATM" },
	gas1 = { id = "atm_gas_1", name = "Gas Station ATM 1" },
	gas2 = { id = "atm_gas_2", name = "Gas Station ATM 2" },
	gas3 = { id = "atm_gas_3", name = "Gas Station ATM 3" },
	gas_downtown = { id = "atm_gas_1", name = "Downtown Gas ATM" },
	gas_industrial = { id = "atm_gas_2", name = "Industrial Gas ATM" },
	gas_suburb = { id = "atm_gas_3", name = "Suburban Gas ATM" },
	street = { id = "atm_street", name = "Street ATM" },
	atm = { id = "atm_1", name = "ATM" },
}

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

function Bank.Credit(ply, amount)
	amount = math_floor(tonumber(amount) or 0)
	if amount < 1 or amount > MAX_TX then return false, "amount" end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return false, "loaded" end

	ply.MintyRP.bank = math_floor((ply.MintyRP.bank or 0) + amount)
	MintyRP.Player.Save(ply)
	syncMoney(ply)
	return true
end

--- Near a teller NPC or an ATM
function Bank.IsNearTeller(ply, dist)
	dist = dist or 220
	local d2 = dist * dist
	local pos = ply:GetPos()
	for _, class in ipairs({ "mintyrp_bank_npc", "mintyrp_atm" }) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if IsValid(ent) and ent:GetPos():DistToSqr(pos) <= d2 then
				return true, ent
			end
		end
	end
	return false
end

net.Receive("MintyRP_BankAction", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if len > MAX_BITS then return end
	if rateLimited(ply) then return end
	if not ply.MintyRP or not ply.MintyRP.Loaded then return end

	if not Bank.IsNearTeller(ply) then
		MintyRP.Util.Notify(ply, "You need to be at a bank teller or ATM.", 2)
		return
	end

	local action = net.ReadUInt(2)
	local amount = net.ReadUInt(32)

	if action == 1 then
		local ok, err = Bank.Deposit(ply, amount)
		if ok then
			MintyRP.Util.Notify(ply, "Deposited $" .. amount .. ".", 1)
		else
			MintyRP.Util.Notify(ply, ({ money = "Not enough cash.", amount = "Invalid amount." })[err] or "Deposit failed.", 3)
		end
	elseif action == 2 then
		local ok, err = Bank.Withdraw(ply, amount)
		if ok then
			MintyRP.Util.Notify(ply, "Withdrew $" .. amount .. ".", 1)
		else
			MintyRP.Util.Notify(ply, ({ bank = "Not enough in bank.", amount = "Invalid amount." })[err] or "Withdraw failed.", 3)
		end
	end
end)

local function toSaveTable(stations)
	local out = {}
	for i = 1, #(stations or {}) do
		local s = stations[i]
		if s and s.pos then
			local pos = s.pos
			local ang = s.ang or { p = 0, y = 0, r = 0 }
			if not istable(pos) then
				pos = { x = pos.x, y = pos.y, z = pos.z }
			end
			if not istable(ang) or ang.Yaw then
				ang = { p = ang.p or 0, y = ang.y or ang.Yaw or 0, r = ang.r or 0 }
			end
			out[#out + 1] = {
				id = s.id or ("station_" .. i),
				name = s.name or "Station",
				pos = { x = pos.x or 0, y = pos.y or 0, z = pos.z or 0 },
				ang = { p = ang.p or 0, y = ang.y or 0, r = ang.r or 0 },
			}
		end
	end
	return out
end

local function saveFile(path, stations)
	if not file.Exists("mintyrp", "DATA") then file.CreateDir("mintyrp") end
	local payload = toSaveTable(stations)
	file.Write(path, util.TableToJSON(payload, true) or "[]")
	return #payload
end

local function loadFile(path)
	if not file.Exists(path, "DATA") then return {} end
	local decoded = util.JSONToTable(file.Read(path, "DATA") or "")
	if type(decoded) ~= "table" then return {} end
	return decoded
end

function Bank.LoadStations()
	Bank.Stations = loadFile(TELLER_FILE) -- tellers only
	Bank.ATMStations = loadFile(ATM_FILE)

	-- One-time migrate: old gas_* teller slots → ATM file
	local migrated = false
	local kept = {}
	for i = 1, #Bank.Stations do
		local s = Bank.Stations[i]
		local id = tostring(s.id or "")
		if string.StartWith(id, "gas_") or id == "gas_auto" then
			s.id = "atm_" .. id
			if not string.find(string.lower(s.name or ""), "atm", 1, true) then
				s.name = (s.name or "Gas") .. " ATM"
			end
			Bank.ATMStations[#Bank.ATMStations + 1] = s
			migrated = true
		else
			kept[#kept + 1] = s
		end
	end
	if migrated then
		Bank.Stations = kept
		saveFile(TELLER_FILE, Bank.Stations)
		saveFile(ATM_FILE, Bank.ATMStations)
		print("[MintyRP] Migrated old gas tellers → ATM placements")
	end

	print(string.format("[MintyRP] Loaded %d teller(s), %d ATM(s)", #Bank.Stations, #Bank.ATMStations))
end

function Bank.SaveStations()
	saveFile(TELLER_FILE, Bank.Stations or {})
end

function Bank.SaveATMs()
	saveFile(ATM_FILE, Bank.ATMStations or {})
end

local function spawnTeller(station)
	local ent = ents.Create("mintyrp_bank_npc")
	if not IsValid(ent) then return nil end
	local pos = station.pos
	if istable(pos) then pos = Vector(pos.x or 0, pos.y or 0, pos.z or 0) end
	local ang = station.ang or Angle(0, 0, 0)
	if istable(ang) and not ang.Yaw then
		ang = Angle(ang.p or 0, ang.y or 0, ang.r or 0)
	end
	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent.MintyRP_AutoSpawn = true
	ent.MintyRP_StationId = station.id
	ent:Spawn()
	ent:Activate()
	ent:SetNWString("MintyRP_NPCName", station.name or "Bank Teller")
	ent:SetNWBool("MintyRP_Beacon", true)
	return ent
end

local function spawnATM(station)
	local ent = ents.Create("mintyrp_atm")
	if not IsValid(ent) then return nil end
	local pos = station.pos
	if istable(pos) then pos = Vector(pos.x or 0, pos.y or 0, pos.z or 0) end
	local ang = station.ang or Angle(0, 0, 0)
	if istable(ang) and not ang.Yaw then
		ang = Angle(ang.p or 0, ang.y or 0, ang.r or 0)
	end
	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent.MintyRP_AutoSpawn = true
	ent.MintyRP_StationId = station.id
	ent:Spawn()
	ent:Activate()
	ent:SetNWString("MintyRP_ATMName", station.name or "ATM")
	ent:SetNWBool("MintyRP_Beacon", true)
	return ent
end

function Bank.SpawnAllTellers()
	for _, ent in ipairs(ents.FindByClass("mintyrp_bank_npc")) do
		if IsValid(ent) and ent.MintyRP_AutoSpawn then ent:Remove() end
	end
	for _, ent in ipairs(ents.FindByClass("mintyrp_atm")) do
		if IsValid(ent) and ent.MintyRP_AutoSpawn then ent:Remove() end
	end

	if not Bank.Stations or not Bank.ATMStations then
		Bank.LoadStations()
	end

	local nt, na = 0, 0
	for i = 1, #(Bank.Stations or {}) do
		if IsValid(spawnTeller(Bank.Stations[i])) then nt = nt + 1 end
	end
	for i = 1, #(Bank.ATMStations or {}) do
		if IsValid(spawnATM(Bank.ATMStations[i])) then na = na + 1 end
	end

	print(string.format("[MintyRP] Spawned %d teller(s), %d ATM(s)", nt, na))
	if nt + na == 0 then
		print("[MintyRP] Place tellers: mintyrp_setteller bank | Place ATMs: mintyrp_setatm gas1")
	end
	return nt + na
end

function Bank.ResolveFromMap()
	Bank.LoadStations()
	Bank.SpawnAllTellers()
	return #(Bank.Stations or {}) + #(Bank.ATMStations or {})
end

local function upsert(list, id, name, pos, yaw)
	local station = {
		id = id,
		name = name,
		pos = { x = pos.x, y = pos.y, z = pos.z },
		ang = { p = 0, y = yaw or 0, r = 0 },
	}
	local replaced = false
	for i = 1, #list do
		if list[i].id == id then
			list[i] = station
			replaced = true
			break
		end
	end
	if not replaced then list[#list + 1] = station end
	return station, replaced
end

hook.Add("InitPostEntity", "MintyRP_BankSpawn", function()
	timer.Simple(2, function()
		Bank.LoadStations()
		Bank.SpawnAllTellers()
	end)
end)

hook.Add("PostCleanupMap", "MintyRP_BankRespawn", function()
	timer.Simple(1, function()
		Bank.LoadStations()
		Bank.SpawnAllTellers()
	end)
end)

hook.Add("MintyRP_CharacterApplied", "MintyRP_BankHint", function(ply)
	timer.Simple(2.5, function()
		if not IsValid(ply) or not ply:IsSuperAdmin() then return end
		local t = #(Bank.Stations or {})
		local a = #(Bank.ATMStations or {})
		if t == 0 and a == 0 then
			MintyRP.Util.Notify(ply, "No bank access placed. mintyrp_setteller bank  |  mintyrp_setatm gas1", 0)
		end
	end)
end)

concommand.Add("mintyrp_setteller", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if not IsValid(ply) then
		print("mintyrp_setteller must be run in-game")
		return
	end

	args = args or {}
	local slotKey = string.lower(tostring(args[1] or ""))

	-- Gas stations are ATMs, not tellers
	if ATM_SLOTS[slotKey] or string.StartWith(slotKey, "gas") then
		MintyRP.Util.Notify(ply, "Gas stations use ATMs — run: mintyrp_setatm " .. (slotKey ~= "" and slotKey or "gas1"), 2)
		return
	end

	local slot = TELLER_SLOTS[slotKey]
	local id, name
	if slot then
		id = slot.id
		name = table.concat(args, " ", 2)
		if name == "" then name = slot.name end
	else
		name = table.concat(args, " ")
		if name == "" then name = "Bank Teller" end
		id = "teller_" .. tostring(os.time())
	end

	Bank.Stations = Bank.Stations or {}
	local station, replaced = upsert(Bank.Stations, id, name, ply:GetPos(), ply:EyeAngles().y)
	Bank.SaveStations()
	Bank.SpawnAllTellers()
	MintyRP.Util.Notify(ply, (replaced and "Updated" or "Placed") .. " teller '" .. station.name .. "'", 1)
end)

concommand.Add("mintyrp_setatm", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if not IsValid(ply) then
		print("mintyrp_setatm must be run in-game")
		return
	end

	args = args or {}
	local slotKey = string.lower(tostring(args[1] or "atm"))
	local slot = ATM_SLOTS[slotKey]
	local id, name
	if slot then
		id = slot.id
		name = table.concat(args, " ", 2)
		if name == "" then name = slot.name end
	else
		name = table.concat(args, " ")
		if name == "" then name = "ATM" end
		id = "atm_" .. tostring(os.time())
	end

	Bank.ATMStations = Bank.ATMStations or {}
	local station, replaced = upsert(Bank.ATMStations, id, name, ply:GetPos(), ply:EyeAngles().y)
	Bank.SaveATMs()
	Bank.SpawnAllTellers()
	MintyRP.Util.Notify(ply, (replaced and "Updated" or "Placed") .. " ATM '" .. station.name .. "'", 1)
	print("[MintyRP] ATM " .. station.id .. " at feet of " .. ply:Nick())
end)

concommand.Add("mintyrp_removeteller", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if not IsValid(ply) then return end
	Bank.Stations = Bank.Stations or {}
	if #Bank.Stations == 0 then
		MintyRP.Util.Notify(ply, "No tellers. Use mintyrp_removeatm for ATMs.", 3)
		return
	end
	local bestI, bestD
	for i = 1, #Bank.Stations do
		local p = Bank.Stations[i].pos
		local d = ply:GetPos():DistToSqr(Vector(p.x, p.y, p.z))
		if not bestD or d < bestD then bestD, bestI = d, i end
	end
	local removed = table.remove(Bank.Stations, bestI)
	Bank.SaveStations()
	Bank.SpawnAllTellers()
	MintyRP.Util.Notify(ply, "Removed teller '" .. (removed.name or "?") .. "'", 0)
end)

concommand.Add("mintyrp_removeatm", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if not IsValid(ply) then return end
	Bank.ATMStations = Bank.ATMStations or {}
	if #Bank.ATMStations == 0 then
		MintyRP.Util.Notify(ply, "No ATMs saved.", 3)
		return
	end
	local bestI, bestD
	for i = 1, #Bank.ATMStations do
		local p = Bank.ATMStations[i].pos
		local d = ply:GetPos():DistToSqr(Vector(p.x, p.y, p.z))
		if not bestD or d < bestD then bestD, bestI = d, i end
	end
	local removed = table.remove(Bank.ATMStations, bestI)
	Bank.SaveATMs()
	Bank.SpawnAllTellers()
	MintyRP.Util.Notify(ply, "Removed ATM '" .. (removed.name or "?") .. "'", 0)
end)

concommand.Add("mintyrp_listtellers", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Bank.LoadStations()
	print("[MintyRP] === Tellers ===")
	for i, s in ipairs(Bank.Stations or {}) do
		print(string.format("  %d) [%s] %s", i, s.id, s.name))
	end
	print("[MintyRP] === ATMs ===")
	for i, s in ipairs(Bank.ATMStations or {}) do
		print(string.format("  %d) [%s] %s", i, s.id, s.name))
	end
	if IsValid(ply) then
		MintyRP.Util.Notify(ply, string.format("%d teller(s), %d ATM(s)", #(Bank.Stations or {}), #(Bank.ATMStations or {})), 0)
	end
end)

concommand.Add("mintyrp_cleartellers", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Bank.Stations = {}
	Bank.SaveStations()
	Bank.SpawnAllTellers()
	if IsValid(ply) then MintyRP.Util.Notify(ply, "Tellers cleared (ATMs kept).", 0) end
end)

concommand.Add("mintyrp_clearatms", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Bank.ATMStations = {}
	Bank.SaveATMs()
	Bank.SpawnAllTellers()
	if IsValid(ply) then MintyRP.Util.Notify(ply, "ATMs cleared.", 0) end
end)

concommand.Add("mintyrp_tpteller", function(ply)
	if not IsValid(ply) then return end
	if not ply:IsSuperAdmin() and not (ply.MintyRP and ply.MintyRP.Loaded) then return end
	local best, bestD
	for _, class in ipairs({ "mintyrp_bank_npc", "mintyrp_atm" }) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if IsValid(ent) then
				local d = ply:GetPos():DistToSqr(ent:GetPos())
				if not bestD or d < bestD then bestD, best = d, ent end
			end
		end
	end
	if not IsValid(best) then
		MintyRP.Util.Notify(ply, "None placed. mintyrp_setteller bank / mintyrp_setatm gas1", 3)
		return
	end
	ply:SetPos(best:GetPos() + best:GetForward() * 50 + Vector(0, 0, 8))
	local label = best:GetClass() == "mintyrp_atm"
		and best:GetNWString("MintyRP_ATMName", "ATM")
		or best:GetNWString("MintyRP_NPCName", "teller")
	MintyRP.Util.Notify(ply, "Teleported to " .. label, 0)
end)

concommand.Add("mintyrp_respawntellers", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Bank.LoadStations()
	Bank.SpawnAllTellers()
end)

print("[MintyRP] Bank server loaded (tellers + ATMs)")
