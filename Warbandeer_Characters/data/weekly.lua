---@type Warbandeer_Characters
local ns = select(2, ...)
local Set, ValueList, any = ns.lua.sets.Set, ns.lua.lists.values, ns.lua.maps.any
local Player = ns.wow.Player
local IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted
local GetActivities = C_WeeklyRewards.GetActivities
local GetOwnedKeystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel

local DMFQuests = {
  Alchemy = 29506,
  Blacksmithing = 29508,
  Cooking = 29509,
  Enchanting = 29510,
  Engineering = 29511,
  Fishing = 29513,
  Herbalism = 29514,
  Inscription = 29515,
  Jewelcrafting = 29516,
  LeatherWorking = 29517,
  Mining = 29518,
  Skinning = 29519,
  Tailoring = 29520,
}

---@class WeeklyBroker: Broker
local Weekly = ns:RegisterBroker("weeklies")
Weekly.fields = {
  ---@class WeeklyBroker
  ---@field DMF boolean
  DMF = {
    missing = false,
    ids = ValueList(DMFQuests),
    resetOn = ns.RESET_SUNDAY,
    get = function(_, _, current)
      -- Once completed, stay completed until the Sunday reset clears it.
      -- An early/transient read (e.g. quest log not yet populated) returns
      -- false for everything — don't let that wipe a stored completion.
      return any(DMFQuests, function(id)
        return IsQuestFlaggedCompleted(id)
      end) or current
    end,
    -- Capture turn-ins live: without this, a completion is only stored if a
    -- refresh runs before the faire ends and clears the quest flags.
    event = "QUEST_TURNED_IN",
    eventHandler = function(self, _, questId)
      if self.ids[questId] then self:set(true) end
    end,
  },
  preMidnight = {
    missing = false,
    ids = Set{87308,91795},
    resetOn = ns.RESET_WEEKLY,
    get = function(self, _, current)
      -- Sticky until the weekly reset: a transient/early read (quest log not yet
      -- populated) returns false for both — don't let it wipe a stored completion.
      local eight = IsQuestFlaggedCompleted(87308)
      local three = IsQuestFlaggedCompleted(91795)
      if current then
        eight = eight or current.eight
        three = three or current.three
      end
      return { eight = eight, three = three }
    end,
    reset = function() return { three = false, eight = false } end,
    event = "QUEST_TURNED_IN",
    eventHandler = function(self, _, questId)
      if self.ids[questId] then self:set(self:get())
      end
    end,
  },
  ---@class WeeklyBroker
  ---@field delversBounty boolean  the weekly Delver's Bounty treasure (quest 86371) claimed this week
  delversBounty = {
    missing = false,
    ids = Set{86371},
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function(_, _, current)
      -- Sticky until the weekly reset: a transient/early read (quest log not yet
      -- populated) returns false — don't let it wipe a stored completion.
      return IsQuestFlaggedCompleted(86371) or current
    end,
    reset = function() return false end,
    -- Capture the claim live; otherwise it's only stored if a refresh runs before
    -- the weekly reset clears the quest flag.
    event = "QUEST_TURNED_IN",
    eventHandler = function(self, _, questId)
      if self.ids[questId] then self:set(true) end
    end,
  },
  ---@class WeeklyBroker
  ---@field caches integer
  caches = {
    missing = false,
    ids = Set{
      93595, 93766, 93769, 88998, 89507, -- Midnight
      --84736, 84737, 84738, 84739, -- WWI cache 1-4 Season 1 & 2
      -- 91175, 91176, 91177, 91178, -- WWI cache 1-4 Season 3
      --82453, -- The Beginning of the End (From Dragon flight??)
      --82355, -- Special Assignment: Cinderbee Surge
      --82679, -- Archives: Seeking History
      --89294, -- Karesh special assignment Aligned Views
      --89293, -- Karesh special assignment
      --85460, -- Ecological Succession Cache 1st completion?
      --87419, -- World Soul Weekly (Delves)
      --91855, -- World Soul Weekly (Karesh World Quests)  looks like these all get flagged completed when one is done.
    },
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function(self)
      local n = 0
      for id,_ in pairs(self.ids) do
        n = n + (IsQuestFlaggedCompleted(id) and 1 or 0)
      end
      return n
    end,
    reset = function() return 0 end,
    event = "QUEST_TURNED_IN",
    eventHandler = function(self, _, questId)
      -- Recompute the count from the live quest flags (as get does) rather than
      -- blindly incrementing: a re-fired QUEST_TURNED_IN would otherwise over-count.
      if self.ids[questId] then self:set(self:get()) end
    end,
  },
  ---@class WeeklyBroker
  ---@field vault VaultRewards
  vault = {
    missing = false,
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function(_, _, current)
      local rewards = Player:GetRewardOptions()
      -- A transient/early API return can report best == 0; don't wipe
      -- previously-stored vault data — keep the existing value instead.
      if rewards.best > 0 then return rewards end
      return current
    end,
    event = "WEEKLY_REWARDS_UPDATE", -- WEEKLY_REWARDS_ITEM_CHANGED
    eventDelay = 1000,
  },
  ---@class WeeklyBroker
  ---@field vaultSlots VaultTracks  per-track (Raid/Dungeons/World) three-slot detail with reward ilvls
  vaultSlots = {
    missing = false,
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    -- Per-slot Great Vault detail for the vault view's pips + tooltip: three slots per track, each
    -- carrying its own reward item level. The aggregate `vault` field (via Player:GetRewardOptions)
    -- is left as-is for the summary column; this walks the same C_WeeklyRewards activities so each
    -- slot keeps the ilvl the aggregate collapses away. ilvl is resolved only for unlocked slots.
    get = function(_, _, current)
      local acts = GetActivities()
      -- transient/early API return — keep existing data rather than wiping
      if not acts or #acts == 0 then return current end
      local raw = {}
      for _, a in ipairs(acts) do
        local ilvl
        if a.progress >= a.threshold then
          local link = C_WeeklyRewards.GetExampleRewardItemHyperlinks(a.id)
          if link then ilvl = C_Item.GetDetailedItemLevelInfo(link) end
        end
        raw[#raw + 1] = { type = a.type, threshold = a.threshold, progress = a.progress, ilvl = ilvl }
      end
      return ns.SummarizeVaultSlots(raw)
    end,
    event = "WEEKLY_REWARDS_UPDATE",
    eventDelay = 1000,
  },
  ---@class WeeklyBroker
  ---@field hasUnclaimedVault boolean
  hasUnclaimedVault = {
    missing = false,
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function() return C_WeeklyRewards.HasAvailableRewards() end,
    -- depends on vault being reset first; safe because "hasUnclaimedVault" < "vault" in fieldOrder
    reset = function(_, toon) return toon.weeklies and toon.weeklies.vault and toon.weeklies.vault.best > 0 end,
    event = "WEEKLY_REWARDS_UPDATE",
    eventDelay = 1000,
  },
  ---@class WeeklyBroker
  ---@field keystone integer? current keystone level, nil if none
  keystone = {
    missing = false,
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function()
      return GetOwnedKeystoneLevel()  -- MayReturnNothing: nil when no keystone
    end,
    event = "CHALLENGE_MODE_COMPLETED",
  },
  ---@class WeeklyBroker
  ---@field dungeons {done: integer, max: integer}? M+ runs done and vault max threshold
  dungeons = {
    missing = false,
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function(_, _, current)
      local activities = GetActivities()
      -- transient/early API return — keep existing data rather than wiping
      if not activities then return current end
      local done, maxThreshold = 0, 0
      for _, a in ipairs(activities) do
        if a.type == 1 then  -- Enum.WeeklyRewardChestThresholdType.Activities (M+ dungeons)
          done = a.progress
          if a.threshold > maxThreshold then maxThreshold = a.threshold end
        end
      end
      return done > 0 and { done = done, max = maxThreshold } or nil
    end,
    event = "CHALLENGE_MODE_COMPLETED",
    eventDelay = 2000,
  },
}

ns:registerDump("m+", "Keystone", "dump keystone data", function(self, out)
  local ks = self.currentData.weeklies.keystone
  local dg = self.currentData.weeklies.dungeons
  out:line("Keystone: " .. (ks and ("+"..ks) or "none"))
  if dg then
    out:line("Dungeons: " .. dg.done .. "/" .. dg.max)
  else
    out:line("Dungeons: 0")
  end
end)

ns:registerDump("vault", "Vault Rewards", "dump vault data", function(self, out)
  ---@type VaultRewards
  local vault = self.currentData.weeklies.vault
  if not vault or vault.best <= 0 then
    out:line("No current vault data.")
    return
  end

  out:line("Vault Rewards: " .. vault.best)
  for ilvl,count in pairs(vault.counts) do
    out:line(ilvl .. " x " .. count)
  end

  for k,v in pairs(vault.progress) do
    out:line(k, ": " .. v.progress .. "/" .. v.max)
  end
end)
