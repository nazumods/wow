---@type Warbandeer_Characters
local ns = select(2, ...)
local C_Reputation = C_Reputation
local IsMajorFaction, IsFactionParagon = C_Reputation.IsMajorFaction, C_Reputation.IsFactionParagon
local GetMajorFactionData, HasMaximumRenown = C_MajorFactions.GetMajorFactionData, C_MajorFactions.HasMaximumRenown
local GetFriendshipReputation, GetFriendshipReputationRanks = C_GossipInfo.GetFriendshipReputation, C_GossipInfo.GetFriendshipReputationRanks

---@class FactionStanding
---@field name string faction name
---@field label string display standing ("Exalted" / "Renown 12" / "Best Friend")
---@field rank integer normalized standing for sorting (reaction 1-8 / renown level / friendship level)
---@field done boolean at the cap (Exalted / max renown / max friendship)
---@field paragon boolean? earning paragon rewards past the cap

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
    e.label, e.rank, e.done = RENOWN_LEVEL_LABEL .. level, level, HasMaximumRenown(fid) or false
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
  return e
end

---@class ReputationsBroker: Broker
local Reputations = ns:RegisterBroker("reputations")

-- All factions the character has a standing with, keyed by factionID. Headers must be
-- expanded for the index walk to reach collapsed children (idempotent — re-expanding an
-- already-open tree fires no event, so it can't loop the UPDATE_FACTION re-scan). Pure
-- headers (no rep of their own) are skipped.
Reputations.fields = {
  factions = {
    get = function()
      if C_Reputation.ExpandAllFactionHeaders then C_Reputation.ExpandAllFactionHeaders() end
      local reps = {}
      for i = 1, (C_Reputation.GetNumFactions() or 0) do
        local data = C_Reputation.GetFactionDataByIndex(i)
        if data and data.factionID and data.factionID > 0 and (not data.isHeader or data.isHeaderWithRep) then
          reps[data.factionID] = resolve(data)
        end
      end
      return reps
    end,
    event = "UPDATE_FACTION",
    eventDelay = 2000,
  },
}
