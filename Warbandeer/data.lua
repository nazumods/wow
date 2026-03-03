local _, ns = ...
local Strings = ns.Colors.Strings

ns.data = {}

-- local gearTiers = {
--   explorer = 98,
--   adventurer = 102,
--   veteran = 108,
--   champion = 121,
--   hero = 134,
--   mythic = 147,
-- }

-- Ready for Midnight
local gearTiers = {
  explorer = 207,
  adventurer = 220,
  veteran = 233,
  champion = 246,
  hero = 259,
  mythic = 272,
}

ns.data.gearTiers = gearTiers

function ns.IlvlColor(ilvl)
  if ilvl >= gearTiers.hero then return ITEM_LEGENDARY_COLOR:WrapTextInColorCode(ilvl)
  elseif ilvl >= gearTiers.champion then return ITEM_EPIC_COLOR:WrapTextInColorCode(ilvl)
  elseif ilvl >= gearTiers.veteran then return ITEM_SUPERIOR_COLOR:WrapTextInColorCode(ilvl)
  elseif ilvl >= gearTiers.adventurer then return ITEM_GOOD_COLOR:WrapTextInColorCode(ilvl)
  elseif ilvl >= gearTiers.explorer then return ITEM_STANDARD_COLOR:WrapTextInColorCode(ilvl)
  else return ITEM_POOR_COLOR:WrapTextInColorCode(ilvl)
  end
end

-- doesn't seem a good way to get this via the api
-- except to crawl the discovered factions by expanding/collapsing what's shown in the standard rep window
-- which would need to be saved in db, at which point why not just hardcode it from wago:
-- https://wago.tools/db2/Faction?filter%5BExpansion%5D=10&page=1
local minorFactions = {}
local minorFactionMaxStanding = {}
-- 2600 = { -- Severed Threads
minorFactions[2600] = {
  2601, -- weaver
  2605, -- general
  2607, -- vizier
}
minorFactionMaxStanding[2600] = 20000
-- cartels of undermine
minorFactions[2653] = {
  2669, -- darkfuse solutions
  2671, -- venture company
  2673, -- bilgewater cartel
  2675, -- blackwater cartel
  2677, -- steamwheedle cartel
}
minorFactionMaxStanding[2653] = 42000

minorFactionMaxStanding[2170] = 42000 -- Argussian Reach
minorFactionMaxStanding[2045] = 42000 -- Armies of Legionfall
minorFactionMaxStanding[2165] = 42000 -- Army of the Light
minorFactionMaxStanding[1900] = 42000 -- Court of Farondis
minorFactionMaxStanding[1883] = 42000 -- Dreamweavers
minorFactionMaxStanding[1828] = 42000 -- Highmountain Tribe
minorFactionMaxStanding[1859] = 42000 -- The Nightfallen
minorFactionMaxStanding[1894] = 42000 -- The Wardens
minorFactionMaxStanding[1948] = 42000 -- Valarjar

ns.data.minorFactions = minorFactions
ns.data.minorFactionMaxStanding = minorFactionMaxStanding
