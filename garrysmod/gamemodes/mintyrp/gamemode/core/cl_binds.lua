--[[-------------------------------------------------------------------------
	MintyRP — Client menu binds (reliable)
	Realm: CLIENT

	PlayerButtonDown is unreliable for some binds on x86-64.
	Use concommands + PlayerBindPress + button hooks together.
---------------------------------------------------------------------------]]

if not CLIENT then return end

local function canUseMenus()
	local ply = LocalPlayer()
	if not IsValid(ply) then return false end
	if gui.IsConsoleVisible() then return false end
	if gui.IsGameUIVisible() then return false end
	return ply.MintyRP and ply.MintyRP.Loaded == true
end

concommand.Add("mintyrp_inventory", function()
	if not canUseMenus() then return end
	if MintyRP.Inventory and MintyRP.Inventory.Open then
		MintyRP.Inventory.Open()
	else
		notification.AddLegacy("Inventory module not loaded.", NOTIFY_ERROR, 3)
	end
end)

concommand.Add("mintyrp_properties", function()
	if not canUseMenus() then return end
	if MintyRP.Property and MintyRP.Property.OpenMenu then
		MintyRP.Property.OpenMenu()
	else
		notification.AddLegacy("Property module not loaded.", NOTIFY_ERROR, 3)
	end
end)

concommand.Add("mintyrp_buydoor", function()
	if not canUseMenus() then return end
	if not MintyRP.Property then return end

	local ply = LocalPlayer()
	local tr = ply:GetEyeTrace()
	if not tr or not IsValid(tr.Entity) then
		notification.AddLegacy("Look at a door to buy it.", NOTIFY_ERROR, 3)
		return
	end
	if tr.HitPos:DistToSqr(ply:EyePos()) > (180 * 180) then
		notification.AddLegacy("Too far from the door.", NOTIFY_ERROR, 3)
		return
	end
	if not MintyRP.Property.IsDoor(tr.Entity) then
		notification.AddLegacy("That's not a door.", NOTIFY_ERROR, 3)
		return
	end

	local info = MintyRP.Property.DoorInfo and MintyRP.Property.DoorInfo(tr.Entity)
	local id = info and info.id or tr.Entity:GetNWString("MintyRP_Property", "")
	if id == "" then
		notification.AddLegacy("Door is not linked — host: mintyrp_propscan", NOTIFY_ERROR, 3)
		return
	end

	local ownable = info and info.ownable
	if ownable == false then
		notification.AddLegacy(
			(info.def and MintyRP.Property.GetOwnerLabel(info.def)) or "Not for sale",
			NOTIFY_ERROR, 3
		)
		return
	end

	net.Start("MintyRP_PropertyAction")
		net.WriteUInt(1, 3)
		net.WriteString(id)
	net.SendToServer()
end)

-- F2 often bound to gm_showteam — intercept
hook.Add("PlayerBindPress", "MintyRP_MenuBinds", function(ply, bind, pressed)
	if not pressed then return end
	if ply ~= LocalPlayer() then return end
	if not canUseMenus() then return end

	bind = string.lower(bind or "")

	if bind == "gm_showteam" or bind == "showteam" then
		RunConsoleCommand("mintyrp_inventory")
		return true
	end

	if bind == "gm_showspare1" or bind == "showspare1" then
		RunConsoleCommand("mintyrp_properties")
		return true
	end
end)

hook.Add("PlayerButtonDown", "MintyRP_MenuButtons", function(ply, button)
	if ply ~= LocalPlayer() then return end
	if not canUseMenus() then return end

	if button == KEY_F2 then
		RunConsoleCommand("mintyrp_inventory")
	elseif button == KEY_F3 then
		RunConsoleCommand("mintyrp_properties")
	elseif button == KEY_N then
		RunConsoleCommand("mintyrp_buydoor")
	elseif button == KEY_F4 then
		-- spare: also inventory
		RunConsoleCommand("mintyrp_inventory")
	end
end)

print("[MintyRP] Client menu binds ready (F2 inv, F3 props, N buy)")
