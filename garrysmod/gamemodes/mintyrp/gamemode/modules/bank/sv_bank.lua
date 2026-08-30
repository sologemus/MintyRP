--[[-------------------------------------------------------------------------
	MintyRP — Bank tellers (YOU place them)
	Realm: SERVER

	No more guessing map coords. Tellers only spawn from
	data/mintyrp/teller_stations.json which you write with:

	  mintyrp_setteller              — place at your feet
	  mintyrp_setteller bank         — set/replace main bank desk
	  mintyrp_setteller gas1 Name    — set/replace a gas desk
	  mintyrp_removeteller           — remove nearest teller + save
	  mintyrp_listtellers            — print saved stations
	  mintyrp_cleartellers           — wipe all
	  mintyrp_respawntellers         — respawn from saved file only
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
local DATA_FILE = "mintyrp/teller_stations.json"

-- Named slots so you can replace without stacking duplicates
local SLOT_ALIASES = {
	bank = { id = "bank_main", name = "Rockford Bank" },
	bank_main = { id = "bank_main", name = "Rockford Bank" },
	spawn = { id = "spawn_kiosk", name = "City Spawn Kiosk" },
	spawn_kiosk = { id = "spawn_kiosk", name = "City Spawn Kiosk" },
	kiosk = { id = "spawn_kiosk", name = "City Spawn Kiosk" },
	gas = { id = "gas_1", name = "Gas Station Desk" },
	gas1 = { id = "gas_1", name = "Gas Station Desk 1" },
	gas2 = { id = "gas_2", name = "Gas Station Desk 2" },
	gas3 = { id = "gas_3", name = "Gas Station Desk 3" },
	gas_downtown = { id = "gas_1", name = "Downtown Gas Desk" },
	gas_industrial = { id = "gas_2", name = "Industrial Gas Desk" },
	gas_suburb = { id = "gas_3", name = "Suburban Gas Desk" },
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

function Bank.IsNearTeller(ply, dist)
	dist = dist or 220
	local d2 = dist * dist
	for _, ent in ipairs(ents.FindByClass("mintyrp_bank_npc")) do
		if IsValid(ent) and ent:GetPos():DistToSqr(ply:GetPos()) <= d2 then
			return true, ent
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
		MintyRP.Util.Notify(ply, "You need to be at a bank teller.", 2)
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
				id = s.id or ("teller_" .. i),
				name = s.name or "Bank Teller",
				pos = { x = pos.x or 0, y = pos.y or 0, z = pos.z or 0 },
				ang = { p = ang.p or 0, y = ang.y or 0, r = ang.r or 0 },
			}
		end
	end
	return out
end

function Bank.SaveStations()
	if not file.Exists("mintyrp", "DATA") then
		file.CreateDir("mintyrp")
	end
	local payload = toSaveTable(Bank.Stations)
	file.Write(DATA_FILE, util.TableToJSON(payload, true) or "[]")
	print("[MintyRP] Saved " .. #payload .. " teller station(s) → data/" .. DATA_FILE)
end

function Bank.LoadStations()
	if not file.Exists("mintyrp", "DATA") then
		file.CreateDir("mintyrp")
	end

	Bank.Stations = {}

	if not file.Exists(DATA_FILE, "DATA") then
		print("[MintyRP] No teller placements yet. Stand where you want one and run: mintyrp_setteller bank")
		return Bank.Stations
	end

	local raw = file.Read(DATA_FILE, "DATA") or ""
	local decoded = util.JSONToTable(raw)
	if type(decoded) ~= "table" or #decoded == 0 then
		print("[MintyRP] Teller file empty. Place with: mintyrp_setteller bank")
		return Bank.Stations
	end

	Bank.Stations = decoded
	print("[MintyRP] Loaded " .. #Bank.Stations .. " teller placement(s) from data/")
	return Bank.Stations
end

--- Exact feet position — do NOT snap/nudge (that was putting them wrong)
local function spawnOne(station)
	if not scripted_ents.GetStored("mintyrp_bank_npc") and not scripted_ents.Get("mintyrp_bank_npc") then
		print("[MintyRP] ERROR: mintyrp_bank_npc not registered")
		return nil
	end

	local ent = ents.Create("mintyrp_bank_npc")
	if not IsValid(ent) then return nil end

	local pos = station.pos
	if istable(pos) then
		pos = Vector(pos.x or pos[1] or 0, pos.y or pos[2] or 0, pos.z or pos[3] or 0)
	end
	local ang = station.ang or Angle(0, 0, 0)
	if istable(ang) and not ang.Yaw then
		ang = Angle(ang.p or ang[1] or 0, ang.y or ang[2] or 0, ang.r or ang[3] or 0)
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

function Bank.SpawnAllTellers()
	for _, ent in ipairs(ents.FindByClass("mintyrp_bank_npc")) do
		if IsValid(ent) and ent.MintyRP_AutoSpawn then
			ent:Remove()
		end
	end

	if not Bank.Stations then
		Bank.LoadStations()
	end

	local n = 0
	for i = 1, #(Bank.Stations or {}) do
		local ent = spawnOne(Bank.Stations[i])
		if IsValid(ent) then
			n = n + 1
			local s = Bank.Stations[i]
			print(string.format("[MintyRP] Teller '%s' [%s] at %.0f %.0f %.0f",
				s.name or "?", s.id or "?",
				(istable(s.pos) and s.pos.x) or s.pos.x,
				(istable(s.pos) and s.pos.y) or s.pos.y,
				(istable(s.pos) and s.pos.z) or s.pos.z
			))
		end
	end

	if n == 0 then
		print("[MintyRP] 0 tellers — place them yourself: mintyrp_setteller bank")
	else
		print("[MintyRP] Spawned " .. n .. " bank teller(s) from your placements")
	end
	return n
end

--- Kept for property-scan hook compatibility — does NOT invent positions
function Bank.ResolveFromMap()
	Bank.LoadStations()
	Bank.SpawnAllTellers()
	return #(Bank.Stations or {})
end

local function upsertStation(id, name, pos, yaw)
	Bank.Stations = Bank.Stations or {}
	local station = {
		id = id,
		name = name,
		pos = { x = pos.x, y = pos.y, z = pos.z },
		ang = { p = 0, y = yaw or 0, r = 0 },
	}

	local replaced = false
	for i = 1, #Bank.Stations do
		if Bank.Stations[i].id == id then
			Bank.Stations[i] = station
			replaced = true
			break
		end
	end
	if not replaced then
		Bank.Stations[#Bank.Stations + 1] = station
	end

	Bank.SaveStations()
	Bank.SpawnAllTellers()
	return station, replaced
end

local function nearestStationIndex(pos)
	local bestI, bestD
	for i = 1, #(Bank.Stations or {}) do
		local s = Bank.Stations[i]
		local sp = s.pos
		local v = istable(sp) and Vector(sp.x, sp.y, sp.z) or sp
		local d = pos:DistToSqr(v)
		if not bestD or d < bestD then
			bestD = d
			bestI = i
		end
	end
	return bestI, bestD
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
		if not IsValid(ply) or not ply.MintyRP or not ply.MintyRP.Loaded then return end
		if #(Bank.Stations or {}) == 0 then
			if ply:IsSuperAdmin() then
				MintyRP.Util.Notify(ply, "No bank tellers placed. Stand at the desk → mintyrp_setteller bank", 0)
			end
			return
		end
		if not Bank.IsNearTeller(ply, 1500) then
			MintyRP.Util.Notify(ply, "Bank tellers: look for green beacons (or mintyrp_tpteller).", 0)
		end
	end)
end)

--[[
	mintyrp_setteller [slot] [display name...]

	Examples (stand exactly where the NPC should stand):
	  mintyrp_setteller bank
	  mintyrp_setteller gas1
	  mintyrp_setteller gas2 Industrial Gas
	  mintyrp_setteller spawn
	  mintyrp_setteller My Custom Desk
]]
concommand.Add("mintyrp_setteller", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if not IsValid(ply) then
		print("mintyrp_setteller must be run in-game while standing at the spot")
		return
	end

	args = args or {}
	local slotKey = string.lower(tostring(args[1] or ""))
	local slot = SLOT_ALIASES[slotKey]

	local id, name
	if slot then
		id = slot.id
		name = table.concat(args, " ", 2)
		if name == "" then name = slot.name end
	else
		-- Freeform: entire args = display name, unique id
		name = table.concat(args, " ")
		if name == "" then name = "Bank Teller" end
		id = "teller_" .. tostring(os.time())
	end

	local pos = ply:GetPos()
	local yaw = ply:EyeAngles().y
	local station, replaced = upsertStation(id, name, pos, yaw)

	local msg = string.format("%s teller '%s' [%s] at your feet (yaw %.0f)",
		replaced and "Updated" or "Placed", station.name, station.id, yaw)
	MintyRP.Util.Notify(ply, msg, 1)
	print("[MintyRP] " .. msg)
end)

concommand.Add("mintyrp_removeteller", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if not IsValid(ply) then return end

	Bank.Stations = Bank.Stations or {}
	if #Bank.Stations == 0 then
		MintyRP.Util.Notify(ply, "No saved tellers.", 3)
		return
	end

	local idx = nearestStationIndex(ply:GetPos())
	if not idx then return end
	local removed = table.remove(Bank.Stations, idx)
	Bank.SaveStations()
	Bank.SpawnAllTellers()
	MintyRP.Util.Notify(ply, "Removed teller '" .. (removed.name or "?") .. "'", 0)
	print("[MintyRP] Removed teller " .. tostring(removed.id))
end)

concommand.Add("mintyrp_listtellers", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Bank.LoadStations()
	print("[MintyRP] === Teller placements (" .. #(Bank.Stations or {}) .. ") ===")
	for i = 1, #(Bank.Stations or {}) do
		local s = Bank.Stations[i]
		local p = s.pos or {}
		print(string.format("  %d) [%s] %s  @ %.0f %.0f %.0f",
			i, s.id or "?", s.name or "?", p.x or 0, p.y or 0, p.z or 0))
	end
	if IsValid(ply) then
		MintyRP.Util.Notify(ply, #(Bank.Stations or {}) .. " teller(s) — see console", 0)
	end
end)

concommand.Add("mintyrp_cleartellers", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Bank.Stations = {}
	Bank.SaveStations()
	Bank.SpawnAllTellers()
	if IsValid(ply) then
		MintyRP.Util.Notify(ply, "All tellers cleared. Place with mintyrp_setteller bank", 0)
	end
	print("[MintyRP] All teller placements cleared")
end)

concommand.Add("mintyrp_tpteller", function(ply)
	if not IsValid(ply) then return end
	if not ply:IsSuperAdmin() and not (ply.MintyRP and ply.MintyRP.Loaded) then return end

	local best, bestD
	for _, ent in ipairs(ents.FindByClass("mintyrp_bank_npc")) do
		if IsValid(ent) then
			local d = ply:GetPos():DistToSqr(ent:GetPos())
			if not bestD or d < bestD then
				bestD = d
				best = ent
			end
		end
	end
	if not IsValid(best) then
		MintyRP.Util.Notify(ply, "No tellers placed. Superadmin: mintyrp_setteller bank", 3)
		return
	end
	ply:SetPos(best:GetPos() + best:GetForward() * 60 + Vector(0, 0, 8))
	MintyRP.Util.Notify(ply, "Teleported to " .. best:GetNWString("MintyRP_NPCName", "teller"), 0)
end)

concommand.Add("mintyrp_respawntellers", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Bank.LoadStations()
	Bank.SpawnAllTellers()
	if IsValid(ply) then
		MintyRP.Util.Notify(ply, "Respawned " .. #(Bank.Stations or {}) .. " teller(s) from save.", 0)
	end
end)

print("[MintyRP] Bank server loaded (manual teller placement)")
