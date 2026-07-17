---@type Warbandeer_Characters
local ns = select(2, ...)
local sort = table.sort

-- Great Vault reward tracks, keyed by the C_WeeklyRewards activity type
-- (Enum.WeeklyRewardChestThresholdType): 1 = M+ dungeons, 3 = raid, 6 = world.
local TRACK = { [1] = "Dungeons", [3] = "Raid", [6] = "World" }

-- Raid-lockout difficulty: a prestige rank (high → low, the primary sort key) and a short label.
-- Current-tier IDs are DifficultyUtil.ID.PrimaryRaid* (14 Normal / 15 Heroic / 16 Mythic / 17 LFR);
-- the legacy 10/25-man and 40-man rows keep an old lockout labelled rather than falling to "D<id>".
-- (The dump map in data/instances.lua is a separate, unrelated debug helper — its labels are wrong.)
local RAID_DIFF = {
  [16] = { rank = 6, label = "M"   }, -- PrimaryRaidMythic
  [15] = { rank = 5, label = "H"   }, -- PrimaryRaidHeroic
  [14] = { rank = 4, label = "N"   }, -- PrimaryRaidNormal
  [17] = { rank = 3, label = "LFR" }, -- PrimaryRaidLFR
  [7]  = { rank = 3, label = "LFR" }, -- RaidLFR (legacy)
  [6]  = { rank = 2, label = "25H" },
  [5]  = { rank = 2, label = "10H" },
  [4]  = { rank = 1, label = "25N" },
  [3]  = { rank = 1, label = "10N" },
  [9]  = { rank = 1, label = "40"  },
}

---@class VaultSlot
---@field threshold integer  activities needed to unlock this slot (e.g. raid 2/4/6, M+ 1/4/8)
---@field progress integer   current activity count toward this track
---@field complete boolean   slot unlocked (progress >= threshold)
---@field ilvl integer?      reward item level, resolved for unlocked slots only

---@class VaultTracks
---@field Raid VaultSlot[]?       three raid slots, ordered by ascending threshold
---@field Dungeons VaultSlot[]?   three Mythic+ slots
---@field World VaultSlot[]?      three world slots

---@class RaidLock
---@field name string
---@field progress integer     bosses defeated this lockout
---@field total integer        total encounters
---@field difficultyID integer
---@field label string         short difficulty label (N / H / M / LFR)
---@field rank integer         difficulty prestige rank (sort key)
---@field reset integer?       server-time epoch when the lockout resets

---@class Warbandeer_Characters
---@field RaidDifficultyLabel fun(difficultyID: integer): string
---@field SummarizeVaultSlots fun(activities: { type: integer, threshold: integer, progress: integer, ilvl: integer? }[]): VaultTracks
---@field RaidLocks fun(locks: table<integer, table<integer, table>>?): RaidLock[]

-- Short label for a raid difficulty ID (falls back to "D<id>" for anything unmapped).
function ns.RaidDifficultyLabel(difficultyID)
  local d = RAID_DIFF[difficultyID]
  return d and d.label or ("D" .. tostring(difficultyID))
end

-- Group Great Vault activities into per-track ordered slots. The reward item levels are resolved by
-- the broker's get (the only WoW-API step); this pure shaping — bucket by track, order by threshold,
-- flag each slot unlocked — is unit-tested (spec/vaultslots_spec.lua).
function ns.SummarizeVaultSlots(activities)
  local tracks = {}
  for _, a in ipairs(activities) do
    local key = TRACK[a.type]
    if key then
      local list = tracks[key]
      if not list then list = {}; tracks[key] = list end
      list[#list + 1] = {
        threshold = a.threshold,
        progress  = a.progress,
        complete  = a.progress >= a.threshold,
        ilvl      = a.ilvl,
      }
    end
  end
  for _, list in pairs(tracks) do
    sort(list, function(x, y) return x.threshold < y.threshold end)
  end
  return tracks
end

-- Flatten the per-character instance-lock store to raid lockouts only, sorted most-prestigious then
-- most-progressed first (name breaks ties for a deterministic order): the view shows [1] as the
-- "primary" raid and lists the rest in its tooltip. Pure — unit-tested.
function ns.RaidLocks(locks)
  local out = {}
  if not locks then return out end
  for _, byDiff in pairs(locks) do
    for difficultyID, l in pairs(byDiff) do
      if l.isRaid then
        local d = RAID_DIFF[difficultyID]
        out[#out + 1] = {
          name         = l.name,
          progress     = l.progress or 0,
          total        = l.total or 0,
          difficultyID = difficultyID,
          label        = d and d.label or ns.RaidDifficultyLabel(difficultyID),
          rank         = d and d.rank or 0,
          reset        = l.reset,
        }
      end
    end
  end
  sort(out, function(x, y)
    if x.rank ~= y.rank then return x.rank > y.rank end
    if x.progress ~= y.progress then return x.progress > y.progress end
    return x.name < y.name
  end)
  return out
end
