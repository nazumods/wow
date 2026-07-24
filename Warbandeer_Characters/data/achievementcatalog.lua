---@type Warbandeer_Characters
local ns = select(2, ...)

-- Single source of truth for the achievement ids Warbandeer's views track: the Overview
-- checklist (per expansion), the Milestones collectible-reward grid, and the Legion
-- hidden-artifact grid. Lives here (not in Warbandeer) because data/achievements.lua needs
-- the full id set to snapshot regardless of whether any view is open.

---@class Warbandeer_Characters
---@field AchievementCatalog table
ns.AchievementCatalog = {
  checklist = {
    wwi = {20597, 40791, 20596, 40309, 40360, 41052, 40618, 41818, 41970, 41808, 61017},
    midnight = {
      62386, -- Light Up the Night (meta)
      62110, -- Loremaster of Midnight
      62104, -- Midnight Lore Hunter
      61741, -- Delve Loremaster: Midnight
      61506, -- Allied Race: Haranir
      61839, -- (existing)
      62261, -- Forever Song (Eversong Woods story)
      61453, -- Making an Amani Out of You (Zul'Aman story)
      62260, -- That's Aln, Folks! (Harandar story)
      62256, -- Yelling into the Voidstorm (Voidstorm story)
      61957, -- Sojourner of Eversong Woods
      61452, -- Sojourner of Zul'Aman
      61739, -- Sojourner of Harandar
      61864, -- Sojourner of Voidstorm
    },
    dragonflight = {
      19458, -- A World Awoken (Dragonflight meta)
      16585, -- Loremaster of the Dragon Isles
      16334, -- Waking Hope (The Waking Shores story)
      15394, -- Ohn'a'Roll (Ohn'ahran Plains story)
      16336, -- Azure Spanner (The Azure Span story)
      16363, -- Just Don't Ask Me to Spell It (Thaldraszus story)
      16401, -- Sojourner of the Waking Shores
      16405, -- Sojourner of Ohn'ahran Plains
      16428, -- Sojourner of Azure Span
      16398, -- Sojourner of Thaldraszus
    },
  },
  milestones = {
    61467, 42189, 42188, 42187, 61451, 40953, 41186, 41119, 40894, 40859, 40542, 40504, 40210, 20595, 20501, 19719,
    19507, 19408, 17773, 17529, 13723, 13475, 13473, 13049, 13018, 12997, 12582, 11699, 11258, 11257, 11124, 10996,
    10698,  9415,  8316,  7322,  6981,  5442,  5245,  5223,  4859,  4405,  1157,  1153,   940,   938,   231,   229,
      222,   221,   213,   212,   200,   158
  },
  legion = {10459, 11160, 11163},
  -- A tracked id whose completion is also satisfied by an alternate id (e.g. a Heroic variant
  -- awarding the same meta). API:IsAchievementComplete ORs the two.
  metaAlts = {
    [41818] = 41820, -- Midnight meta, also satisfied by its Heroic variant
  },
}
