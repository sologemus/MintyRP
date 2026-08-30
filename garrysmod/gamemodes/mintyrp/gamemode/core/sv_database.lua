--[[-------------------------------------------------------------------------
	MintyRP — SQLite persistence layer
	Realm: SERVER

	Uses GMod's sql library (SQLite). Never trust client-supplied keys or
	query fragments — all values are escaped via sql.SQLStr.
---------------------------------------------------------------------------]]

if not SERVER then return end

MintyRP.Database = MintyRP.Database or {}

local DB = MintyRP.Database
local sql = sql
local sql_Query = sql.Query
local sql_SQLStr = sql.SQLStr
local sql_QueryValue = sql.QueryValue
local tonumber = tonumber
local tostring = tostring
local print = print

local SCHEMA_VERSION = 1

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
			money INTEGER NOT NULL DEFAULT 500,
			bank INTEGER NOT NULL DEFAULT 0,
			model TEXT NOT NULL DEFAULT 'models/player/Group01/male_02.mdl',
			data TEXT NOT NULL DEFAULT '{}',
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL
		);
	]])

	sql_Query([[
		CREATE TABLE IF NOT EXISTS mintyrp_inventory (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			steamid64 TEXT NOT NULL,
			slot INTEGER NOT NULL,
			item_id TEXT NOT NULL,
			amount INTEGER NOT NULL DEFAULT 1,
			meta TEXT NOT NULL DEFAULT '{}',
			UNIQUE(steamid64, slot)
		);
	]])

	sql_Query([[
		CREATE INDEX IF NOT EXISTS idx_inv_steamid
		ON mintyrp_inventory(steamid64);
	]])

	local ver = tonumber(sql_QueryValue("SELECT value FROM mintyrp_meta WHERE key = 'schema_version'")) or 0
	if ver < SCHEMA_VERSION then
		sql_Query("INSERT OR REPLACE INTO mintyrp_meta (key, value) VALUES ('schema_version', " .. sql_SQLStr(tostring(SCHEMA_VERSION)) .. ")")
	end

	if sql.LastError and sql.LastError() ~= "" then
		print("[MintyRP] Database warning: " .. tostring(sql.LastError()))
	else
		print("[MintyRP] SQLite database ready (schema v" .. SCHEMA_VERSION .. ")")
	end

	DB._ready = true
end

function DB.IsReady()
	return DB._ready == true
end

function DB.GetPlayer(steamid64)
	if not steamid64 or steamid64 == "" then return nil end

	local q = "SELECT * FROM mintyrp_players WHERE steamid64 = " .. sql_SQLStr(steamid64)
	local rows = sql_Query(q)
	if not rows or not rows[1] then return nil end

	local row = rows[1]
	return {
		steamid64 = row.steamid64,
		money = tonumber(row.money) or 0,
		bank = tonumber(row.bank) or 0,
		model = row.model,
		data = row.data,
		created_at = tonumber(row.created_at) or 0,
		updated_at = tonumber(row.updated_at) or 0,
	}
end

function DB.CreatePlayer(steamid64, money, bank, model)
	if not steamid64 or steamid64 == "" then return false end

	local now = os.time()
	money = tonumber(money) or MintyRP.Config.StartMoney
	bank = tonumber(bank) or MintyRP.Config.StartBank
	model = model or "models/player/Group01/male_02.mdl"

	local q = string.format(
		"INSERT INTO mintyrp_players (steamid64, money, bank, model, data, created_at, updated_at) VALUES (%s, %d, %d, %s, '{}', %d, %d)",
		sql_SQLStr(steamid64),
		money,
		bank,
		sql_SQLStr(model),
		now,
		now
	)

	sql_Query(q)
	return sql.LastError() == ""
end

function DB.SavePlayer(steamid64, money, bank, model, dataJson)
	if not steamid64 or steamid64 == "" then return false end

	local now = os.time()
	local q = string.format(
		"UPDATE mintyrp_players SET money = %d, bank = %d, model = %s, data = %s, updated_at = %d WHERE steamid64 = %s",
		tonumber(money) or 0,
		tonumber(bank) or 0,
		sql_SQLStr(model or "models/player/Group01/male_02.mdl"),
		sql_SQLStr(dataJson or "{}"),
		now,
		sql_SQLStr(steamid64)
	)

	sql_Query(q)
	return sql.LastError() == ""
end

function DB.ClearInventory(steamid64)
	if not steamid64 or steamid64 == "" then return end
	sql_Query("DELETE FROM mintyrp_inventory WHERE steamid64 = " .. sql_SQLStr(steamid64))
end

function DB.LoadInventory(steamid64)
	if not steamid64 or steamid64 == "" then return {} end

	local q = "SELECT slot, item_id, amount, meta FROM mintyrp_inventory WHERE steamid64 = " .. sql_SQLStr(steamid64) .. " ORDER BY slot ASC"
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

function DB.SaveInventory(steamid64, items)
	if not steamid64 or steamid64 == "" then return false end
	if type(items) ~= "table" then return false end

	sql_Query("BEGIN")
	DB.ClearInventory(steamid64)

	for i = 1, #items do
		local it = items[i]
		if it and it.item_id and it.amount and it.amount > 0 then
			local q = string.format(
				"INSERT INTO mintyrp_inventory (steamid64, slot, item_id, amount, meta) VALUES (%s, %d, %s, %d, %s)",
				sql_SQLStr(steamid64),
				tonumber(it.slot) or i,
				sql_SQLStr(tostring(it.item_id)),
				tonumber(it.amount) or 1,
				sql_SQLStr(tostring(it.meta or "{}"))
			)
			sql_Query(q)
		end
	end

	sql_Query("COMMIT")
	return true
end

function DB.Close()
	-- SQLite in GMod is process-global; flush any pending player data via callers
	print("[MintyRP] Database shutdown")
	DB._ready = false
end

print("[MintyRP] Database module registered")
