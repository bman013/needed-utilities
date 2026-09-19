local ADDON_NAME, ns = ...
local NU = ns.NU

local Config = {}
NU.Config = Config

local ROOT_NAME = "Needed Utilities"
local useModernSettings = Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterCanvasLayoutSubcategory

local rootCategory
local panels = {}

local function CreatePanel(displayName)
	local panel = CreateFrame("Frame")
	panel.name = displayName
	panel.nextY = -16
	return panel
end

local function EnsureRoot()
	if rootCategory then return rootCategory end

	local panel = CreatePanel(ROOT_NAME)

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(ROOT_NAME)

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetPoint("RIGHT", -16, 0)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetText("A modular utility framework. Select a module on the left to configure it.")

	if useModernSettings then
		rootCategory = Settings.RegisterCanvasLayoutCategory(panel, ROOT_NAME)
		Settings.RegisterAddOnCategory(rootCategory)
	else
		InterfaceOptions_AddCategory(panel)
		rootCategory = { panel = panel }
	end

	return rootCategory
end

--- Called once per module (typically from the module's OnEnable) to create a
--- dedicated options page nested under the "Needed Utilities" category.
--- Returns a plain frame the module can add widgets to via AddCheckbox.
function Config:RegisterModulePanel(moduleKey, displayName)
	if panels[moduleKey] then return panels[moduleKey].panel end

	local root = EnsureRoot()
	local panel = CreatePanel(displayName)

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(displayName)
	panel.nextY = -48

	if useModernSettings then
		panels[moduleKey] = { panel = panel, category = Settings.RegisterCanvasLayoutSubcategory(root, panel, displayName) }
	else
		panel.parent = ROOT_NAME
		InterfaceOptions_AddCategory(panel)
		panels[moduleKey] = { panel = panel }
	end

	return panel
end

--- Adds a checkbox bound to get()/set(value) getter/setter functions,
--- stacking it below the previous widget added to this panel.
function Config:AddCheckbox(panel, label, tooltipText, get, set)
	local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", 16, panel.nextY)
	checkbox.Text:SetText(label)
	checkbox.tooltipText = tooltipText
	checkbox:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
	end)
	checkbox:SetScript("OnShow", function(self)
		self:SetChecked(get() and true or false)
	end)
	panel.nextY = panel.nextY - 28
	return checkbox
end

function Config:Open()
	EnsureRoot()
	if useModernSettings then
		Settings.OpenToCategory(rootCategory:GetID())
	else
		-- InterfaceOptionsFrame_OpenToCategory has a long-standing Blizzard
		-- quirk where the first call can land on the wrong panel if the
		-- options frame hasn't been shown yet; calling it twice works around it.
		InterfaceOptionsFrame_OpenToCategory(ROOT_NAME)
		InterfaceOptionsFrame_OpenToCategory(ROOT_NAME)
	end
end
