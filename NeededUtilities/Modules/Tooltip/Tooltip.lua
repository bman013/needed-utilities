local ADDON_NAME, ns = ...
local NU = ns.NU

local Tooltip = NU:RegisterModule("Tooltip", {})

Tooltip.defaults = {
	enabled = true,
	anchorToMouse = false,
	showUnitID = true,
	showSpellID = true,
	showItemID = true,
	classColorNames = true,
	showDistance = true,
}

local CURSOR_OFFSET_X, CURSOR_OFFSET_Y = 12, -12
local INFO_COLOR = "|cff999999"

local function db()
	return NU:GetModuleDB("Tooltip")
end

local function GetClassColor(class)
	if not class then return nil end
	if C_ClassColor and C_ClassColor.GetClassColor then
		return C_ClassColor.GetClassColor(class)
	end
	return RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
end

--- Pulls the numeric NPC/vehicle/pet ID out of a unit GUID.
--- GUID layout: Type-0-ServerID-InstanceID-ZoneUID-ID-SpawnUID
local function GetIDFromGUID(guid)
	if not guid then return nil, nil end
	local unitType, _, _, _, _, id = strsplit("-", guid)
	return tonumber(id), unitType
end

local function AnchorToMouse(tooltip)
	local settings = db()
	if not (settings and settings.enabled and settings.anchorToMouse) then return end

	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	tooltip:ClearAllPoints()
	tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + CURSOR_OFFSET_X, y / scale + CURSOR_OFFSET_Y)
end

local function ColorUnitName(tooltip, unit)
	local settings = db()
	if not (settings and settings.enabled and settings.classColorNames) then return end
	if not UnitIsPlayer(unit) then return end

	local _, class = UnitClass(unit)
	local color = GetClassColor(class)
	if not color then return end

	local nameText = _G[tooltip:GetName() .. "TextLeft1"]
	if nameText then
		nameText:SetTextColor(color.r, color.g, color.b)
	end
end

local function AddUnitIDLine(tooltip, unit)
	local settings = db()
	if not (settings and settings.enabled and settings.showUnitID) then return end

	local id, unitType = GetIDFromGUID(UnitGUID(unit))
	if not id then return end

	tooltip:AddLine(("%sID: %d (%s)|r"):format(INFO_COLOR, id, unitType), 1, 1, 1)
	tooltip:Show()
end

-- Blizzard stopped exposing exact unit distances to addons years ago (an
-- anti-cheat measure that applies to Classic too), so the closest we can
-- get is bucketing against the fixed ranges CheckInteractDistance still
-- exposes: duel (~9.9yd), trade (~11.11yd), and inspect (~28yd).
local function GetApproxDistance(unit)
	if not CheckInteractDistance then return nil end
	if CheckInteractDistance(unit, 3) then
		return "< 10 yd"
	elseif CheckInteractDistance(unit, 2) then
		return "10-11 yd"
	elseif CheckInteractDistance(unit, 1) then
		return "11-28 yd"
	else
		return "28+ yd"
	end
end

local function AddDistanceLine(tooltip, unit)
	local settings = db()
	if not (settings and settings.enabled and settings.showDistance) then return end

	local distance = GetApproxDistance(unit)
	if not distance then return end

	tooltip:AddLine(("%sDistance: %s|r"):format(INFO_COLOR, distance), 1, 1, 1)
	tooltip:Show()
end

local function OnTooltipSetUnit(tooltip)
	local settings = db()
	if not (settings and settings.enabled) then return end
	if not tooltip.GetUnit then return end

	local _, unit = tooltip:GetUnit()
	if not unit then return end

	ColorUnitName(tooltip, unit)
	AddUnitIDLine(tooltip, unit)
	AddDistanceLine(tooltip, unit)
end

local function OnTooltipSetSpell(tooltip)
	local settings = db()
	if not (settings and settings.enabled and settings.showSpellID) then return end
	if not tooltip.GetSpell then return end

	local _, spellID = tooltip:GetSpell()
	if not spellID then return end

	tooltip:AddLine(("%sSpell ID: %d|r"):format(INFO_COLOR, spellID), 1, 1, 1)
	tooltip:Show()
end

local function OnTooltipSetItem(tooltip)
	local settings = db()
	if not (settings and settings.enabled and settings.showItemID) then return end
	-- The shopping/comparison tooltip Blizzard shows next to an equippable
	-- item (e.g. one you already have something equipped in that slot for)
	-- goes through this same callback but doesn't implement GetItem().
	if not tooltip.GetItem then return end

	local _, link = tooltip:GetItem()
	local itemID = link and tonumber(link:match("item:(%d+)"))
	if not itemID then return end

	tooltip:AddLine(("%sItem ID: %d|r"):format(INFO_COLOR, itemID), 1, 1, 1)
	tooltip:Show()
end

local hooked = false
local function HookTooltips()
	if hooked then return end
	hooked = true

	-- Prefer the modern tooltip data API when available; fall back to the
	-- classic OnTooltipSet* scripts otherwise. Both paths call the same
	-- handlers above.
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipSetUnit)
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, OnTooltipSetSpell)
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem)
	else
		GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
		GameTooltip:HookScript("OnTooltipSetSpell", OnTooltipSetSpell)
		GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
		if ItemRefTooltip then
			ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
		end
	end

	-- Blizzard doesn't allow unhooking, so the mouse-anchor hook stays
	-- attached for the life of the session; AnchorToMouse() itself checks
	-- the enabled/anchorToMouse settings every call and no-ops otherwise.
	GameTooltip:HookScript("OnUpdate", AnchorToMouse)
	hooksecurefunc(GameTooltip, "SetOwner", AnchorToMouse)
end

local configBuilt = false
local function BuildConfig()
	if configBuilt then return end
	configBuilt = true

	local panel = NU.Config:RegisterModulePanel("Tooltip", "Tooltip")
	NU.Config:AddModuleToggle(panel, "Tooltip")

	NU.Config:AddCheckbox(panel, "Anchor tooltip to mouse", "Keeps the tooltip attached to the cursor instead of its default screen position.",
		function() return db().anchorToMouse end,
		function(value) db().anchorToMouse = value end)

	NU.Config:AddCheckbox(panel, "Show unit/object ID", "Adds the NPC, vehicle, or pet ID taken from the unit's GUID.",
		function() return db().showUnitID end,
		function(value) db().showUnitID = value end)

	NU.Config:AddCheckbox(panel, "Show spell ID", "Adds the spell ID to spell tooltips.",
		function() return db().showSpellID end,
		function(value) db().showSpellID = value end)

	NU.Config:AddCheckbox(panel, "Show item ID", "Adds the item ID to item tooltips.",
		function() return db().showItemID end,
		function(value) db().showItemID = value end)

	NU.Config:AddCheckbox(panel, "Class-colour player names", "Colours a player's name in the tooltip by their class.",
		function() return db().classColorNames end,
		function(value) db().classColorNames = value end)

	NU.Config:AddCheckbox(panel, "Show distance to unit", "Adds an approximate distance in yards to the moused-over unit. Blizzard doesn't let addons read exact distances, so this shows a range band (< 10, 10-11, 11-28, or 28+ yards) instead of a precise number.",
		function() return db().showDistance end,
		function(value) db().showDistance = value end)
end

function Tooltip:OnEnable()
	HookTooltips()
	BuildConfig()
end
