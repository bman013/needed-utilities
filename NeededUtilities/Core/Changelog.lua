local ADDON_NAME, ns = ...
local NU = ns.NU

-- Kept in sync by hand with CHANGELOG.md in the repo, which stays the
-- authoritative record; this is a compact copy players can read in-game
-- without visiting GitHub. Newest first.
local ENTRIES = {
	{
		version = "0.1.0-beta.6",
		date = "2026-09-19",
		notes = {
			"Fixed: checkboxes could show unchecked on first opening a category even though the setting was still on, most reliably seen right after replacing the addon folder and /reload. Widgets now set correct state immediately and re-sync whenever their panel is shown.",
		},
	},
	{
		version = "0.1.0-beta.5",
		date = "2026-09-19",
		notes = {
			"Added: Backpacks module. Hold Shift and drag the \"Combined Backpack\" header to move the combined bags window.",
			"Added: this Changelog panel.",
		},
	},
	{
		version = "0.1.0-beta.4",
		date = "2026-09-19",
		notes = {
			"Fixed: an error on equippable items you already have something equipped in - Blizzard's comparison tooltip doesn't support GetItem/GetSpell/GetUnit.",
		},
	},
	{
		version = "0.1.0-beta.3",
		date = "2026-09-19",
		notes = {
			"Added: Tooltip \"Show distance to unit\" setting - an approximate range band, since Blizzard doesn't expose exact distances to addons.",
		},
	},
	{
		version = "0.1.0-beta.2",
		date = "2026-09-19",
		notes = {
			"Added: About panel, with addon info, author, and support links pulled from the .toc.",
		},
	},
	{
		version = "0.1.0-beta.1",
		date = "2026-09-19",
		notes = {
			"Added: initial release - the core framework and the Tooltip module.",
		},
	},
}

-- Registered immediately (not deferred to an OnEnable), same as About.lua,
-- so it's listed directly under About and ahead of every module's panel.
local panel = NU.Config:RegisterModulePanel("Changelog", "Changelog")
NU.Config:AddChangelog(panel, ENTRIES)
