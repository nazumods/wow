---@class ShadowsOfUI_Upgrade: AddOn
local ns = LibNAddOn(...)

-- ShadowsOfUI-Upgrade — gear-upgrade finder.
--
-- Reads the data layer (ns.api == WarbandeerApi, bound from X-NUI-API): each
-- character's equipped gear plus the loose equippable gear recorded in their bags
-- and the warband bank.  For a character it answers "is this item an ilvl upgrade
-- for a slot I can use?", annotated with how well the item's secondary stats match
-- the spec's stat priority (a small precomputed table — see data/statpriority.lua),
-- so this addon is fully standalone.
--
-- The computed result is published as the global ShadowsOfUI_UpgradeApi, which
-- Warbandeer consumes as an OptionalDep (mirroring WarbandeerBarsApi /
-- WarbandeerCollectedApi).  No saved variables — everything derives from the data
-- layer at query time.

-- Private data, filled by data/*.lua.
---@class ShadowsOfUI_Upgrade
---@field StatPriority table<string, table<integer, table<string, integer>>> [classToken][specIndex] = {crit,haste,mastery,versatility} stat→tier
ns.StatPriority = {}

-- Our published read-only API; methods are added in upgrade.lua.
---@class ShadowsOfUI_UpgradeApi
ShadowsOfUI_UpgradeApi = ShadowsOfUI_UpgradeApi or {}

---@class ShadowsOfUI_Upgrade
---@field UpgradeApi ShadowsOfUI_UpgradeApi

ns.UpgradeApi = ShadowsOfUI_UpgradeApi
