# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning](https://semver.org/).

## [0.1.0-beta.3] - 2026-09-19

### Added

- **Tooltip**: "Show distance to unit" setting, adding an approximate
  distance band (`< 10 yd`, `10-11 yd`, `11-28 yd`, `28+ yd`) to the
  moused-over unit's tooltip via `CheckInteractDistance`. Blizzard doesn't
  expose exact distances to addons, so this is a range band rather than a
  precise number.

### Notes

- Settings already survive removing and re-copying the addon folder - they
  live in `WTF/.../SavedVariables/NeededUtilities.lua`, not in
  `Interface/AddOns/NeededUtilities/`, and `NU:InitializeDB()` merges
  whatever's already saved with any new defaults on load. No code change
  was needed here; see the README FAQ for details.

## [0.1.0-beta.2] - 2026-09-19

### Added

- **About panel**, listed above the Tooltip module page under "Needed
  Utilities". Shows the addon name, version, description, and author, all
  pulled from the `.toc` metadata rather than duplicated in Lua, plus
  copyable links to the author's GitHub profile and the repo's issues page
  for bug reports and feature requests.
- `Config:AddSubheading`, `Config:AddText`, and `Config:AddCopyBox` helpers
  in `Core/Config.lua` for any module that wants to show plain text or a
  copyable link on its options page.

### Changed

- `## Author:` in the `.toc` now correctly credits
  [bman013](https://github.com/bman013/).

## [0.1.0-beta.1] - 2026-09-19

### Added

- Modular addon framework (`NeededUtilities` core): module registration,
  per-module SavedVariables namespacing with default-merging, a saved-variable
  schema version with a migration hook, and `/nu` slash commands
  (`config`, `version`, `modules`, `enable`, `disable`).
- Shared options-panel helper (`Core/Config.lua`) that any module can use to
  register its own settings page under a single "Needed Utilities" category,
  with automatic fallback between the modern Settings API and the classic
  Interface Options API.
- **Tooltip module**, individually configurable:
  - Anchor the tooltip to the mouse cursor.
  - Show the NPC/vehicle/pet ID from the moused-over unit's GUID.
  - Show the spell ID on spell tooltips.
  - Show the item ID on item tooltips.
  - Class-colour player names in the tooltip.
