# Needed Utilities

A modular utility framework for World of Warcraft: Classic Forever, built to
make it easy to bolt on new small features (modules) over time without each
one reinventing saved variables, an options panel, or slash commands.

This is a beta release. Classic Forever is a new beta itself, so the
`## Interface` line in the `.toc` may not match your client's build exactly —
see [Installation](#installation) below if the addon doesn't load.

## Installation

1. Download the latest release zip from the
   [Releases page](https://github.com/bman013/needed-utilities/releases).
2. Extract it so you end up with `Interface/AddOns/NeededUtilities/` (the zip
   already contains the `NeededUtilities` folder — don't nest it further).
3. Restart the game or reload your UI (`/reload`).

If the addon doesn't show up in your AddOns list, your client's build number
probably isn't one of the ones listed in `NeededUtilities.toc` yet. Check
your build with:

```
/run print(select(4, GetBuildInfo()))
```

and either add that number to the `## Interface:` line, or enable
**Load out of date AddOns** in the AddOns menu as a stopgap.

## Slash commands

| Command | Description |
| --- | --- |
| `/nu` or `/nu config` | Open the options panel |
| `/nu version` | Print the installed addon version |
| `/nu modules` | List registered modules and whether they're enabled |
| `/nu enable <module>` | Enable a module (e.g. `/nu enable Tooltip`) |
| `/nu disable <module>` | Disable a module |

## Modules

### Tooltip

Adds a set of independently toggleable tooltip enhancements, all available in
`/nu config` under **Needed Utilities > Tooltip**:

- **Anchor tooltip to mouse** — keeps the tooltip attached to the cursor
  instead of its default screen position.
- **Show unit/object ID** — adds the NPC, vehicle, or pet ID read from the
  moused-over unit's GUID.
- **Show spell ID** — adds the spell ID to spell tooltips.
- **Show item ID** — adds the item ID to item tooltips.
- **Class-colour player names** — colours a player's name in the tooltip by
  their class.
- **Show distance to unit** — adds an approximate distance band (`< 10 yd`,
  `10-11 yd`, `11-28 yd`, or `28+ yd`) to the moused-over unit. Blizzard
  removed addons' access to exact unit distances years ago (an anti-cheat
  measure that applies to Classic too), so this uses `CheckInteractDistance`
  against its fixed duel/trade/inspect range thresholds — the same technique
  other range-display addons use. It's a band, not a precise number.

Each of these, plus a module-level enable/disable switch, is its own
checkbox — nothing is bundled together.

## Versioning

The addon follows [Semantic Versioning](https://semver.org/)
(`MAJOR.MINOR.PATCH`, with a `-beta.N` suffix for pre-release builds). The
`.toc`'s `## Version:` field is the single source of truth: `Core/Version.lua`
reads it at load time via `GetAddOnMetadata`, parses it, and exposes it as
`NeededUtilities.Version` for the rest of the addon (and for `/nu version`).

Saved variables are versioned separately via a `schemaVersion` stored in
`NeededUtilitiesDB`. When a future change needs to alter the shape of saved
settings, bump `Version.dbSchema` in `Core/Version.lua` and add the
corresponding upgrade step in `NU:MigrateDB()` in `Core/Core.lua`, so
existing users' settings get migrated forward instead of reset.

Release zips are named `NeededUtilities-<version>.zip` (see
`scripts/package.sh`), so the filename always matches what's in the `.toc`.

## FAQ

**If I delete and re-copy the `NeededUtilities` addon folder, do I lose my
settings?** No. Settings live in
`WTF/Account/<account>/SavedVariables/NeededUtilities.lua`, not in
`Interface/AddOns/NeededUtilities/` — they're entirely separate from the
addon's code. On login, `NU:InitializeDB()` loads whatever's already saved
there and layers in defaults for any settings that don't exist yet (e.g.
after updating to a version with a new checkbox), without touching values
you've already set. You'd only lose settings if you also delete your `WTF`
folder or reset your UI.

## Cutting a release

1. Bump `## Version:` in `NeededUtilities/NeededUtilities.toc` and add an
   entry to `CHANGELOG.md`. Commit and merge that to `main`.
2. Tag the merge commit to match, prefixed with `v`, and push the tag:

   ```
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. The `Release` GitHub Actions workflow (`.github/workflows/release.yml`)
   picks up the pushed tag, checks it matches the `.toc` version, builds the
   zip via `scripts/package.sh`, and publishes it as a GitHub release. A tag
   with a `-` in it (e.g. `v0.1.0-beta.1`) is published as a pre-release
   automatically.

## Adding a new module

Modules are self-contained files that register themselves with the
framework. A minimal module looks like:

```lua
local ADDON_NAME, ns = ...
local NU = ns.NU

local MyModule = NU:RegisterModule("MyModule", {})

MyModule.defaults = {
	enabled = true,
	someSetting = true,
}

function MyModule:OnEnable()
	local settings = NU:GetModuleDB("MyModule")
	-- do stuff, checking settings.someSetting as needed
end
```

Then:

1. Put the file under `NeededUtilities/Modules/<MyModule>/`.
2. Add it to the load order at the bottom of `NeededUtilities.toc`.
3. Optionally call `NU.Config:RegisterModulePanel(...)` and
   `NU.Config:AddCheckbox(...)` from `OnEnable` to add an options page —
   see `Modules/Tooltip/Tooltip.lua` for a full example.

The core framework handles saved-variable defaults, migration, enabling on
login, and the `/nu enable|disable` commands for you.

## Repository layout

```
NeededUtilities/            the addon itself (this folder is what gets zipped)
  NeededUtilities.toc
  Core/
    Version.lua              version parsing, single source of truth
    Core.lua                 module registry, SavedVariables, slash commands
    Config.lua                shared options-panel helper
    About.lua                About page (addon info pulled from the .toc)
  Modules/
    Tooltip/
      Tooltip.lua
scripts/
  package.sh                 builds dist/NeededUtilities-<version>.zip
```

## Contributing

Bug reports and pull requests are welcome via
[GitHub Issues](https://github.com/bman013/needed-utilities/issues).
