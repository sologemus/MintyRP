--[[-------------------------------------------------------------------------
	MintyRP — Bank tellers (multi-station) + persistent placements
	Realm: SERVER
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

--- Add money straight to bank (paychecks, tutorial) — does not take pocket cash
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

function Bank.LoadStations()
	if not file.Exists("mintyrp", "DATA") then
		file.CreateDir("mintyrp")
	end

	if file.Exists(DATA_FILE, "DATA") then
		local raw = file.Read(DATA_FILE, "DATA") or ""
		local decoded = util.JSONToTable(raw)
		if type(decoded) == "table" and #decoded > 0 then
			Bank.Stations = decoded
			-- Always keep a spawn kiosk so new players can find a teller
			local hasSpawn = false
			for i = 1, #Bank.Stations do
				if Bank.Stations[i].id == "spawn_kiosk" then
					hasSpawn = true
					break
				end
			end
			if not hasSpawn and Bank.DefaultStations then
				table.insert(Bank.Stations, 1, table.Copy(Bank.DefaultStations[1]))
			end
			print("[MintyRP] Loaded " .. #Bank.Stations .. " teller stations from data/")
			return
		end
	end

	Bank.Stations = table.Copy(Bank.DefaultStations or {})
	print("[MintyRP] Using default teller stations (" .. #Bank.Stations .. ")")
end

function Bank.SaveStations()
	if not file.Exists("mintyrp", "DATA") then
		file.CreateDir("mintyrp")
	end
	file.Write(DATA_FILE, util.TableToJSON(Bank.Stations or {}, true) or "[]")
end

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

	-- Drop to ground so they aren't buried/floating from bad Z
	local tr = util.TraceLine({
		start = pos + Vector(0, 0, 64),
		endpos = pos - Vector(0, 0, 256),
		mask = MASK_SOLID_BRUSHONLY,
	})
	if tr.Hit then
		pos = tr.HitPos + Vector(0, 0, 2)
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
			print(string.format("[MintyRP] Teller '%s' at %s", Bank.Stations[i].name or "?", tostring(ent:GetPos())))
		end
	end
	print("[MintyRP] Spawned " .. n .. " bank tellers")
	return n
end

local function ensureTellers()
	timer.Simple(2, function()
		local expected = #(Bank.Stations or Bank.DefaultStations or {})
		local count = 0
		for _, ent in ipairs(ents.FindByClass("mintyrp_bank_npc")) do
			if IsValid(ent) then count = count + 1 end
		end
		if count < math.max(1, expected) then
			Bank.LoadStations()
			Bank.SpawnAllTellers()
		end
	end)
end

hook.Add("InitPostEntity", "MintyRP_BankSpawn", function()
	Bank.LoadStations()
	timer.Simple(1, Bank.SpawnAllTellers)
end)
hook.Add("PostCleanupMap", "MintyRP_BankRespawn", function()
	timer.Simple(1, Bank.SpawnAllTellers)
end)
hook.Add("PlayerInitialSpawn", "MintyRP_BankEnsure", ensureTellers)

-- After character select, tip player toward nearest teller if far away
hook.Add("MintyRP_CharacterApplied", "MintyRP_BankHint", function(ply)
	timer.Simple(2.5, function()
		if not IsValid(ply) or not ply.MintyRP or not ply.MintyRP.Loaded then return end
		local near = Bank.IsNearTeller(ply, 1200)
		if near then return end
		MintyRP.Util.Notify(ply, "No teller nearby — type mintyrp_tpteller or look for the green beacon at spawn.", 0)
	end)
end)

-- Admin: place teller at your feet and save
concommand.Add("mintyrp_setteller", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if not IsValid(ply) then
		print("mintyrp_setteller must be run by a player in-game")
		return
	end

	local name = table.concat(args or {}, " ")
	if name == "" then name = "Bank Teller" end
	local id = "custom_" .. tostring(os.time())

	Bank.Stations = Bank.Stations or {}
	local station = {
		id = id,
		name = name,
		pos = { x = ply:GetPos().x, y = ply:GetPos().y, z = ply:GetPos().z },
		ang = { p = 0, y = ply:EyeAngles().y, r = 0 },
	}
	Bank.Stations[#Bank.Stations + 1] = station
	Bank.SaveStations()

	local ent = spawnOne({
		id = id,
		name = name,
		pos = ply:GetPos(),
		ang = Angle(0, ply:EyeAngles().y, 0),
	})
	MintyRP.Util.Notify(ply, "Teller saved: " .. name, 1)
	print("[MintyRP] Saved teller '" .. name .. "' — total stations " .. #Bank.Stations)
end)

concommand.Add("mintyrp_cleartellers", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Bank.Stations = table.Copy(Bank.DefaultStations or {})
	Bank.SaveStations()
	Bank.SpawnAllTellers()
	if IsValid(ply) then MintyRP.Util.Notify(ply, "Tellers reset to defaults.", 0) end
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
		MintyRP.Util.Notify(ply, "No tellers spawned.", 3)
		return
	end
	ply:SetPos(best:GetPos() + best:GetForward() * 60 + Vector(0, 0, 8))
	MintyRP.Util.Notify(ply, "Teleported to " .. best:GetNWString("MintyRP_NPCName", "teller"), 0)
end)

concommand.Add("mintyrp_respawntellers", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Bank.SpawnAllTellers()
end)

print("[MintyRP] Bank server loaded")
