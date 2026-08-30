--[[-------------------------------------------------------------------------
	MintyRP — SQLite persistence layer
	Realm: SERVER

	Schema v2: account row + multi-character slots + per-character inventory.
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

local SCHEMA_VERSION = 2

function DB.Initialize()
	sql_Query([[
		CREATE TABLE IF NOT EXISTS mintyrp_meta (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL
		);
	]])

	sql_Query([[
		CREATE TABLE IF NOT EXISTS mintyrp_players (
			steamid64 TEXT PRIMARY KEY,
			last_character_id INTEGER,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL
		);
	]])

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

	sql_Query([[
		CREATE INDEX IF NOT EXISTS idx_chars_steamid
		ON mintyrp_characters(steamid64);
	]])

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

	sql_Query([[
		CREATE INDEX IF NOT EXISTS idx_inv_character
		ON mintyrp_inventory(character_id);
	]])

	DB.Migrate()

	sql_Query("INSERT OR REPLACE INTO mintyrp_meta (key, value) VALUES ('schema_version', " .. sql_SQLStr(tostring(SCHEMA_VERSION)) .. ")")

	local err = sql.LastError and sql.LastError() or ""
	if err ~= "" then
		print("[MintyRP] Database warning: " .. tostring(err))
	else
		print("[MintyRP] SQLite database ready (schema v" .. SCHEMA_VERSION .. ")")
	end

	DB._ready = true
end

function DB.Migrate()
	local ver = tonumber(sql_QueryValue("SELECT value FROM mintyrp_meta WHERE key = 'schema_version'")) or 0
	if ver >= SCHEMA_VERSION then return end

	-- v1 → v2: old mintyrp_players had money/model columns; pull into a character if present
	local cols = sql_Query("PRAGMA table_info(mintyrp_players)")
	local hasMoney = false
	if cols then
		for i = 1, #cols do
			if cols[i].name == "money" then
				hasMoney = true
				break
			end
		end
	end

	if hasMoney then
		local rows = sql_Query("SELECT steamid64, money, bank, model, data, created_at, updated_at FROM mintyrp_players")
		if rows then
			for i = 1, #rows do
				local r = rows[i]
				local existing = sql_QueryValue(
					"SELECT id FROM mintyrp_characters WHERE steamid64 = " .. sql_SQLStr(r.steamid64) .. " LIMIT 1"
				)
				if not existing then
					sql_Query(string_format(
						"INSERT INTO mintyrp_characters (steamid64, slot, name, model, money, bank, data, created_at, updated_at) VALUES (%s, 1, %s, %s, %d, %d, %s, %d, %d)",
						sql_SQLStr(r.steamid64),
						sql_SQLStr("Migrated Character"),
						sql_SQLStr(r.model or "models/player/Group01/male_02.mdl"),
						tonumber(r.money) or 500,
						tonumber(r.bank) or 0,
						sql_SQLStr(r.data or "{}"),
						tonumber(r.created_at) or os.time(),
						tonumber(r.updated_at) or os.time()
					))
				end
			end
		end

		-- Rebuild lean account table
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
			INSERT INTO mintyrp_players (steamid64, last_character_id, created_at, updated_at)
			SELECT steamid64, NULL, created_at, updated_at FROM mintyrp_players_v1
		]])
		sql_Query("DROP TABLE mintyrp_players_v1")

		-- Old inventory was steamid-keyed; drop orphaned rows (fresh start for inv on migrate)
		local invCols = sql_Query("PRAGMA table_info(mintyrp_inventory)")
		local hasSteamInv = false
		if invCols then
			for i = 1, #invCols do
				if invCols[i].name == "steamid64" then
					hasSteamInv = true
					break
				end
			end
		end
		if hasSteamInv then
			sql_Query("DROP TABLE mintyrp_inventory")
			sql_Query([[
				CREATE TABLE mintyrp_inventory (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					character_id INTEGER NOT NULL,
					slot INTEGER NOT NULL,
					item_id TEXT NOT NULL,
					amount INTEGER NOT NULL DEFAULT 1,
					meta TEXT NOT NULL DEFAULT '{}',
					UNIQUE(character_id, slot)
				);
			]])
			sql_Query("CREATE INDEX IF NOT EXISTS idx_inv_character ON mintyrp_inventory(character_id)")
		end

		print("[MintyRP] Migrated database schema v1 → v2")
	end
end

function DB.IsReady()
	return DB._ready == true
end

function DB.EnsureAccount(steamid64)
	if not steamid64 or steamid64 == "" then return false end

	local exists = sql_QueryValue("SELECT steamid64 FROM mintyrp_players WHERE steamid64 = " .. sql_SQLStr(steamid64))
	if exists then return true end

	local now = os.time()
	sql_Query(string_format(
		"INSERT INTO mintyrp_players (steamid64, last_character_id, created_at, updated_at) VALUES (%s, NULL, %d, %d)",
		sql_SQLStr(steamid64),
		now,
		now
	))
	return sql.LastError() == ""
end

function DB.ListCharacters(steamid64)
	if not steamid64 or steamid64 == "" then return {} end

	local q = "SELECT id, slot, name, model, money, bank FROM mintyrp_characters WHERE steamid64 = "
		.. sql_SQLStr(steamid64) .. " ORDER BY slot ASC"
	local rows = sql_Query(q)
	if not rows then return {} end

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
	if not steamid64 or steamid64 == "" then return 0 end
	return tonumber(sql_QueryValue(
		"SELECT COUNT(*) FROM mintyrp_characters WHERE steamid64 = " .. sql_SQLStr(steamid64)
	)) or 0
end

function DB.GetCharacter(characterId, steamid64)
	characterId = tonumber(characterId)
	if not characterId then return nil end

	local q = "SELECT * FROM mintyrp_characters WHERE id = " .. characterId
	if steamid64 then
		q = q .. " AND steamid64 = " .. sql_SQLStr(steamid64)
	end

	local rows = sql_Query(q)
	if not rows or not rows[1] then return nil end

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

function DB.CreateCharacter(steamid64, name, model)
	if not steamid64 or steamid64 == "" then return nil, "account" end

	DB.EnsureAccount(steamid64)

	local maxSlots = (MintyRP.Character and MintyRP.Character.MaxSlots) or 3
	if DB.CountCharacters(steamid64) >= maxSlots then
		return nil, "slots_full"
	end

	local slot = DB.NextSlot(steamid64)
	if not slot then return nil, "slots_full" end

	local now = os.time()
	local money = (MintyRP.Config and MintyRP.Config.StartMoney) or 500
	local bank = (MintyRP.Config and MintyRP.Config.StartBank) or 0

	sql_Query(string_format(
		"INSERT INTO mintyrp_characters (steamid64, slot, name, model, money, bank, data, created_at, updated_at) VALUES (%s, %d, %s, %s, %d, %d, '{}', %d, %d)",
		sql_SQLStr(steamid64),
		slot,
		sql_SQLStr(name),
		sql_SQLStr(model),
		money,
		bank,
		now,
		now
	))

	if sql.LastError() ~= "" then
		return nil, "db"
	end

	local id = tonumber(sql_QueryValue("SELECT last_insert_rowid()"))
	return DB.GetCharacter(id, steamid64), nil
end

function DB.SaveCharacter(characterId, money, bank, model, dataJson)
	characterId = tonumber(characterId)
	if not characterId then return false end

	local now = os.time()
	sql_Query(string_format(
		"UPDATE mintyrp_characters SET money = %d, bank = %d, model = %s, data = %s, updated_at = %d WHERE id = %d",
		tonumber(money) or 0,
		tonumber(bank) or 0,
		sql_SQLStr(model or "models/player/Group01/male_02.mdl"),
		sql_SQLStr(dataJson or "{}"),
		now,
		characterId
	))
	return sql.LastError() == ""
end

function DB.SetLastCharacter(steamid64, characterId)
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
	if not rows then return {} end

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

function DB.Close()
	print("[MintyRP] Database shutdown")
	DB._ready = false
end

print("[MintyRP] Database module registered")
