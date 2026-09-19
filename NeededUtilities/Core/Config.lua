local ADDON_NAME, ns = ...
local NU = ns.NU

local Config = {}
NU.Config = Config

local ROOT_NAME = "Needed Utilities"
local useModernSettings = Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterCanvasLayoutSubcategory

local rootCategory
local modulesCategory
local panels = {}

local function CreatePanel(displayName)
	local panel = CreateFrame("Frame")
	panel.name = displayName
	panel.nextY = -16
	panel.refreshers = {}
	panel.dependentWidgets = {}
	-- Belt-and-suspenders: re-sync every widget on this panel whenever the
	-- panel itself is shown (e.g. switching to it in the category list),
	-- rather than trusting each individual widget's own OnShow to fire -
	-- a freshly created widget whose parent panel happened to already be
	-- the selected/visible category (e.g. remembered from before a
	-- /reload) never gets a real hidden->shown transition of its own.
	panel:SetScript("OnShow", function(self)
		for _, refresh in ipairs(self.refreshers) do
			refresh()
		end
	end)
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

local MODULES_NAME = "Modules"

--- The "Modules" group nested under the root category, holding every actual
--- feature module's panel (Tooltip, Bags, Nameplates, ...) separately from
--- framework pages like About/Changelog that sit directly under the root.
local function EnsureModulesCategory()
	if modulesCategory then return modulesCategory end

	local root = EnsureRoot()
	local panel = CreatePanel(MODULES_NAME)

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(MODULES_NAME)

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetPoint("RIGHT", -16, 0)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetText("Feature modules. Select one on the left to configure it.")

	if useModernSettings then
		modulesCategory = Settings.RegisterCanvasLayoutSubcategory(root, panel, MODULES_NAME)
	else
		panel.parent = ROOT_NAME
		InterfaceOptions_AddCategory(panel)
		modulesCategory = { panel = panel }
	end

	return modulesCategory
end

--- Called once per module (typically from the module's OnEnable) to create a
--- dedicated options page. Pass underModules = true (every actual feature
--- module should) to nest it under the "Modules" group; framework pages
--- like About/Changelog omit it to sit directly under the root category.
--- Returns a plain frame the module can add widgets to via AddCheckbox.
function Config:RegisterModulePanel(moduleKey, displayName, underModules)
	if panels[moduleKey] then return panels[moduleKey].panel end

	local parent = underModules and EnsureModulesCategory() or EnsureRoot()
	local panel = CreatePanel(displayName)
	panel.moduleKey = moduleKey

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(displayName)
	panel.nextY = -48

	if useModernSettings then
		panels[moduleKey] = { panel = panel, category = Settings.RegisterCanvasLayoutSubcategory(parent, panel, displayName) }
	else
		panel.parent = underModules and MODULES_NAME or ROOT_NAME
		InterfaceOptions_AddCategory(panel)
		panels[moduleKey] = { panel = panel }
	end

	return panel
end

--- Adds a checkbox bound to get()/set(value) getter/setter functions,
--- stacking it below the previous widget added to this panel. Unless this
--- is the panel's own module-enable toggle (isMasterToggle), it's greyed
--- out and disabled whenever the panel's module itself is off.
function Config:AddCheckbox(panel, label, tooltipText, get, set, isMasterToggle)
	local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", 16, panel.nextY)
	checkbox.Text:SetText(label)
	checkbox.tooltipText = tooltipText
	checkbox:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
	end)

	local function Refresh()
		checkbox:SetChecked(get() and true or false)
	end
	Refresh() -- correct immediately; don't rely solely on OnShow firing
	table.insert(panel.refreshers, Refresh)

	if panel.moduleKey and not isMasterToggle then
		local function RefreshEnabled()
			local moduleDB = NU:GetModuleDB(panel.moduleKey)
			local moduleEnabled = moduleDB and moduleDB.enabled
			checkbox:SetEnabled(moduleEnabled and true or false)
			checkbox.Text:SetFontObject(moduleEnabled and "GameFontHighlight" or "GameFontDisable")
		end
		RefreshEnabled()
		table.insert(panel.refreshers, RefreshEnabled)
		table.insert(panel.dependentWidgets, RefreshEnabled)
	end

	panel.nextY = panel.nextY - 28
	return checkbox
end

--- Adds the standard master "Enable X module" checkbox for a module panel.
--- Every other AddCheckbox added to this panel is automatically greyed out
--- and disabled while the module itself is off, and re-enabled immediately
--- (not just next time the panel is shown) when this is switched back on.
function Config:AddModuleToggle(panel, displayName)
	local moduleKey = panel.moduleKey
	return self:AddCheckbox(panel, ("Enable %s module"):format(displayName), "Master switch for everything below.",
		function() return NU:GetModuleDB(moduleKey).enabled end,
		function(value)
			NU:SetModuleEnabled(moduleKey, value)
			for _, refreshEnabled in ipairs(panel.dependentWidgets) do
				refreshEnabled()
			end
		end,
		true)
end

--- Adds a bold sub-heading line, stacking below the previous widget.
function Config:AddSubheading(panel, text)
	local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", 16, panel.nextY)
	fs:SetText(text)
	panel.nextY = panel.nextY - 20
	return fs
end

--- Adds a wrapping paragraph of plain text, stacking below the previous widget.
function Config:AddText(panel, text)
	local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT", 16, panel.nextY)
	fs:SetPoint("RIGHT", -16, 0)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	panel.nextY = panel.nextY - fs:GetStringHeight() - 12
	return fs
end

--- Adds a labelled, read-only, click-to-select text box - the standard WoW
--- addon pattern for giving players a URL they can copy into a browser,
--- since FontStrings can't be clicked as links.
function Config:AddCopyBox(panel, label, value)
	local labelFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	labelFS:SetPoint("TOPLEFT", 16, panel.nextY)
	labelFS:SetText(label)
	panel.nextY = panel.nextY - 18

	local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	box:SetSize(380, 20)
	box:SetPoint("TOPLEFT", 20, panel.nextY)
	box:SetAutoFocus(false)
	box:SetText(value)
	box:SetCursorPosition(0)
	box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

	panel.nextY = panel.nextY - 30
	return box
end

--- Renders a scrolling, read-only list of {version, date, notes={...}}
--- entries filling the rest of the panel below its title. Used for the
--- Changelog panel, but generic enough for any module with a long block of
--- text to show (a fixed canvas panel can't grow to fit it).
function Config:AddChangelog(panel, entries)
	local CONTENT_WIDTH = 520

	local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 16, panel.nextY)
	scrollFrame:SetPoint("BOTTOMRIGHT", -30, 16)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetWidth(CONTENT_WIDTH)
	scrollFrame:SetScrollChild(content)

	local y = 0
	for _, entry in ipairs(entries) do
		local heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		heading:SetPoint("TOPLEFT", 0, y)
		heading:SetWidth(CONTENT_WIDTH)
		heading:SetJustifyH("LEFT")
		heading:SetText(("v%s  |cff999999(%s)|r"):format(entry.version, entry.date))
		y = y - heading:GetStringHeight() - 4

		for _, line in ipairs(entry.notes) do
			local fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			fs:SetPoint("TOPLEFT", 12, y)
			fs:SetWidth(CONTENT_WIDTH - 12)
			fs:SetJustifyH("LEFT")
			fs:SetText("- " .. line)
			y = y - fs:GetStringHeight() - 4
		end

		y = y - 12
	end

	content:SetHeight(-y)
	panel.nextY = 0

	return content
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
