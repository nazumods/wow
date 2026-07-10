---@type Warbandeer_Characters
local ns = select(2, ...)
local GetBuildInfo = GetBuildInfo

local patch = false

-- True when the stored profession detail shows the character has trained the
-- current expansion's skill line.  Only then is recipe capture expected, so only
-- then does a nil recipes table mean "missing data" rather than "not trained yet".
local function hasCurrentExpSkill(detail)
  if not detail or not detail.expansions then return false end
  for _, exp in ipairs(detail.expansions) do
    if exp.name == ns.CURRENT_RECIPE_EXP and (exp.maxSkillLevel or 0) > 0 then
      return true
    end
  end
  return false
end

-- Warbandeer_Bars is optional, so its API is reached via the global. A profile
-- captured since the layout-snapshot upgrade always has bindingSet (1 or 2), so
-- a nil there means the character hasn't been re-snapshotted (logged in) since.
-- Returns the missing-report entry, or nil when the bars data is complete
-- (or Warbandeer_Bars isn't loaded).
local function missingBars(name)
  local api = WarbandeerBarsApi
  if not (api and name) then return end
  local profiles = api:GetProfiles(name)
  if not profiles or not next(profiles) then return "bars profile" end
  local stale
  for _, profile in pairs(profiles) do
    if profile.bindingSet == nil then
      stale = stale or {}
      table.insert(stale, profile.spec or "Unknown")
    end
  end
  if not stale then return end
  table.sort(stale)
  return "bars snapshot (" .. table.concat(stale, ", ") .. ")"
end

function ns.getMissingFields(toon)
  if not patch then patch = select(1, GetBuildInfo()) end
  local missing = {}

  -- gold/total are recorded numbers; 0 is valid data (a broke or freshly-tracked
  -- character), so only a nil means the value was never captured.
  if not toon.currency or toon.currency.gold == nil then
    table.insert(missing, "gold")
  end

  if not toon.playtime or toon.playtime.total == nil then
    table.insert(missing, "playtime")
  elseif not toon.playtime.byPatch or toon.playtime.byPatch[patch] == nil then
    table.insert(missing, "playtime (this patch)")
  end

  if not toon.lastRefresh then table.insert(missing, "lastRefresh") end

  -- guid is stamped every login (added in DB v30); a nil means the character hasn't
  -- logged in since, so external tools keying off it (e.g. a character-list sorter)
  -- can't yet identify it from character-list-order.txt's raw GUID fragments.
  if not toon.guid then table.insert(missing, "guid") end

  local bars = missingBars(toon.name)
  if bars then table.insert(missing, bars) end

  -- Bank profession gear is captured only when the character opens their bank.
  -- The store stamps scannedAt even when the bank holds no profession gear, so a
  -- missing entry (not an empty gear list) is what flags "never scanned".
  local banks = ns.db.bank and ns.db.bank.characters
  if not (banks and banks[toon.name]) then
    table.insert(missing, "bank contents")
  end

  -- Bag item counts (the warband-stock tooltip's per-character totals) are captured
  -- by the `inventory` broker, which only runs while the character is logged in. The
  -- broker always returns a table, so a nil counts means the character hasn't been
  -- seen since the index was added (its stock won't show in the tooltip until it logs in).
  if not toon.inventory or toon.inventory.counts == nil then
    table.insert(missing, "bag contents")
  end

  -- Mail contents are captured only while the character has a mailbox open. The scan
  -- stamps a count even for an empty inbox, so a missing count means "never visited a
  -- mailbox" — its expiries can't warn and its attachments are absent from the stock
  -- tooltip. (A record may exist with only the new-mail flag set, from UPDATE_PENDING_MAIL.)
  if not toon.mail or toon.mail.count == nil then
    table.insert(missing, "mail")
  end

  -- Reputations are captured each login (and on change), so a nil means the character
  -- hasn't been seen since the cache was added — its standings won't appear in
  -- ShadowsOfUI-Reputations' cross-alt block.
  if not toon.reputations then
    table.insert(missing, "reputations")
  end

  -- Quest log (active + completed history) is captured each login; a nil means the
  -- character hasn't been seen since the cache was added, so it won't appear in
  -- ShadowsOfUI-Quests' "also on / completed by" block.
  if not toon.questlog then
    table.insert(missing, "quest history")
  end

  -- LumberAxe is a recorded boolean (has / doesn't have the Find Lumber tracking
  -- spell), so only a nil means the data was never captured. false is real data.
  if not toon.quests or toon.quests.LumberAxe == nil then
    table.insert(missing, "lumber axe")
  end

  if toon.basic and toon.basic.level == ns.wow.maxLevel then
    if toon.equipment and toon.equipment.slots and not toon.equipment.trackScanned then
      table.insert(missing, "upgrade track data")
    end
    -- Alts last scanned before the GetItemGemID empty-socket fix carry stale socket
    -- counts (the old GetItemStats parse over-counted gemmed items under the Midnight
    -- Gem Manager); flag until they re-log and rescan with the corrected logic.
    if toon.equipment and toon.equipment.slots and not toon.equipment.socketScanned then
      table.insert(missing, "gem socket data")
    end
    if not toon.currency or toon.currency.HeroDawncrest == nil then
      table.insert(missing, "hero dawncrest")
    end
    if not toon.currency or toon.currency.MythDawncrest == nil then
      table.insert(missing, "myth dawncrest")
    end
    if not toon.currency or toon.currency.Catalyst == nil then
      table.insert(missing, "catalyst charges")
    end
    if not toon.currency or toon.currency.NebulousVoidcore == nil then
      table.insert(missing, "nebulous voidcores")
    end
    if not toon.currency or toon.currency.UntaintedManaCrystal == nil then
      table.insert(missing, "untainted mana-crystals")
    end
    if not toon.currency or toon.currency.ShardOfDundun == nil then
      table.insert(missing, "shard of dundun")
    end
    if not toon.currency or toon.currency.FieldAccolade == nil then
      table.insert(missing, "field accolade")
    end
    if not toon.currency or toon.currency.UnalloyedAbundance == nil then
      table.insert(missing, "unalloyed abundance")
    end
    if not toon.stats or toon.stats.secondary == nil then
      table.insert(missing, "secondary stats")
    end
  end

  if toon.basic and toon.basic.professions then
    local details = toon.professions and toon.professions.details
    local missingProfs, missingRecipes = {}, {}
    for _, prof in ipairs({ toon.basic.professions.primary, toon.basic.professions.secondary,
                              toon.basic.professions.fishing, toon.basic.professions.cooking }) do
      if prof and prof.name and prof.skillID then
        local detail = details and details[prof.skillID]
        if not detail or not (detail.expansions and #detail.expansions > 0) then
          -- No per-expansion skill captured: the detail entry is absent, or present
          -- but its expansions list never populated (a TRADE_SKILL_SHOW scan that
          -- fired before the child skill-lines loaded writes recipes/specPoints but
          -- no expansions, and that sticks). Both leave the Professions view all-"—".
          table.insert(missingProfs, prof.name)
        elseif not detail.recipes and hasCurrentExpSkill(detail) then
          -- Trained the current expansion but recipes weren't captured: detail
          -- predates recipe tracking, or the prof window hasn't been reopened since.
          -- (A character that simply hasn't trained the current-expansion skill is
          -- intentionally not reported here — that's expected, not missing data.)
          table.insert(missingRecipes, prof.name)
        end
      end
    end
    if #missingProfs > 0 then
      table.insert(missing, "professions (" .. table.concat(missingProfs, ", ") .. ")")
    end
    if #missingRecipes > 0 then
      table.insert(missing, "recipes (" .. table.concat(missingRecipes, ", ") .. ")")
    end
  end

  return missing
end
local getMissingFields = ns.getMissingFields

---@class Warbandeer_Characters
---@field getMissingReport fun(self): string[] Report of missing character data
function ns:getMissingReport()
  local current = self.currentPlayer
  local currentLine
  local missing = {}
  for name, toon in pairs(self.db.characters) do
    local issues = getMissingFields(toon)
    if #issues > 0 then
      local line = name .. " - missing " .. table.concat(issues, ", ")
      if name == current then
        currentLine = line
      else
        table.insert(missing, line)
      end
    end
  end
  table.sort(missing)
  -- The logged-in character, when it has missing data, is pinned to the very top
  -- ahead of the alphabetically-sorted rest.
  if currentLine then
    table.insert(missing, 1, currentLine)
  end
  return missing
end

ns:registerCommand("missing", "", function(self)
  local missing = self:getMissingReport()

  if #missing == 0 then
    ns.Print("All characters have complete data.")
    return
  end

  ns.Print(#missing .. " characters missing data:")
  for _, line in ipairs(missing) do
    print(line)
  end
end, "List characters missing data")

ns:registerCommand("missing", "me", function(self)
  local toon = self.currentData
  local missing = getMissingFields(toon)

  if #missing > 0 then
    ns.Print("Missing: " .. table.concat(missing, ", "))
  else
    ns.Print("No missing data.")
  end
end, "List the current character's missing data")
