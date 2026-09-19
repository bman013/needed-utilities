# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning](https://semver.org/).

## [0.1.0-beta.10] - 2026-09-19

### Fixed

- **Bags**: releasing a drag threw "attempt to call a nil value" on
  `frame:IsMoving()`. `IsMoving()` isn't an actual Frame method - it was
  confused with `IsMovable` (a different check, for whether movement is
  enabled at all). `StopMovingOrSizing()` is safe to call unconditionally
  regardless of whether a move is in progress, so the guard is removed
  rather than replaced. Dragging itself was already working correctly by
  this point (beta.9's frame-lookup and overlay fix); this only affected
  what happened on mouse-up.

## [0.1.0-beta.9] - 2026-09-19

### Fixed

- **Bags**: unlocking still didn't let the combined bags window move for
  some players. Two issues: the frame lookup assumed an exact global name
  (`ContainerFrameCombinedBags`) that may not match every client, and
  hooking the frame's own `OnMouseDown` only fires for clicks landing
  somewhere no child widget (item slots, dropdown, search box) has already
  claimed - if those cover the whole window, it never fires at all.
  Replaced with: a name-agnostic frame finder (falls back to scanning every
  existing frame via `EnumerateFrames` for one matching "CombinedBags"), and
  a dedicated overlay frame layered above every child widget that reliably
  wins hit-testing while unlocked, instead of hooking the container's own
  mouse handler. While unlocked, the whole window is now a pure drag
  handle (won't respond to item clicks); lock it again to resume normal use.
- Added `/nubags` as a quick diagnostic - reports whether the combined bags
  frame was found and hooked.

## [0.1.0-beta.8] - 2026-09-19

### Changed

- Options panel now groups every feature module (Tooltip, Bags,
  Nameplates) under a nested "Modules" category, separate from framework
  pages (About, Changelog) which stay directly under "Needed Utilities" -
  matching the requested layout. `Config:RegisterModulePanel` takes a new
  `underModules` flag; every module now passes it.

## [0.1.0-beta.7] - 2026-09-19

### Added

- **Nameplates module**: "Highlight quest-objective mobs" setting. Adds a
  gold border to the nameplate of any mob relevant to one of your current
  quests (via `UnitIsQuestBoss`, the same check Blizzard uses for the
  quest-skull icon), so you can prioritise it at a glance.
- Keybinding support (`Bindings.xml`): a "Toggle Bags Lock (Combined Bags)"
  action, unbound by default - set it under Key Bindings > AddOns > Needed
  Utilities.

### Changed

- **Renamed the Backpacks module to Bags.** A DB migration (schema v2)
  carries over its saved settings and window position automatically.
- **Reworked how the combined bags window is moved.** The previous
  Shift+drag-the-header approach depended on locating a specific label at
  runtime and click-propagation to avoid breaking the dropdown underneath -
  too many failure points, and it wasn't reliable in testing. Replaced with
  a lock/unlock toggle (checkbox in Bags settings, or the new keybinding):
  while unlocked, drag anywhere on the window's background to move it; item
  slots and the dropdown are separate child widgets and keep working
  normally either way. Always resets to locked on login.
- **Every module's settings now grey out and disable while that module's
  own "Enable" switch is off**, instead of staying clickable but inert.
- About and Changelog moved from `Core/` to `Modules/`, alongside every
  other panel - `Core/` is now just the framework internals (Version,
  Core, Config).

## [0.1.0-beta.6] - 2026-09-19

### Fixed

- Checkboxes across every options panel (Tooltip, Backpacks) could show
  unchecked on first opening a category even though the underlying setting
  was still on and working - most reliably seen right after replacing the
  addon folder and `/reload`ing. The checkbox state was only synced on its
  own `OnShow`, which doesn't reliably fire for a widget created while its
  parent panel happens to already be the visible/selected category (e.g.
  one the game remembered as last-viewed across the reload). Checkboxes now
  set their correct state immediately on creation, and every widget on a
  panel is also re-synced whenever that panel itself is shown.

## [0.1.0-beta.5] - 2026-09-19

### Added

- **Backpacks module**: "Allow moving the combined bags window" setting.
  Hold Shift and drag the "Combined Backpack" header to reposition the
  combined bags window; a plain click still opens its dropdown as normal.
  Position is saved and restored automatically. Deliberately scoped to just
  the header row, not the whole bag frame, since Shift+click on an item
  slot already links it in chat.
- **Changelog panel**, listed directly under About, showing a scrollable
  in-game copy of this file so players don't need to visit GitHub to see
  what changed. Kept in sync by hand with `Core/Changelog.lua`.

## [0.1.0-beta.4] - 2026-09-19

### Fixed

- **Tooltip**: fixed a "attempt to call a nil value" error hovering an
  equippable item that has something equipped in the same slot (e.g. in
  bags/vendor windows). Blizzard's shopping/comparison tooltip
  (`ShoppingTooltip1`/`2`) is routed through the same tooltip data callback
  as the main tooltip but doesn't implement `GetItem()`/`GetSpell()`/
  `GetUnit()`; `OnTooltipSetItem`, `OnTooltipSetSpell`, and `OnTooltipSetUnit`
  now check the method exists before calling it.

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
