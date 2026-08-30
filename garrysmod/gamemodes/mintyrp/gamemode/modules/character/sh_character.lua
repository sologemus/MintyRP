--[[-------------------------------------------------------------------------
	MintyRP — Character definitions
	Realm: SHARED
---------------------------------------------------------------------------]]

MintyRP.Character = MintyRP.Character or {}

local Char = MintyRP.Character

Char.MaxSlots = 3
Char.NameMin = 3
Char.NameMax = 24
Char.DefaultModel = "models/player/Group01/male_02.mdl"
Char.MaxBodygroups = 8

Char.Models = {
	"models/player/Group01/male_01.mdl",
	"models/player/Group01/male_02.mdl",
	"models/player/Group01/male_03.mdl",
	"models/player/Group01/male_04.mdl",
	"models/player/Group01/male_05.mdl",
	"models/player/Group01/male_06.mdl",
	"models/player/Group01/male_07.mdl",
	"models/player/Group01/male_08.mdl",
	"models/player/Group01/male_09.mdl",
	"models/player/Group01/female_01.mdl",
	"models/player/Group01/female_02.mdl",
	"models/player/Group01/female_03.mdl",
	"models/player/Group01/female_04.mdl",
	"models/player/Group01/female_05.mdl",
	"models/player/Group01/female_06.mdl",
}

-- Friendly labels for the create menu
Char.ModelLabels = {
	["models/player/Group01/male_01.mdl"] = "Male 01",
	["models/player/Group01/male_02.mdl"] = "Male 02",
	["models/player/Group01/male_03.mdl"] = "Male 03",
	["models/player/Group01/male_04.mdl"] = "Male 04",
	["models/player/Group01/male_05.mdl"] = "Male 05",
	["models/player/Group01/male_06.mdl"] = "Male 06",
	["models/player/Group01/male_07.mdl"] = "Male 07",
	["models/player/Group01/male_08.mdl"] = "Male 08",
	["models/player/Group01/male_09.mdl"] = "Male 09",
	["models/player/Group01/female_01.mdl"] = "Female 01",
	["models/player/Group01/female_02.mdl"] = "Female 02",
	["models/player/Group01/female_03.mdl"] = "Female 03",
	["models/player/Group01/female_04.mdl"] = "Female 04",
	["models/player/Group01/female_05.mdl"] = "Female 05",
	["models/player/Group01/female_06.mdl"] = "Female 06",
}

local modelSet = {}
for i = 1, #Char.Models do
	modelSet[Char.Models[i]] = true
end

function Char.IsAllowedModel(model)
	return modelSet[model] == true
end

function Char.ValidateName(name)
	if type(name) ~= "string" then
		return nil, "invalid"
	end

	name = string.Trim(name)
	name = string.gsub(name, "%s+", " ")

	local len = string.len(name)
	if len < Char.NameMin or len > Char.NameMax then
		return nil, "length"
	end

	if not string.match(name, "^[%a%s%-%']+$") then
		return nil, "chars"
	end

	if not string.find(name, " ", 1, true) then
		return nil, "fullname"
	end

	if name == string.upper(name) and len > 4 then
		return nil, "caps"
	end

	return name, nil
end

--- Clamp appearance from client. Returns { skin = n, bodygroups = { [id]=val } }
function Char.SanitizeAppearance(skin, bodygroups)
	skin = math.floor(tonumber(skin) or 0)
	if skin < 0 then skin = 0 end
	if skin > 32 then skin = 32 end

	local clean = {}
	if type(bodygroups) == "table" then
		local count = 0
		for id, val in pairs(bodygroups) do
			local gid = math.floor(tonumber(id) or -1)
			local gval = math.floor(tonumber(val) or 0)
			if gid >= 0 and gid < Char.MaxBodygroups and gval >= 0 and gval <= 16 then
				clean[gid] = gval
				count = count + 1
				if count >= Char.MaxBodygroups then break end
			end
		end
	end

	return { skin = skin, bodygroups = clean }
end

function Char.ApplyAppearance(ent, appearance)
	if not IsValid(ent) or type(appearance) ~= "table" then return end

	local skin = math.floor(tonumber(appearance.skin) or 0)
	ent:SetSkin(skin)

	local groups = appearance.bodygroups
	if type(groups) == "table" then
		for id, val in pairs(groups) do
			ent:SetBodygroup(tonumber(id) or 0, tonumber(val) or 0)
		end
	end
end

print("[MintyRP] Character shared loaded")
