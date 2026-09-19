local ADDON_NAME, ns = ...
local NU = ns.NU

-- Bindings.xml at the addon root picks this display name up automatically.
BINDING_NAME_NEEDEDUTILITIES_TOGGLE_BAGSLOCK = "Toggle Bags Lock (Combined Bags)"

local Bags = NU:RegisterModule("Bags", {})

Bags.defaults = {
	enabled = false,
}

local function db()
	return NU:GetModuleDB("Bags")
end

local combinedBagsFrame
local lockButton
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

local function UpdateLockButton()
	if not lockButton then return end
	local settings = db()
	lockButton:SetShown(settings and settings.enabled and true or false)
	if locked then
		lockButton.bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
	else
		lockButton.bg:SetColorTexture(1, 0.3, 0.3, 0.9)
	end
end

local function ApplyLockState()
	if unlockLabel then unlockLabel:SetShown(not locked) end
	UpdateLockButton()
end

local function SetLocked(value)
	locked = value
	ApplyLockState()
	if unlockCheckbox then unlockCheckbox:SetChecked(not locked) end
	if value and combinedBagsFrame then
		-- Belt-and-suspenders: also save on the moment it's locked, not
		-- just on every drag release.
		SavePosition(combinedBagsFrame)
	end
end

--- Bound to the keybinding (Bindings.xml -> BINDING_NAME_NEEDEDUTILITIES_TOGGLE_BAGSLOCK).
function NeededUtilities_ToggleBagsLock()
	local settings = db()
	if not (settings and settings.enabled) then return end
	SetLocked(not locked)
	NU:Print(locked and "Bags locked." or "Bags unlocked - drag the title bar to move the window.")
end

local function CreateLockButton(frame)
	local button = CreateFrame("Button", nil, frame)
	button:SetSize(18, 18)
	if frame.CloseButton then
		button:SetPoint("RIGHT", frame.CloseButton, "LEFT", -2, 0)
	else
		button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -6)
	end
	button:SetFrameLevel(frame:GetFrameLevel() + 10)

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	button.bg = bg

	local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
	border:SetAllPoints()
	if border.SetBackdrop then
		border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
		border:SetBackdropBorderColor(0, 0, 0, 0.6)
	end

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		if locked then
			GameTooltip:SetText("Bags locked", 1, 1, 1)
			GameTooltip:AddLine("Click to unlock. While unlocked, drag the title bar to move the window.", nil, nil, nil, true)
		else
			GameTooltip:SetText("Bags unlocked", 1, 0.4, 0.4)
			GameTooltip:AddLine("Drag the title bar to move the window. Click to lock it in place.", nil, nil, nil, true)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnClick", function()
		local settings = db()
		if not (settings and settings.enabled) then return end
		SetLocked(not locked)
	end)

	return button
end

local frameHooked = false
local function HookCombinedBags(frame)
	if frameHooked then return end
	frameHooked = true
	combinedBagsFrame = frame

	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	RestorePosition(frame)

	-- Drag only from the title bar (TitleContainer), not the whole window:
	-- hooking a widget's own mouse handlers only fires for clicks that land
	-- somewhere no child widget has already claimed, and the title bar
	-- doesn't overlap the item-slot grid at all - so this can never
	-- intercept an item click, unlike an overlay covering the whole window.
	local dragZone = frame.TitleContainer or frame
	dragZone:EnableMouse(true)

	dragZone:HookScript("OnMouseDown", function(self, button)
		local settings = db()
		if button == "LeftButton" and not locked and settings and settings.enabled then
			frame:StartMoving()
		end
	end)
	dragZone:HookScript("OnMouseUp", function(self)
		-- StopMovingOrSizing is safe to call even if nothing is currently
		-- being moved (there's no IsMoving() method to guard it with).
		frame:StopMovingOrSizing()
		SavePosition(frame)
	end)

	unlockLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	unlockLabel:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	unlockLabel:SetTextColor(1, 0.82, 0)
	unlockLabel:SetText("Bags unlocked - drag the title bar to move")
	unlockLabel:Hide()

	lockButton = CreateLockButton(frame)

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
		"While checked, click and drag the combined bags window's title bar to reposition it. There's also a lock button next to its close button that does the same thing. Always resets to locked on login, but the position is saved as soon as you lock it (or release a drag). You can also toggle this with a keybinding - see Game Menu > Key Bindings > AddOns > Needed Utilities.",
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
