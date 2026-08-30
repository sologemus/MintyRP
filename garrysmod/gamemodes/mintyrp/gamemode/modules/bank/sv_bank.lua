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

local function posValid(pos)
	if not pos then return false end
	local contents = util.PointContents(pos + Vector(0, 0, 36))
	if bit.band(contents, CONTENTS_SOLID) ~= 0 then return false end
	return true
end

local function groundPos(pos)
	local tr = util.TraceLine({
		start = pos + Vector(0, 0, 128),
		endpos = pos - Vector(0, 0, 512),
		mask = MASK_SOLID_BRUSHONLY,
	})
	if tr.Hit then
		return tr.HitPos + Vector(0, 0, 2)
	end
	return pos
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

	pos = groundPos(pos)
	if not posValid(pos) then
		-- Nudge sideways and retry ground
		for _, off in ipairs({ Vector(64, 0, 0), Vector(-64, 0, 0), Vector(0, 64, 0), Vector(0, -64, 0), Vector(96, 96, 0) }) do
			local try = groundPos(pos + off)
			if posValid(try) then
				pos = try
				break
			end
		end
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

local function avgDoorPos(propertyId)
	local Prop = MintyRP.Property
	if not Prop or not Prop.State or not Prop.State[propertyId] then return nil end
	local doors = Prop.State[propertyId].doors
	if not doors or #doors == 0 then return nil, nil end

	local avg = Vector(0, 0, 0)
	local ang = Angle(0, 0, 0)
	for i = 1, #doors do
		if IsValid(doors[i]) then
			avg = avg + doors[i]:GetPos()
			ang = doors[i]:GetAngles()
		end
	end
	avg = avg / #doors
	-- Stand in front of the door (outside)
	local front = avg + ang:Forward() * 56 + Vector(0, 0, 2)
	return front, Angle(0, ang.y + 180, 0)
end

local function findSpawnPos()
	local starts = ents.FindByClass("info_player_start")
	if #starts == 0 then
		starts = ents.FindByClass("info_player_deathmatch")
	end
	if #starts > 0 and IsValid(starts[1]) then
		local e = starts[1]
		local pos = e:GetPos() + e:GetForward() * 80 + e:GetRight() * 40
		return groundPos(pos), Angle(0, e:GetAngles().y + 180, 0)
	end
	if MintyRP.Locations and MintyRP.Locations.GetDefaultSpawn then
		local sp = MintyRP.Locations.GetDefaultSpawn()
		if sp and sp.pos then
			return groundPos(sp.pos + Vector(60, 40, 0)), sp.ang or Angle(0, 90, 0)
		end
	end
	return nil, nil
end

local function findNamedDoorPos(patterns)
	local doors = ents.FindByClass("prop_door_rotating")
	table.Add(doors, ents.FindByClass("func_door"))
	table.Add(doors, ents.FindByClass("func_door_rotating"))
	for i = 1, #doors do
		local d = doors[i]
		if IsValid(d) then
			local n = string.lower(d:GetName() or "")
			for _, pat in ipairs(patterns) do
				if n ~= "" and string.find(n, pat, 1, true) then
					local ang = d:GetAngles()
					return groundPos(d:GetPos() + ang:Forward() * 56), Angle(0, ang.y + 180, 0)
				end
			end
		end
	end
	return nil, nil
end

--- Build stations from real map doors / spawn entities (not placeholders)
function Bank.ResolveFromMap()
	local stations = {}
	local custom = {}

	-- Keep admin-placed custom_* stations from disk
	if file.Exists(DATA_FILE, "DATA") then
		local decoded = util.JSONToTable(file.Read(DATA_FILE, "DATA") or "")
		if type(decoded) == "table" then
			for i = 1, #decoded do
				local s = decoded[i]
				if s and type(s.id) == "string" and string.StartWith(s.id, "custom_") then
					custom[#custom + 1] = s
				end
			end
		end
	end

	local function add(id, name, pos, ang)
		if not pos then return false end
		stations[#stations + 1] = {
			id = id,
			name = name,
			pos = { x = pos.x, y = pos.y, z = pos.z },
			ang = { p = ang and ang.p or 0, y = ang and ang.y or 0, r = 0 },
		}
		return true
	end

	-- 1) Always: civilian spawn kiosk
	local spawnPos, spawnAng = findSpawnPos()
	if spawnPos then
		add("spawn_kiosk", "City Spawn Kiosk", spawnPos, spawnAng)
	end

	-- 2) Bank from linked doors, else name search
	local bankPos, bankAng = avgDoorPos("city_bank")
	if not bankPos then
		bankPos, bankAng = findNamedDoorPos({ "bank", "vault" })
	end
	if bankPos then
		add("bank_main", "Rockford Bank", bankPos, bankAng)
	end

	-- 3) Gas desks from franchise props / names
	local gasSpecs = {
		{ id = "gas_downtown", name = "Downtown Gas Desk", prop = "fran_gas_downtown" },
		{ id = "gas_industrial", name = "Industrial Gas Desk", prop = "fran_gas_industrial" },
		{ id = "gas_suburb", name = "Suburban Gas Desk", prop = "fran_gas_suburb" },
	}
	local gasFound = 0
	for _, g in ipairs(gasSpecs) do
		local pos, ang = avgDoorPos(g.prop)
		if pos then
			add(g.id, g.name, pos, ang)
			gasFound = gasFound + 1
		end
	end
	if gasFound == 0 then
		-- Fallback: any door named gas/fuel — one desk is better than none
		local pos, ang = findNamedDoorPos({ "gas", "fuel", "petrol", "station" })
		if pos then
			add("gas_auto", "Gas Station Desk", pos, ang)
		end
	end

	-- Append customs
	for i = 1, #custom do
		stations[#stations + 1] = custom[i]
	end

	if #stations == 0 then
		print("[MintyRP] WARNING: no teller stations resolved — using defaults")
		Bank.Stations = table.Copy(Bank.DefaultStations or {})
	else
		Bank.Stations = stations
		print(string.format("[MintyRP] Resolved %d teller stations from map (custom=%d)", #stations, #custom))
	end

	Bank.SpawnAllTellers()
	return #Bank.Stations
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
	timer.Simple(4, function()
		local count = 0
		for _, ent in ipairs(ents.FindByClass("mintyrp_bank_npc")) do
			if IsValid(ent) then count = count + 1 end
		end
		if count < 1 then
			Bank.ResolveFromMap()
		end
	end)
end

-- Property scan calls ResolveFromMap; early spawn only as safety net
hook.Add("InitPostEntity", "MintyRP_BankSpawn", function()
	timer.Simple(5, function()
		local count = 0
		for _, ent in ipairs(ents.FindByClass("mintyrp_bank_npc")) do
			if IsValid(ent) then count = count + 1 end
		end
		if count < 1 then
			Bank.ResolveFromMap()
		end
	end)
end)
hook.Add("PostCleanupMap", "MintyRP_BankRespawn", function()
	timer.Simple(3, function()
		Bank.ResolveFromMap()
	end)
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

	-- Persist only custom stations + current resolved ones? Save customs to file.
	local toSave = {}
	for i = 1, #Bank.Stations do
		local s = Bank.Stations[i]
		if s and type(s.id) == "string" and string.StartWith(s.id, "custom_") then
			toSave[#toSave + 1] = s
		end
	end
	if not file.Exists("mintyrp", "DATA") then file.CreateDir("mintyrp") end
	file.Write(DATA_FILE, util.TableToJSON(toSave, true) or "[]")

	spawnOne({
		id = id,
		name = name,
		pos = ply:GetPos(),
		ang = Angle(0, ply:EyeAngles().y, 0),
	})
	MintyRP.Util.Notify(ply, "Teller saved: " .. name, 1)
	print("[MintyRP] Saved teller '" .. name .. "'")
end)

concommand.Add("mintyrp_cleartellers", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	if file.Exists(DATA_FILE, "DATA") then
		file.Write(DATA_FILE, "[]")
	end
	Bank.ResolveFromMap()
	if IsValid(ply) then MintyRP.Util.Notify(ply, "Tellers re-resolved from map.", 0) end
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
	Bank.ResolveFromMap()
end)

print("[MintyRP] Bank server loaded")
