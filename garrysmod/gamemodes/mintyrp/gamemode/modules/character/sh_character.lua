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

local modelSet = {}
for i = 1, #Char.Models do
	modelSet[Char.Models[i]] = true
end

function Char.IsAllowedModel(model)
	return modelSet[model] == true
end

--- Sanitize + validate RP name. Returns name, err
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

	-- Letters, spaces, hyphen, apostrophe only
	if not string.match(name, "^[%a%s%-%']+$") then
		return nil, "chars"
	end

	-- Must look like "First Last" (at least one space)
	if not string.find(name, " ", 1, true) then
		return nil, "fullname"
	end

	-- Title-ish: reject all-caps spam
	if name == string.upper(name) and len > 4 then
		return nil, "caps"
	end

	return name, nil
end

print("[MintyRP] Character shared loaded")
