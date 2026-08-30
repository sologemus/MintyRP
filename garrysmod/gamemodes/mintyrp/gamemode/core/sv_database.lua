--[[-------------------------------------------------------------------------
	MintyRP — SQLite persistence layer
	Realm: SERVER

	Schema v3: accounts + multi-character slots + per-character inventory.
	All values escaped via sql.SQLStr — never concatenate raw client input.
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Database = MintyRP.Database or {}

local DB = MintyRP.Database
local sql_Query = sql.Query
local sql_SQLStr = sql.SQLStr
local sql_QueryValue = sql.QueryValue
local tonumber = tonumber
local tostring = tostring
local print = print
local string_format = string.format
local type = type
local pairs = pairs

local SCHEMA_VERSION = 3

local function sid(steamid64)
	if steamid64 == nil then return nil end
	return tostring(steamid64)
end

local function sqlErr()
	return (sql.LastError and sql.LastError()) or ""
end

local function clearSqlErr()
	-- Successful no-op query to avoid sticky LastError confusing later checks
	sql_Query("SELECT 1")
end

local function tableColumns(tableName)
	local rows = sql_Query("PRAGMA table_info(" .. tableName .. ")")
	local set = {}
	if type(rows) ~= "table" then return set end
	for i = 1, #rows do
		set[rows[i].name] = true
	end
	return set
end

local function hasColumn(tableName, column)
	return tableColumns(tableName)[column] == true
end

function DB.Initialize()
	sql_Query([[
		CREATE TABLE IF NOT EXISTS mintyrp_meta (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL
		);
	]])

	DB.EnsureSchema()
	DB.Migrate()

	sql_Query("INSERT OR REPLACE INTO mintyrp_meta (key, value) VALUES ('schema_version', "
		.. sql_SQLStr(tostring(SCHEMA_VERSION)) .. ")")

	local err = sqlErr()
	if err ~= "" then
		print("[MintyRP] Database warning after init: " .. tostring(err))
	else
		print("[MintyRP] SQLite database ready (schema v" .. SCHEMA_VERSION .. ")")
	end

	DB._ready = true
end

--- Create / repair tables so CREATE IF NOT EXISTS leftovers can't block inserts
function DB.EnsureSchema()
	-- Accounts
	if not hasColumn("mintyrp_players", "steamid64") then
		sql_Query([[
			CREATE TABLE IF NOT EXISTS mintyrp_players (
				steamid64 TEXT PRIMARY KEY,
				last_character_id INTEGER,
				created_at INTEGER NOT NULL,
				updated_at INTEGER NOT NULL
			);
		]])
	elseif hasColumn("mintyrp_players", "money") and not hasColumn("mintyrp_players", "last_character_id") then
		-- v1 account table still present; Migrate() will rebuild
		print("[MintyRP] Detected v1 players table — will migrate")
	end

	-- Characters
	local charCols = tableColumns("mintyrp_characters")
	local charsOk = charCols.id and charCols.steamid64 and charCols.slot
		and charCols.name and charCols.model and charCols.money
		and charCols.bank and charCols.data

	if not charsOk then
		if charCols.steamid64 then
			print("[MintyRP] Rebuilding mintyrp_characters (schema mismatch)")
			sql_Query("DROP TABLE IF EXISTS mintyrp_characters")
		end
		sql_Query([[
			CREATE TABLE IF NOT EXISTS mintyrp_characters (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				steamid64 TEXT NOT NULL,
				slot INTEGER NOT NULL,
				name TEXT NOT NULL,
				model TEXT NOT NULL,
				money INTEGER NOT NULL DEFAULT 500,
				bank INTEGER NOT NULL DEFAULT 0,
				data TEXT NOT NULL DEFAULT '{}',
				created_at INTEGER NOT NULL,
				updated_at INTEGER NOT NULL,
				UNIQUE(steamid64, slot)
			);
		]])
	end

	sql_Query("CREATE INDEX IF NOT EXISTS idx_chars_steamid ON mintyrp_characters(steamid64)")

	-- Inventory (must be character_id keyed)
	local invCols = tableColumns("mintyrp_inventory")
	local invOk = invCols.character_id and invCols.item_id and invCols.amount and not invCols.steamid64
	if not invOk then
		if invCols.steamid64 or invCols.id then
			print("[MintyRP] Rebuilding mintyrp_inventory for character_id schema")
			sql_Query("DROP TABLE IF EXISTS mintyrp_inventory")
		end
		sql_Query([[
			CREATE TABLE IF NOT EXISTS mintyrp_inventory (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				character_id INTEGER NOT NULL,
				slot INTEGER NOT NULL,
				item_id TEXT NOT NULL,
				amount INTEGER NOT NULL DEFAULT 1,
				meta TEXT NOT NULL DEFAULT '{}',
				UNIQUE(character_id, slot)
			);
		]])
	end

	sql_Query("CREATE INDEX IF NOT EXISTS idx_inv_character ON mintyrp_inventory(character_id)")
end

function DB.Migrate()
	-- Always migrate v1 players → characters if money column still exists
	if not hasColumn("mintyrp_players", "money") then return end

	print("[MintyRP] Migrating players v1 → v2/v3…")

	sql_Query([[
		CREATE TABLE IF NOT EXISTS mintyrp_characters (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			steamid64 TEXT NOT NULL,
			slot INTEGER NOT NULL,
			name TEXT NOT NULL,
			model TEXT NOT NULL,
			money INTEGER NOT NULL DEFAULT 500,
			bank INTEGER NOT NULL DEFAULT 0,
			data TEXT NOT NULL DEFAULT '{}',
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			UNIQUE(steamid64, slot)
		);
	]])

	local rows = sql_Query("SELECT steamid64, money, bank, model, data, created_at, updated_at FROM mintyrp_players")
	if type(rows) == "table" then
		for i = 1, #rows do
			local r = rows[i]
			local steam = sid(r.steamid64)
			local existing = sql_QueryValue(
				"SELECT id FROM mintyrp_characters WHERE steamid64 = " .. sql_SQLStr(steam) .. " LIMIT 1"
			)
			if not existing then
				sql_Query(string_format(
					"INSERT INTO mintyrp_characters (steamid64, slot, name, model, money, bank, data, created_at, updated_at) VALUES (%s, 1, %s, %s, %d, %d, %s, %d, %d)",
					sql_SQLStr(steam),
					sql_SQLStr("Migrated Character"),
					sql_SQLStr(r.model or "models/player/Group01/male_02.mdl"),
					tonumber(r.money) or 500,
					tonumber(r.bank) or 0,
					sql_SQLStr(tostring(r.data or "{}")),
					tonumber(r.created_at) or os.time(),
					tonumber(r.updated_at) or os.time()
				))
			end
		end
	end

	sql_Query("ALTER TABLE mintyrp_players RENAME TO mintyrp_players_v1")
	sql_Query([[
		CREATE TABLE mintyrp_players (
			steamid64 TEXT PRIMARY KEY,
			last_character_id INTEGER,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL
		);
	]])
	sql_Query([[
		INSERT OR IGNORE INTO mintyrp_players (steamid64, last_character_id, created_at, updated_at)
		SELECT steamid64, NULL, created_at, updated_at FROM mintyrp_players_v1
	]])
	sql_Query("DROP TABLE IF EXISTS mintyrp_players_v1")

	print("[MintyRP] Migration complete")
	clearSqlErr()
end

function DB.IsReady()
	return DB._ready == true
end

function DB.EnsureAccount(steamid64)
	steamid64 = sid(steamid64)
	if not steamid64 or steamid64 == "" then return false end

	local exists = sql_QueryValue("SELECT steamid64 FROM mintyrp_players WHERE steamid64 = " .. sql_SQLStr(steamid64))
	if exists then return true end

	-- If v1 table still around, migrate first
	if hasColumn("mintyrp_players", "money") then
		DB.Migrate()
		exists = sql_QueryValue("SELECT steamid64 FROM mintyrp_players WHERE steamid64 = " .. sql_SQLStr(steamid64))
		if exists then return true end
	end

	local now = os.time()
	local result = sql_Query(string_format(
		"INSERT INTO mintyrp_players (steamid64, last_character_id, created_at, updated_at) VALUES (%s, NULL, %d, %d)",
		sql_SQLStr(steamid64),
		now,
		now
	))

	if result == false then
		print("[MintyRP] EnsureAccount INSERT failed: " .. sqlErr())
		-- Last resort: ensure schema and retry once
		DB.EnsureSchema()
		result = sql_Query(string_format(
			"INSERT OR IGNORE INTO mintyrp_players (steamid64, last_character_id, created_at, updated_at) VALUES (%s, NULL, %d, %d)",
			sql_SQLStr(steamid64),
			now,
			now
		))
		if result == false then
			print("[MintyRP] EnsureAccount retry failed: " .. sqlErr())
			return false
		end
	end

	return true
end

function DB.ListCharacters(steamid64)
	steamid64 = sid(steamid64)
	if not steamid64 or steamid64 == "" then return {} end

	local q = "SELECT id, slot, name, model, money, bank FROM mintyrp_characters WHERE steamid64 = "
		.. sql_SQLStr(steamid64) .. " ORDER BY slot ASC"
	local rows = sql_Query(q)
	if type(rows) ~= "table" then return {} end

	local out = {}
	for i = 1, #rows do
		local r = rows[i]
		out[#out + 1] = {
			id = tonumber(r.id),
			slot = tonumber(r.slot),
			name = r.name,
			model = r.model,
			money = tonumber(r.money) or 0,
			bank = tonumber(r.bank) or 0,
		}
	end
	return out
end

function DB.CountCharacters(steamid64)
	steamid64 = sid(steamid64)
	if not steamid64 or steamid64 == "" then return 0 end
	return tonumber(sql_QueryValue(
		"SELECT COUNT(*) FROM mintyrp_characters WHERE steamid64 = " .. sql_SQLStr(steamid64)
	)) or 0
end

function DB.GetCharacter(characterId, steamid64)
	characterId = tonumber(characterId)
	if not characterId or characterId < 1 then return nil end

	local q = "SELECT * FROM mintyrp_characters WHERE id = " .. characterId
	if steamid64 then
		q = q .. " AND steamid64 = " .. sql_SQLStr(sid(steamid64))
	end

	local rows = sql_Query(q)
	if type(rows) ~= "table" or not rows[1] then return nil end

	local r = rows[1]
	return {
		id = tonumber(r.id),
		steamid64 = r.steamid64,
		slot = tonumber(r.slot),
		name = r.name,
		model = r.model,
		money = tonumber(r.money) or 0,
		bank = tonumber(r.bank) or 0,
		data = r.data,
		created_at = tonumber(r.created_at) or 0,
		updated_at = tonumber(r.updated_at) or 0,
	}
end

function DB.NextSlot(steamid64)
	local used = {}
	local chars = DB.ListCharacters(steamid64)
	for i = 1, #chars do
		used[chars[i].slot] = true
	end
	local maxSlots = (MintyRP.Character and MintyRP.Character.MaxSlots) or 3
	for slot = 1, maxSlots do
		if not used[slot] then return slot end
	end
	return nil
end

local function encodeAppearance(appearance)
	local skin = 0
	local bodygroups = {}
	if type(appearance) == "table" then
		skin = math.floor(tonumber(appearance.skin) or 0)
		if type(appearance.bodygroups) == "table" then
			for k, v in pairs(appearance.bodygroups) do
				bodygroups[tostring(k)] = math.floor(tonumber(v) or 0)
			end
		end
	end

	local json = util.TableToJSON({ skin = skin, bodygroups = bodygroups })
	if type(json) ~= "string" or json == "" then
		json = "{\"skin\":0,\"bodygroups\":{}}"
	end
	return json
end

function DB.CreateCharacter(steamid64, name, model, appearance)
	steamid64 = sid(steamid64)
	if not steamid64 or steamid64 == "" then return nil, "account" end

	name = tostring(name or "")
	model = tostring(model or "")

	DB.EnsureSchema()
	if not DB.EnsureAccount(steamid64) then
		return nil, "account"
	end

	local maxSlots = (MintyRP.Character and MintyRP.Character.MaxSlots) or 3
	if DB.CountCharacters(steamid64) >= maxSlots then
		return nil, "slots_full"
	end

	local slot = DB.NextSlot(steamid64)
	if not slot then return nil, "slots_full" end

	local now = os.time()
	local money = (MintyRP.Config and MintyRP.Config.StartMoney) or 500
	local bank = (MintyRP.Config and MintyRP.Config.StartBank) or 0
	local dataJson = encodeAppearance(appearance)

	clearSqlErr()

	local q = string_format(
		"INSERT INTO mintyrp_characters (steamid64, slot, name, model, money, bank, data, created_at, updated_at) VALUES (%s, %d, %s, %s, %d, %d, %s, %d, %d)",
		sql_SQLStr(steamid64),
		slot,
		sql_SQLStr(name),
		sql_SQLStr(model),
		money,
		bank,
		sql_SQLStr(dataJson),
		now,
		now
	)

	local result = sql_Query(q)
	if result == false then
		local err = sqlErr()
		print("[MintyRP] Character INSERT failed: " .. err)
		print("[MintyRP] SQL: " .. q)

		-- Repair + one retry (handles half-migrated DBs)
		DB.EnsureSchema()
		clearSqlErr()
		result = sql_Query(q)
		if result == false then
			print("[MintyRP] Character INSERT retry failed: " .. sqlErr())
			return nil, "db"
		end
	end

	-- Prefer lookup over last_insert_rowid (more reliable across GMod builds)
	local id = tonumber(sql_QueryValue(string_format(
		"SELECT id FROM mintyrp_characters WHERE steamid64 = %s AND slot = %d LIMIT 1",
		sql_SQLStr(steamid64),
		slot
	)))

	if not id or id < 1 then
		id = tonumber(sql_QueryValue("SELECT last_insert_rowid()"))
	end

	if not id or id < 1 then
		print("[MintyRP] Character INSERT produced no id. LastError=" .. sqlErr())
		return nil, "db"
	end

	local row = DB.GetCharacter(id, steamid64)
	if not row then
		print("[MintyRP] Character row missing after INSERT id=" .. tostring(id))
		return nil, "db"
	end

	return row, nil
end

function DB.SaveCharacter(characterId, money, bank, model, dataJson)
	characterId = tonumber(characterId)
	if not characterId then return false end

	local now = os.time()
	local result = sql_Query(string_format(
		"UPDATE mintyrp_characters SET money = %d, bank = %d, model = %s, data = %s, updated_at = %d WHERE id = %d",
		tonumber(money) or 0,
		tonumber(bank) or 0,
		sql_SQLStr(model or "models/player/Group01/male_02.mdl"),
		sql_SQLStr(dataJson or "{}"),
		now,
		characterId
	))
	return result ~= false
end

function DB.SetLastCharacter(steamid64, characterId)
	steamid64 = sid(steamid64)
	if not steamid64 then return end
	sql_Query(string_format(
		"UPDATE mintyrp_players SET last_character_id = %s, updated_at = %d WHERE steamid64 = %s",
		characterId and tostring(tonumber(characterId)) or "NULL",
		os.time(),
		sql_SQLStr(steamid64)
	))
end

function DB.ClearInventory(characterId)
	characterId = tonumber(characterId)
	if not characterId then return end
	sql_Query("DELETE FROM mintyrp_inventory WHERE character_id = " .. characterId)
end

function DB.LoadInventory(characterId)
	characterId = tonumber(characterId)
	if not characterId then return {} end

	local q = "SELECT slot, item_id, amount, meta FROM mintyrp_inventory WHERE character_id = "
		.. characterId .. " ORDER BY slot ASC"
	local rows = sql_Query(q)
	if type(rows) ~= "table" then return {} end

	local items = {}
	for i = 1, #rows do
		local row = rows[i]
		items[#items + 1] = {
			slot = tonumber(row.slot) or i,
			item_id = row.item_id,
			amount = tonumber(row.amount) or 1,
			meta = row.meta or "{}",
		}
	end
	return items
end

function DB.SaveInventory(characterId, items)
	characterId = tonumber(characterId)
	if not characterId then return false end
	if type(items) ~= "table" then return false end

	sql_Query("BEGIN")
	DB.ClearInventory(characterId)

	for i = 1, #items do
		local it = items[i]
		if it and it.item_id and it.amount and it.amount > 0 then
			sql_Query(string_format(
				"INSERT INTO mintyrp_inventory (character_id, slot, item_id, amount, meta) VALUES (%d, %d, %s, %d, %s)",
				characterId,
				tonumber(it.slot) or i,
				sql_SQLStr(tostring(it.item_id)),
				tonumber(it.amount) or 1,
				sql_SQLStr(tostring(it.meta or "{}"))
			))
		end
	end

	sql_Query("COMMIT")
	return true
end

--- Superadmin: wipe MintyRP tables (keeps sv.db otherwise)
function DB.ResetAll()
	sql_Query("DROP TABLE IF EXISTS mintyrp_inventory")
	sql_Query("DROP TABLE IF EXISTS mintyrp_characters")
	sql_Query("DROP TABLE IF EXISTS mintyrp_players")
	sql_Query("DROP TABLE IF EXISTS mintyrp_players_v1")
	sql_Query("DELETE FROM mintyrp_meta WHERE key = 'schema_version'")
	DB._ready = false
	DB.Initialize()
	print("[MintyRP] Database reset complete")
end

concommand.Add("mintyrp_dbreset", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	DB.ResetAll()
	if IsValid(ply) then
		MintyRP.Util.Notify(ply, "MintyRP database reset. Reconnect.", 1)
	end
end)

function DB.Close()
	print("[MintyRP] Database shutdown")
	DB._ready = false
end

print("[MintyRP] Database module registered")
