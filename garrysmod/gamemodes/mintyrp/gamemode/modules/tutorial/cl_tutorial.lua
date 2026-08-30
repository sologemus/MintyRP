--[[-------------------------------------------------------------------------
	MintyRP — Starter tutorial UI (client)
	Realm: CLIENT
---------------------------------------------------------------------------]]

if not CLIENT then return end

MintyRP = MintyRP or {}
MintyRP.Tutorial = MintyRP.Tutorial or {}

local PANEL

local function CloseTutorial()
	if IsValid(PANEL) then
		PANEL:Remove()
		PANEL = nil
	end
end

local function FinishTutorial(skip)
	CloseTutorial()
	if skip then
		net.Start("MintyRP_TutorialSkip")
		net.SendToServer()
	else
		net.Start("MintyRP_TutorialComplete")
		net.SendToServer()
	end
end

local function OpenTutorial()
	CloseTutorial()

	local steps = MintyRP.Tutorial.Steps or {}
	if #steps == 0 then return end

	local step = 1
	local cash = MintyRP.Tutorial.StarterCash or 20000

	local frame = vgui.Create("DFrame")
	PANEL = frame
	frame:SetSize(520, 360)
	frame:Center()
	frame:SetTitle("MintyRP — Getting started")
	frame:MakePopup()
	frame:SetDraggable(true)
	frame:ShowCloseButton(false)

	local title = vgui.Create("DLabel", frame)
	title:SetPos(20, 36)
	title:SetSize(480, 28)
	title:SetFont("DermaLarge")
	title:SetText("")

	local body = vgui.Create("DLabel", frame)
	body:SetPos(20, 72)
	body:SetSize(480, 200)
	body:SetWrap(true)
	body:SetAutoStretchVertical(true)
	body:SetContentAlignment(7)
	body:SetText("")

	local progress = vgui.Create("DLabel", frame)
	progress:SetPos(20, 280)
	progress:SetSize(200, 20)
	progress:SetText("")

	local nextBtn = vgui.Create("DButton", frame)
	nextBtn:SetPos(400, 310)
	nextBtn:SetSize(100, 32)
	nextBtn:SetText("Next")

	local function Refresh()
		local s = steps[step]
		if not s then return end
		title:SetText(s.title or "")
		body:SetText(s.body or "")
		progress:SetText(("Step %d / %d"):format(step, #steps))
		if step >= #steps then
			nextBtn:SetText("Claim $" .. string.Comma(cash))
		else
			nextBtn:SetText("Next")
		end
	end

	local skip = vgui.Create("DButton", frame)
	skip:SetPos(20, 310)
	skip:SetSize(100, 32)
	skip:SetText("Skip (+$" .. string.Comma(cash) .. ")")
	skip.DoClick = function()
		FinishTutorial(true)
	end

	local back = vgui.Create("DButton", frame)
	back:SetPos(280, 310)
	back:SetSize(100, 32)
	back:SetText("Back")
	back.DoClick = function()
		if step > 1 then
			step = step - 1
			Refresh()
		end
	end

	nextBtn.DoClick = function()
		if step < #steps then
			step = step + 1
			Refresh()
		else
			FinishTutorial(false)
		end
	end

	Refresh()
end

net.Receive("MintyRP_TutorialOpen", function()
	OpenTutorial()
end)

concommand.Add("mintyrp_tutorial_ui", function()
	OpenTutorial()
end)

print("[MintyRP] Tutorial client loaded")
