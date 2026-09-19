local ADDON_NAME, ns = ...
local NU = ns.NU

-- Bindings.xml at the addon root picks this display name up automatically.
BINDING_NAME_NEEDEDUTILITIES_TOGGLE_BAGSLOCK = "Toggle Bags Lock (Combined Bags)"

local Bags = NU:RegisterModule("Bags", {})

Bags.defaults = {
	enabled = true,
}

local function db()
	return NU:GetModuleDB("Bags")
end

local combinedBagsFrame
local unlockLabel
local unlockCheckbox
local locked = true -- always starts locked each session; only the saved position persists

local function SavePosition(frame)
	local settings = db()
	if not settings then return end

	local left, bottom = frame:GetLeft(), frame:GetBottom()
	if not left or not bottom then return end

	local scale = frame:GetEffectiveScale()
	settings.combinedBagsPosition = { x = left * scale, y = bottom * scale }
end

local function RestorePosition(frame)
	local settings = db()
	local saved = settings and settings.combinedBagsPosition
	if not saved then return end

	local scale = frame:GetEffectiveScale()
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", saved.x / scale, saved.y / scale)
end

local function SetLocked(value)
	locked = value
	if unlockLabel then unlockLabel:SetShown(not locked) end
	if unlockCheckbox then unlockCheckbox:SetChecked(not locked) end
end

--- Bound to the keybinding (Bindings.xml -> BINDING_NAME_NEEDEDUTILITIES_TOGGLE_BAGSLOCK).
function NeededUtilities_ToggleBagsLock()
	local settings = db()
	if not (settings and settings.enabled) then return end
	SetLocked(not locked)
	NU:Print(locked and "Bags locked." or "Bags unlocked - drag the combined bags window's background to move it.")
end

local frameHooked = false
local function HookCombinedBags(frame)
	if frameHooked then return end
	frameHooked = true
	combinedBagsFrame = frame

	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	-- Ensures background clicks reach our handler below; item slots, the
	-- dropdown, and the search box are separate child widgets that manage
	-- their own mouse state independently, so this doesn't affect them.
	frame:EnableMouse(true)
	RestorePosition(frame)

	unlockLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	unlockLabel:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	unlockLabel:SetTextColor(1, 0.82, 0)
	unlockLabel:SetText("Bags unlocked - drag the background to move")
	unlockLabel:Hide()

	-- HookScript (not SetScript) so we add to whatever Blizzard's own
	-- handlers do here rather than replacing them.
	frame:HookScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and not locked then
			self:StartMoving()
		end
	end)
	frame:HookScript("OnMouseUp", function(self)
		if self:IsMoving() then
			self:StopMovingOrSizing()
			SavePosition(self)
		end
	end)
end

--- The combined bags frame may not exist yet the moment we try (bag frames
--- can be created lazily), so this gets retried on BAG_UPDATE until it works.
local function TryHook()
	local frame = _G.ContainerFrameCombinedBags
	if not frame then return false end
	HookCombinedBags(frame)
	return true
end

local configBuilt = false
local function BuildConfig()
	if configBuilt then return end
	configBuilt = true

	local panel = NU.Config:RegisterModulePanel("Bags", "Bags", true)
	NU.Config:AddModuleToggle(panel, "Bags")

	unlockCheckbox = NU.Config:AddCheckbox(panel, "Bags unlocked (drag to move)",
		"While checked, click and drag anywhere on the combined bags window's background (not on an item) to reposition it. Always resets to locked on login. You can also toggle this with a keybinding - see Game Menu > Key Bindings > AddOns > Needed Utilities.",
		function() return not locked end,
		function(value) SetLocked(not value) end)
end

function Bags:OnEnable()
	BuildConfig()

	if not TryHook() then
		local watcher = CreateFrame("Frame")
		watcher:RegisterEvent("BAG_UPDATE")
		watcher:SetScript("OnEvent", function(self)
			if TryHook() then
				self:UnregisterAllEvents()
			end
		end)
	end
end
