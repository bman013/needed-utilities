local ADDON_NAME, ns = ...

local NU = CreateFrame("Frame", "NeededUtilitiesFrame")
NeededUtilities = NU
ns.NU = NU

NU.name = ADDON_NAME
NU.modules = {}
NU.moduleOrder = {}

-- Shared keybinding section header, shown in Game Menu > Key Bindings >
-- AddOns. Individual bindings (BINDING_NAME_...) are declared next to the
-- feature they belong to, e.g. Modules/Bags/Bags.lua.
BINDING_HEADER_NEEDEDUTILITIES = "Needed Utilities"

local Version = ns.Version
local PREFIX = "|cff3fa0ffNeeded Utilities|r"

function NU:Print(msg)
	print(("%s: %s"):format(PREFIX, msg))
end

--- Modules call this at file-load time to register themselves with the
--- framework. moduleTable may define:
---   defaults          table of saved-variable defaults (enabled = true/false at minimum)
---   OnEnable(self)     called when the module is (re)enabled
---   OnDisable(self)    called when the module is disabled
function NU:RegisterModule(moduleKey, moduleTable)
	if self.modules[moduleKey] then
		error(("NeededUtilities: module '%s' is already registered"):format(moduleKey), 2)
	end
	moduleTable.key = moduleKey
	moduleTable.NU = self
	self.modules[moduleKey] = moduleTable
	table.insert(self.moduleOrder, moduleKey)
	return moduleTable
end

function NU:GetModule(moduleKey)
	return self.modules[moduleKey]
end

--- Returns the saved-variable table for a module (already merged with its defaults).
function NU:GetModuleDB(moduleKey)
	return self.db and self.db.modules[moduleKey]
end

local function ApplyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			ApplyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

function NU:MigrateDB()
	local db = self.db
	local from = db.schemaVersion or 0
	local to = Version.dbSchema

	if from < 2 and db.modules and db.modules.Backpacks then
		-- The Backpacks module was renamed to Bags.
		db.modules.Bags = db.modules.Bags or {}
		local old = db.modules.Backpacks
		if old.combinedBagsPosition and not db.modules.Bags.combinedBagsPosition then
			db.modules.Bags.combinedBagsPosition = old.combinedBagsPosition
		end
		if old.enabled ~= nil and db.modules.Bags.enabled == nil then
			db.modules.Bags.enabled = old.enabled
		end
		db.modules.Backpacks = nil
	end

	if from < 3 and db.modules and db.modules.Nameplates then
		-- The Nameplates module was removed.
		db.modules.Nameplates = nil
	end

	db.schemaVersion = to
end

function NU:InitializeDB()
	-- Distinguishes two very different failure modes if settings ever
	-- appear reset: the saved file not being found/read at all (this is
	-- true) versus being read but its content never actually updating
	-- (this is false, but values still look wrong) - see loadedFromDisk
	-- used in OnPlayerLogin below.
	self.loadedFromDisk = type(NeededUtilitiesDB) == "table"
	if not self.loadedFromDisk then
		NeededUtilitiesDB = {}
	end
	self.db = NeededUtilitiesDB
	self:MigrateDB()
	ApplyDefaults(self.db, { modules = {} })

	for _, moduleKey in ipairs(self.moduleOrder) do
		local moduleTable = self.modules[moduleKey]
		if type(self.db.modules[moduleKey]) ~= "table" then
			self.db.modules[moduleKey] = {}
		end
		ApplyDefaults(self.db.modules[moduleKey], moduleTable.defaults or { enabled = true })
	end
end

function NU:SetModuleEnabled(moduleKey, enabled)
	local moduleTable = self.modules[moduleKey]
	if not moduleTable then
		self:Print(("Unknown module '%s'."):format(moduleKey))
		return
	end

	local db = self:GetModuleDB(moduleKey)
	if db.enabled == enabled then return end
	db.enabled = enabled

	if enabled and moduleTable.OnEnable then
		moduleTable:OnEnable()
	elseif not enabled and moduleTable.OnDisable then
		moduleTable:OnDisable()
	end

	self:Print(("%s module %s."):format(moduleKey, enabled and "enabled" or "disabled"))
end

function NU:ListModules()
	self:Print("Registered modules:")
	for _, moduleKey in ipairs(self.moduleOrder) do
		local db = self:GetModuleDB(moduleKey)
		print(("  - %s: %s"):format(moduleKey, db.enabled and "|cff40ff40enabled|r" or "|cffff4040disabled|r"))
	end
end

function NU:OnAddonLoaded()
	self:InitializeDB()
	for _, moduleKey in ipairs(self.moduleOrder) do
		local moduleTable = self.modules[moduleKey]
		local db = self:GetModuleDB(moduleKey)
		if db.enabled and moduleTable.OnEnable then
			local ok, err = pcall(moduleTable.OnEnable, moduleTable)
			if not ok then
				self:Print(("Failed to enable module '%s': %s"):format(moduleKey, err))
			end
		end
	end
end

function NU:OnPlayerLogin()
	self:Print(("v%s loaded. Type |cffffffff/nu|r for options."):format(Version:ToString()))
	if Version.isPrerelease then
		self:Print("This is a beta build - please report issues on GitHub.")
	end
	self:Print(self.loadedFromDisk and "Loaded existing saved settings." or "No saved settings found - starting fresh.")
end

NU:RegisterEvent("ADDON_LOADED")
NU:RegisterEvent("PLAYER_LOGIN")
NU:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" then
		if addonName == ADDON_NAME then
			self:OnAddonLoaded()
			self:UnregisterEvent("ADDON_LOADED")
		end
	elseif event == "PLAYER_LOGIN" then
		self:OnPlayerLogin()
	end
end)

-- Slash commands: /nu and /needed
SLASH_NEEDEDUTILITIES1 = "/nu"
SLASH_NEEDEDUTILITIES2 = "/needed"
SlashCmdList["NEEDEDUTILITIES"] = function(msg)
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()

	if cmd == "version" then
		NU:Print(("version %s"):format(Version:ToString()))
	elseif cmd == "modules" then
		NU:ListModules()
	elseif cmd == "enable" and rest ~= "" then
		NU:SetModuleEnabled(rest, true)
	elseif cmd == "disable" and rest ~= "" then
		NU:SetModuleEnabled(rest, false)
	elseif cmd == "dump" and rest ~= "" then
		local moduleDB = NU:GetModuleDB(rest)
		if not moduleDB then
			NU:Print(("Unknown module '%s'."):format(rest))
		else
			NU:Print(("Saved settings for '%s' (schemaVersion %s):"):format(rest, tostring(NU.db.schemaVersion)))
			for key, value in pairs(moduleDB) do
				if type(value) ~= "table" then
					print(("  %s = %s"):format(key, tostring(value)))
				end
			end
		end
	elseif cmd == "config" or cmd == "options" or cmd == "" then
		NU.Config:Open()
	else
		NU:Print("Commands:")
		print("  /nu config          - open the options panel")
		print("  /nu version         - print the addon version")
		print("  /nu modules         - list modules and their state")
		print("  /nu enable <name>   - enable a module")
		print("  /nu disable <name>  - disable a module")
		print("  /nu dump <name>     - print a module's raw saved settings")
	end
end
