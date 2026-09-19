local ADDON_NAME, ns = ...
local NU = ns.NU
local Version = ns.Version

local function GetAddonMetadata(field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(ADDON_NAME, field)
	end
	return GetAddOnMetadata(ADDON_NAME, field)
end

-- All of this is pulled from the .toc rather than hard-coded here, so the
-- About panel can never drift out of sync with the addon's own metadata.
local title = GetAddonMetadata("Title") or ADDON_NAME
local notes = GetAddonMetadata("Notes")
local author = GetAddonMetadata("Author")
local website = GetAddonMetadata("X-Website")
local authorURL = GetAddonMetadata("X-Author-URL")

-- Registered immediately (not deferred to an OnEnable) so it exists, and is
-- listed, ahead of every module's own panel - modules only register theirs
-- once they're enabled, which happens after this file has already run.
local panel = NU.Config:RegisterModulePanel("About", "About")

NU.Config:AddSubheading(panel, ("%s  |cff999999v%s|r"):format(title, Version:ToString()))

if notes and notes ~= "" then
	NU.Config:AddText(panel, notes)
end

if author then
	NU.Config:AddText(panel, ("Author: %s"):format(author))
end

if authorURL then
	NU.Config:AddCopyBox(panel, "Author's GitHub profile (click, Ctrl+A, Ctrl+C):", authorURL)
end

NU.Config:AddText(panel, "Found a bug, or have an idea for a feature? Please raise it on GitHub - both issues and feature requests are welcome.")

if website then
	NU.Config:AddCopyBox(panel, "Report an issue / request a feature (click, Ctrl+A, Ctrl+C):", website .. "/issues")
end
