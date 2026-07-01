---@class ShadowsOfUI_Collectibles
local ns = select(2, ...)

-- Collectibles the game doesn't flag as "already known" on their own tooltip, so
-- their owned-state has to be inferred by hand. These are factual item/quest IDs.

-- Quest-reward blueprints & soulshapes: owned once their granting quest is complete.
---@type table<integer, integer>  itemID -> questID
ns.QuestItems = {
  -- Warlords of Draenor — shipyard equipment blueprints (Alliance / Horde pairs)
  [128491] = 39359, [128251] = 39359, -- Equipment Blueprint: Tuskarr Fishing Net
  [128250] = 39358, [128489] = 39358, -- Equipment Blueprint: Unsinkable
  -- Shadowlands — Night Fae soulshapes
  [181313] = 62420, [181314] = 62421, [182165] = 62422, [182166] = 62423,
  [182168] = 62424, [182169] = 62425, [182170] = 62426, [182171] = 62427,
  [182172] = 62428, [182174] = 62429, [182175] = 62430, [182176] = 62431,
  [182177] = 62432, [182178] = 62433, [182179] = 62434, [182180] = 62435,
  [182181] = 62437, [182182] = 62438, [182183] = 62439, [182184] = 62440,
  [182185] = 62436,
}

-- Items whose owned-state is read off a *different* item's link field. Value is
-- { sourceItemID, linkFieldIndex, expectedValue } — the source item's link is
-- split on ":" and field `linkFieldIndex` must equal `expectedValue`.
---@type table<integer, integer[]>
ns.SpecialItems = {
  -- Legion — Krokul Flute is "known" once the Flight Master's Whistle is upgraded
  [152964] = { 141605, 11, 269 },
}

-- Containers whose contents may be individually known; the container counts as
-- known only when *every* listed item inside it is known.
---@type table<integer, integer[]>
ns.ContainerItems = {
  -- Vanilla — firework recipe bundles
  [21740] = { 21724, 21725, 21726 }, -- Small Rocket Recipes
  [21741] = { 21730, 21731, 21732 }, -- Cluster Rocket Recipes
  [21742] = { 21727, 21728, 21729 }, -- Large Rocket Recipes
  [21743] = { 21733, 21734, 21735 }, -- Large Cluster Rocket Recipes
  -- Warlords of Draenor
  [128319] = { 128318 },             -- Void-Shrouded Satchel -> Touch of the Void
}
