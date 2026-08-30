--[[-------------------------------------------------------------------------
	MintyRP — Shared bootstrap & modular autoloader
	Realm: SHARED
	Map:   rp_rockford_v2b

	Strictly GLua (Garry's Mod). Do not use Roblox or vanilla Lua APIs.
---------------------------------------------------------------------------]]

GM.Name      = "MintyRP"
GM.Author    = "MintyRP Team"
GM.Email     = ""
GM.Website   = ""
GM.Version   = "0.1.0"
GM.TeamBased = false

DeriveGamemode("base")

MintyRP = MintyRP or {}
MintyRP.Config = MintyRP.Config or {}
MintyRP.Modules = MintyRP.Modules or {}

local pairs = pairs
local ipairs = ipairs
local print = print
local string_sub = string.sub
local string_lower = string.lower
local string_GetFileFromFilename = string.GetFileFromFilename
local file_Find = file.Find
local include = include
local AddCSLuaFile = AddCSLuaFile
local SERVER = SERVER
local CLIENT = CLIENT
local table_sort = table.sort

local FOLDER = (GM.FolderName or "mintyrp") .. "/gamemode/"

--[[-------------------------------------------------------------------------
	Secure modular autoloader
	Prefix rules (standard GMod):
	  sh_  → shared  (server include + AddCSLuaFile, client include)
	  sv_  → server only
	  cl_  → client only (server AddCSLuaFile, client include)
---------------------------------------------------------------------------]]

local REALM_ORDER = { sh_ = 1, sv_ = 2, cl_ = 3 }

local function getRealm(filename)
	local name = string_lower(string_GetFileFromFilename(filename))
	local prefix = string_sub(name, 1, 3)

	if prefix == "sh_" then return "shared" end
	if prefix == "sv_" then return "server" end
	if prefix == "cl_" then return "client" end

	return nil
end

--- Include a file relative to gamemode/ (e.g. "core/sh_config.lua")
local function includeFile(relPath)
	local realm = getRealm(relPath)
	if not realm then
		print("[MintyRP] Skipping (unknown prefix): " .. relPath)
		return false
	end

	if realm == "shared" then
		if SERVER then
			AddCSLuaFile(relPath)
		end
		include(relPath)
	elseif realm == "server" then
		if SERVER then
			include(relPath)
		end
	elseif realm == "client" then
		if SERVER then
			AddCSLuaFile(relPath)
		else
			include(relPath)
		end
	end

	return true
end

--- Recursively include Lua files from a folder under gamemode/
local function includeFolder(folder, recursive)
	if recursive == nil then recursive = true end

	local files, dirs = file_Find(FOLDER .. folder .. "/*", "LUA")
	if not files then
		print("[MintyRP] Folder missing or empty: " .. folder)
		return
	end

	table_sort(files, function(a, b)
		local pa = REALM_ORDER[string_sub(string_lower(a), 1, 3)] or 9
		local pb = REALM_ORDER[string_sub(string_lower(b), 1, 3)] or 9
		if pa == pb then return a < b end
		return pa < pb
	end)

	for i = 1, #files do
		local fname = files[i]
		if string_sub(fname, -4) == ".lua" then
			includeFile(folder .. "/" .. fname)
		end
	end

	if recursive and dirs then
		table_sort(dirs)
		for i = 1, #dirs do
			local dir = dirs[i]
			if dir ~= "." and dir ~= ".." then
				includeFolder(folder .. "/" .. dir, true)
			end
		end
	end
end

MintyRP.IncludeFile = includeFile
MintyRP.IncludeFolder = includeFolder

print("[MintyRP] Shared bootstrap v" .. GM.Version)

includeFolder("core", true)
includeFolder("modules", true)

print("[MintyRP] Autoload complete")
