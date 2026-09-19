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
local dragOverlay
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

local function ApplyLockState()
	if dragOverlay then
		-- The overlay only intercepts clicks while unlocked; locked, it's
		-- fully click-through so bag/item interaction is untouched.
		dragOverlay:EnableMouse(not locked)
	end
	if unlockLabel then unlockLabel:SetShown(not locked) end
end

local function SetLocked(value)
	locked = value
	ApplyLockState()
	if unlockCheckbox then unlockCheckbox:SetChecked(not locked) end
end

--- Bound to the keybinding (Bindings.xml -> BINDING_NAME_NEEDEDUTILITIES_TOGGLE_BAGSLOCK).
function NeededUtilities_ToggleBagsLock()
	local settings = db()
	if not (settings and settings.enabled) then return end
	SetLocked(not locked)
	NU:Print(locked and "Bags locked." or "Bags unlocked - drag the combined bags window to move it.")
end

local frameHooked = false
local function HookCombinedBags(frame)
	if frameHooked then return end
	frameHooked = true
	combinedBagsFrame = frame

	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	RestorePosition(frame)

	-- A dedicated frame layered ABOVE every one of the bag window's own
	-- child widgets (item slots, the dropdown, the search box) so it always
	-- wins hit-testing regardless of whether those widgets happen to cover
	-- the whole window - hooking the container's own OnMouseDown isn't
	-- reliable, since it only fires for clicks that land somewhere no child
	-- widget has already claimed. This overlay is the whole window while
	-- unlocked (it deliberately blocks item clicks too - you're moving the
	-- window, not using it, until you lock it again) and fully inert while
	-- locked.
	dragOverlay = CreateFrame("Frame", nil, frame)
	dragOverlay:SetAllPoints(frame)
	dragOverlay:SetFrameStrata(frame:GetFrameStrata())
	dragOverlay:SetFrameLevel(frame:GetFrameLevel() + 50)
	dragOverlay:EnableMouse(false)

	dragOverlay:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			frame:StartMoving()
		end
	end)
	dragOverlay:SetScript("OnMouseUp", function(self)
		-- StopMovingOrSizing is safe to call even if nothing is currently
		-- being moved (there's no IsMoving() method to guard it with).
		frame:StopMovingOrSizing()
		SavePosition(frame)
	end)

	unlockLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	unlockLabel:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	unlockLabel:SetTextColor(1, 0.82, 0)
	unlockLabel:SetText("Bags unlocked - drag anywhere on the window to move it")
	unlockLabel:Hide()

	ApplyLockState()
end

--- Finds the combined bags frame without assuming its exact global name -
--- the fast path checks the name it has in current clients, and
--- EnumerateFrames (which walks every existing frame) is a name-agnostic
--- fallback matching anything with "CombinedBags" in its frame name.
local function FindCombinedBagsFrame()
	if _G.ContainerFrameCombinedBags then
		return _G.ContainerFrameCombinedBags
	end

	local frame = EnumerateFrames()
	while frame do
		local name = frame.GetName and frame:GetName()
		if name and name:find("CombinedBags") then
			return frame
		end
		frame = EnumerateFrames(frame)
	end

	return nil
end

--- The combined bags frame may not exist yet the moment we try (bag frames
--- can be created lazily), so this gets retried on BAG_UPDATE until it works.
local function TryHook()
	local frame = FindCombinedBagsFrame()
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
		"While checked, click and drag anywhere on the combined bags window to reposition it (it won't respond to item clicks while unlocked). Always resets to locked on login. You can also toggle this with a keybinding - see Game Menu > Key Bindings > AddOns > Needed Utilities.",
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

--- Quick diagnostic in case the combined bags frame still isn't found on a
--- given client - reports what (if anything) was hooked.
SLASH_NEEDEDUTILITIESBAGS1 = "/nubags"
SlashCmdList["NEEDEDUTILITIESBAGS"] = function()
	if combinedBagsFrame then
		NU:Print(("Bags: hooked frame '%s'. Locked: %s"):format(combinedBagsFrame:GetName() or "<unnamed frame>", tostring(locked)))
	else
		NU:Print("Bags: combined bags frame not found yet. Open your bags (B) and run /nubags again.")
	end
end
