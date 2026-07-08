---@type Warbandeer_Characters
local ns = select(2, ...)
local C_Reputation = C_Reputation
local GetTime = GetTime
local IsMajorFaction, IsFactionParagon = C_Reputation.IsMajorFaction, C_Reputation.IsFactionParagon
local GetMajorFactionData, HasMaximumRenown = C_MajorFactions.GetMajorFactionData, C_MajorFactions.HasMaximumRenown
local GetFriendshipReputation, GetFriendshipReputationRanks = C_GossipInfo.GetFriendshipReputation, C_GossipInfo.GetFriendshipReputationRanks

---@class FactionStanding
---@field name string faction name
---@field label string display standing ("Exalted" / "Renown 12" / "Best Friend")
---@field rank integer normalized standing for sorting (reaction 1-8 / renown level / friendship level)
---@field done boolean at the cap (Exalted / max renown / max friendship)
---@field paragon boolean? earning paragon rewards past the cap
---@field accountWide boolean? the standing is shared across the whole warband (show once, not per character)
---@field categoryId integer? the top-level expansion header's factionID (0 = uncategorized/Other); locale-proof grouping key for Warbandeer's Reputations view

---@class ReputationsBroker
---@field factions table<integer, FactionStanding>  per-faction standing, keyed by factionID

---@class Character
---@field reputations ReputationsBroker?

-- Resolve one faction's standing from its live FactionData, picking the right model:
-- major (renown), friendship, or standard reaction. Run on the owning character (data
-- warm + same locale), so the label is captured ready to display warband-wide.
local function resolve(data)
  local fid = data.factionID
  local e = { name = data.name }
  if IsMajorFaction(fid) then
    local mf = GetMajorFactionData(fid)
    local level = (mf and mf.renownLevel) or 0
    -- RENOWN_LEVEL_LABEL is the format string "Renown %d", not a literal prefix —
    -- format it so the level lands in place (concatenation leaves "Renown %d12").
    local label = RENOWN_LEVEL_LABEL
    label = (label:find("%%d") and label:format(level)) or (label .. " " .. level)
    e.label, e.rank, e.done = label, level, HasMaximumRenown(fid) or false
  else
    local friend = GetFriendshipReputation(fid)
    if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0 then
      local ranks = GetFriendshipReputationRanks(fid)
      e.label = friend.reaction
      e.rank = (ranks and ranks.currentLevel) or 0
      e.done = (ranks and ranks.currentLevel >= ranks.maxLevel) or false
    else
      local reaction = data.reaction or 4
      e.label = _G["FACTION_STANDING_LABEL" .. reaction] or tostring(reaction)
      e.rank, e.done = reaction, reaction >= 8
    end
  end
  if IsFactionParagon(fid) then e.paragon = true end
  if data.isAccountWide then e.accountWide = true end
  return e
end

---@class ReputationsBroker: Broker
local Reputations = ns:RegisterBroker("reputations")

-- A full GetNumFactions walk (hundreds of factions, each resolved through several C_*
-- calls) is heavy, and UPDATE_FACTION fires in large bursts (any rep gain, opening the
-- panel), so the live handler below is carefully rate-limited — an unguarded re-scan per
-- event pegged the CPU in-game. Three guards (see eventHandler):
--   1. Self-trigger suppression. The scan's own ExpandAllFactionHeaders fires more
--      UPDATE_FACTION events, but ASYNC (after get returns), so a synchronous in-scan flag
--      can't catch them. Instead we stamp the scan-completion time and ignore any event
--      landing within SELF_WINDOW of it — the echo can never schedule a new scan.
--   2. Throttle: a scan never lands sooner than MIN_INTERVAL after the previous one, so a
--      sustained rep-gain stream can't fire a full walk more than once per window.
--   3. Debounce (LibNAddOn's ns:debounce, like worldquests): only the last event in a burst runs.
local SCAN_DEBOUNCE = 2 -- s: collapse a burst of UPDATE_FACTION into a single scan
local MIN_INTERVAL  = 6 -- s: throttle — at most one faction walk per this window
local SELF_WINDOW   = 1 -- s: ignore UPDATE_FACTION this soon after our own scan (its echo)

local lastScanAt  = 0   -- GetTime() of the last completed scan (0 = never)

-- All factions the character has a standing with, keyed by factionID. Headers must be
-- expanded for the index walk to reach collapsed children. Pure headers (no rep of their
-- own) are skipped. The walk is in panel (tree) order, so the last top-level header
-- (`isHeader and not isChild`) seen is each faction's expansion category — captured as
-- `categoryId` (locale-proof) for Warbandeer's Reputations view. Sub-headers (`isChild`,
-- e.g. Dragonscale Expedition under Dragonflight) don't reset it, so their children
-- inherit the right expansion.
Reputations.fields = {
  factions = {
    get = function()
      if C_Reputation.ExpandAllFactionHeaders then C_Reputation.ExpandAllFactionHeaders() end
      local reps = {}
      local categoryId = 0
      for i = 1, (C_Reputation.GetNumFactions() or 0) do
        local data = C_Reputation.GetFactionDataByIndex(i)
        if data and data.factionID then
          if data.isHeader and not data.isChild then
            categoryId = data.factionID
          end
          if data.factionID > 0 and (not data.isHeader or data.isHeaderWithRep) then
            local e = resolve(data)
            e.categoryId = categoryId
            reps[data.factionID] = e
          end
        end
      end
      return reps
    end,
    event = "UPDATE_FACTION",
    eventHandler = function(field)
      local toon = field._toon or ns.currentData
      if not toon then return end
      local now = GetTime()

      -- (1) Suppress the async echo of our own ExpandAllFactionHeaders.
      if now - lastScanAt < SELF_WINDOW then return end

      -- (2) Throttle: never schedule the scan to land before MIN_INTERVAL has elapsed
      -- since the last one.
      local wait = SCAN_DEBOUNCE
      local earliest = lastScanAt + MIN_INTERVAL
      if now + wait < earliest then wait = earliest - now end

      -- (3) Debounce (via ns:debounce): each event supersedes the pending scan.
      ns:debounce("reputations.factions", wait * 1000, function()
        toon.reputations.factions = field:get(toon, toon.reputations.factions)
        lastScanAt = GetTime() -- stamp AFTER get so the SELF_WINDOW covers the echo
      end)
    end,
  },
}
