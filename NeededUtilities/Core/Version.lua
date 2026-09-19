local ADDON_NAME, ns = ...

local Version = {}
ns.Version = Version

local function GetAddonMetadata(field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(ADDON_NAME, field)
	end
	return GetAddOnMetadata(ADDON_NAME, field)
end

-- The .toc's "## Version:" field is the single source of truth for the
-- addon version. Everything below just parses and exposes it, so there is
-- only ever one place to bump when cutting a release.
Version.full = GetAddonMetadata("Version") or "0.0.0"

-- Bump this whenever the shape of NeededUtilitiesDB changes, and add the
-- corresponding step to NU:MigrateDB() in Core.lua so old saved variables
-- get carried forward instead of reset.
Version.dbSchema = 2

local major, minor, patch, prerelease = Version.full:match("^(%d+)%.(%d+)%.(%d+)%-?(.-)$")
Version.major = tonumber(major) or 0
Version.minor = tonumber(minor) or 0
Version.patch = tonumber(patch) or 0
Version.prerelease = (prerelease and prerelease ~= "") and prerelease or nil
Version.isPrerelease = Version.prerelease ~= nil

function Version:IsAtLeast(major, minor, patch)
	major, minor, patch = major or 0, minor or 0, patch or 0
	if self.major ~= major then return self.major > major end
	if self.minor ~= minor then return self.minor > minor end
	return self.patch >= patch
end

function Version:ToString()
	return self.full
end
