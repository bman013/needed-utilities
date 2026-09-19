local ADDON_NAME, ns = ...
local NU = ns.NU

local Backpacks = NU:RegisterModule("Backpacks", {})

Backpacks.defaults = {
	enabled = true,
	moveableCombinedBags = true,
}

local function db()
	return NU:GetModuleDB("Backpacks")
end

-- Fallback height (covers the title bar plus the "Combined Backpack"
-- dropdown row) if the label below can't be found and we have to guess.
local FALLBACK_HEADER_HEIGHT = 46

--- Looks for the "Combined Backpack" label so the drag handle can be sized
--- to just that row instead of guessing pixel heights - checked one level
--- into child frames too, since it may live inside a button/dropdown widget
--- rather than directly on the container frame. English client text only.
local function FindCombinedBackpackLabel(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			local text = region:GetText()
			if text and text:find("Combined") then
				return region
			end
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		for _, region in ipairs({ child:GetRegions() }) do
			if region.GetObjectType and region:GetObjectType() == "FontString" then
				local text = region:GetText()
				if text and text:find("Combined") then
					return region
				end
			end
		end
	end
	return nil
end

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

local frameHooked = false
local function HookCombinedBags(frame)
	if frameHooked then return end
	frameHooked = true

	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	RestorePosition(frame)

	-- A click-through overlay over just the header row: a plain click still
	-- reaches the "Combined Backpack" dropdown underneath as normal, and
	-- only Shift+drag moves the frame. This deliberately doesn't cover the
	-- whole bag frame - Shift+click on an item slot already links it in
	-- chat, and this must not interfere with that.
	local label = FindCombinedBackpackLabel(frame)
	local dragHandle = CreateFrame("Frame", nil, frame)
	dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	if label then
		dragHandle:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 8, -4)
	else
		dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
		dragHandle:SetHeight(FALLBACK_HEADER_HEIGHT)
	end
	dragHandle:EnableMouse(true)
	dragHandle:SetPropagateMouseClicks(true)
	dragHandle:SetPropagateMouseMotion(true)

	dragHandle:SetScript("OnMouseDown", function(self, button)
		local settings = db()
		if button ~= "LeftButton" then return end
		if not (settings and settings.enabled and settings.moveableCombinedBags) then return end
		if not IsShiftKeyDown() then return end
		frame:StartMoving()
	end)

	dragHandle:SetScript("OnMouseUp", function()
		if frame:IsMoving() then
			frame:StopMovingOrSizing()
			SavePosition(frame)
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

	local panel = NU.Config:RegisterModulePanel("Backpacks", "Backpacks")

	NU.Config:AddCheckbox(panel, "Enable Backpacks module", "Master switch for backpack-related enhancements below.",
		function() return db().enabled end,
		function(value) NU:SetModuleEnabled("Backpacks", value) end)

	NU.Config:AddCheckbox(panel, "Allow moving the combined bags window", "Hold Shift and drag the \"Combined Backpack\" header to reposition the combined bags window. A plain click still opens its dropdown as normal.",
		function() return db().moveableCombinedBags end,
		function(value) db().moveableCombinedBags = value end)
end

function Backpacks:OnEnable()
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
