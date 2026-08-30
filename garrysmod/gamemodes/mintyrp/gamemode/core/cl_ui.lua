--[[-------------------------------------------------------------------------
	MintyRP — Shared UI palette (Perpheads-leaning dark RP panels)
	Realm: CLIENT
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP.UI = MintyRP.UI or {}

MintyRP.UI.Colors = {
	bg       = Color(18, 18, 20, 250),
	panel    = Color(28, 28, 32, 255),
	panelAlt = Color(36, 36, 42, 255),
	slot     = Color(42, 42, 48, 255),
	slotHov  = Color(55, 55, 64, 255),
	slotSel  = Color(62, 90, 78, 255),
	accent   = Color(72, 180, 130),
	text     = Color(235, 235, 238),
	dim      = Color(140, 140, 150),
	warn     = Color(220, 160, 90),
	barBg    = Color(20, 20, 24, 255),
	barFill  = Color(72, 180, 130, 220),
	border   = Color(55, 55, 62, 255),
}

function MintyRP.UI.PaintPanel(w, h, col)
	col = col or MintyRP.UI.Colors.panel
	draw.RoundedBox(4, 0, 0, w, h, col)
end

function MintyRP.UI.PaintFrame(w, h)
	local C = MintyRP.UI.Colors
	draw.RoundedBox(6, 0, 0, w, h, C.bg)
	surface.SetDrawColor(C.border)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end

print("[MintyRP] UI theme loaded")
