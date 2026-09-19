# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning](https://semver.org/).

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
