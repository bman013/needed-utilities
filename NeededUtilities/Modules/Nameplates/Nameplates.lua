local ADDON_NAME, ns = ...
local NU = ns.NU

local Nameplates = NU:RegisterModule("Nameplates", {})

Nameplates.defaults = {
	enabled = true,
	highlightQuestMobs = true,
}

local function db()
	return NU:GetModuleDB("Nameplates")
end

local BORDER_COLOR = { 1, 0.82, 0 } -- gold, matches the game's own quest-yellow convention
local BORDER_THICKNESS = 2

local function GetPlateAnchor(namePlateFrame)
	return namePlateFrame.UnitFrame or namePlateFrame
end

local borders = {} -- namePlateFrame -> border frame (plates are pooled/reused by Blizzard)

local function CreateBorder(anchor)
	local border = CreateFrame("Frame", nil, anchor)
	border:SetAllPoints(anchor)
	border:SetFrameLevel(anchor:GetFrameLevel() + 5)

	local function Line()
		local tex = border:CreateTexture(nil, "OVERLAY")
		tex:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 1)
		return tex
	end

	local top = Line()
	top:SetPoint("TOPLEFT", -BORDER_THICKNESS, BORDER_THICKNESS)
	top:SetPoint("TOPRIGHT", BORDER_THICKNESS, BORDER_THICKNESS)
	top:SetHeight(BORDER_THICKNESS)

	local bottom = Line()
	bottom:SetPoint("BOTTOMLEFT", -BORDER_THICKNESS, -BORDER_THICKNESS)
	bottom:SetPoint("BOTTOMRIGHT", BORDER_THICKNESS, -BORDER_THICKNESS)
	bottom:SetHeight(BORDER_THICKNESS)

	local left = Line()
	left:SetPoint("TOPLEFT", -BORDER_THICKNESS, BORDER_THICKNESS)
	left:SetPoint("BOTTOMLEFT", -BORDER_THICKNESS, -BORDER_THICKNESS)
	left:SetWidth(BORDER_THICKNESS)

	local right = Line()
	right:SetPoint("TOPRIGHT", BORDER_THICKNESS, BORDER_THICKNESS)
	right:SetPoint("BOTTOMRIGHT", BORDER_THICKNESS, -BORDER_THICKNESS)
	right:SetWidth(BORDER_THICKNESS)

	return border
end

--- Blizzard's own long-standing way of asking "is this unit relevant to one
--- of my quests as a kill/interact objective" - the same check historically
--- used to show a quest-skull icon above a mob's head.
local function IsQuestRelevant(unit)
	return UnitIsQuestBoss and UnitIsQuestBoss(unit)
end

local function UpdatePlate(unit)
	local settings = db()
	if not (settings and settings.enabled and settings.highlightQuestMobs) then return end
	if not (unit and UnitExists(unit)) then return end

	local namePlateFrame = C_NamePlate.GetNamePlateForUnit(unit)
	if not namePlateFrame then return end

	local border = borders[namePlateFrame]
	if IsQuestRelevant(unit) then
		if not border then
			border = CreateBorder(GetPlateAnchor(namePlateFrame))
			borders[namePlateFrame] = border
		end
		border:Show()
	elseif border then
		border:Hide()
	end
end

local function RefreshAllPlates()
	for _, namePlateFrame in ipairs(C_NamePlate.GetNamePlates()) do
		if namePlateFrame.namePlateUnitToken then
			UpdatePlate(namePlateFrame.namePlateUnitToken)
		end
	end
end

local watcher
local function HookEvents()
	if watcher then return end
	watcher = CreateFrame("Frame")
	watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	-- Quest state can change while a mob's nameplate is already on screen
	-- (accepting/completing/abandoning the relevant quest), so re-check
	-- every visible plate on these too.
	watcher:RegisterEvent("QUEST_ACCEPTED")
	watcher:RegisterEvent("QUEST_REMOVED")
	watcher:RegisterEvent("QUEST_LOG_UPDATE")
	watcher:SetScript("OnEvent", function(self, event, unit)
		if event == "NAME_PLATE_UNIT_ADDED" then
			UpdatePlate(unit)
		else
			RefreshAllPlates()
		end
	end)
end

local configBuilt = false
local function BuildConfig()
	if configBuilt then return end
	configBuilt = true

	local panel = NU.Config:RegisterModulePanel("Nameplates", "Nameplates")
	NU.Config:AddModuleToggle(panel, "Nameplates")

	NU.Config:AddCheckbox(panel, "Highlight quest-objective mobs", "Adds a gold border to the nameplate of any mob relevant to one of your current quests, so you can prioritise it at a glance.",
		function() return db().highlightQuestMobs end,
		function(value)
			db().highlightQuestMobs = value
			RefreshAllPlates()
		end)
end

function Nameplates:OnEnable()
	BuildConfig()
	HookEvents()
	RefreshAllPlates()
end
