---@type Warbandeer_Characters
local ns = select(2, ...)

-- Per-character WEEKLY profession knowledge tracking. Every weekly knowledge source Blizzard
-- offers is gated behind a hidden quest that flags complete when the knowledge is earned and
-- clears at the weekly reset, so `C_QuestLog.IsQuestFlaggedCompleted` against a static per-
-- profession quest table is the whole mechanism — no crafting window, no live scan of alts.
-- The `professionKnowledge` broker caches each character's per-profession completion on login
-- and on QUEST_TURNED_IN, and self-clears weekly via `resetOn`; the summary is read cross-alt by
-- Warbandeer's Midnight professions view (WarbandeerApi:GetProfessionKnowledge). This replaces
-- the standalone WeeklyKnowledge addon.
--
-- The four weekly-renewable sources (one-time First Craft / Unique knowledge is out of scope):
--   treatise    – the weekly profession treatise (Inscription-crafted / crafting-order), 1 quest.
--   weeklyQuest – the profession trainer OR Artisan's Consortium weekly (any-of, counts once).
--   treasure    – knowledge randomly looted from world treasures (crafting professions), one
--                 independent quest per treasure item.
--   gathering   – knowledge randomly looted from gathering nodes (herb/mine/skin) or disenchanting
--                 (Enchanting); a tiered set of quests plus a bonus.
--
-- PROVENANCE / VERIFICATION: Midnight (12.0) hidden quest IDs, keyed by PARENT skill line ID, from
-- datamining cross-checked against the community WeeklyKnowledge / Myu's Knowledge Points Tracker
-- addons, and confirmable in-game with `/wbc dump knowledge` (a wrong id simply reads "not done"
-- until corrected — never a false complete). Quest IDs are patch-specific: update this whole table
-- each expansion (a Midnight-only tracker keys by base skill line; multi-expansion would need to
-- key by skillLineVariant, e.g. via data/professioninfo.lua's midVariantID).
---@type table<integer, table<string, integer[]>>
local KNOWLEDGE = {
  [171] = { treatise = {95127}, weeklyQuest = {93690}, treasure = {93528, 93529} },                                                             -- Alchemy
  [164] = { treatise = {95128}, weeklyQuest = {93691}, treasure = {93530, 93531} },                                                             -- Blacksmithing
  [333] = { treatise = {95129}, weeklyQuest = {93697, 93698, 93699}, treasure = {93532, 93533}, gathering = {95048, 95049, 95050, 95051, 95052, 95053} }, -- Enchanting
  [202] = { treatise = {95138}, weeklyQuest = {93692}, treasure = {93534, 93535} },                                                             -- Engineering
  [182] = { treatise = {95130}, weeklyQuest = {93700, 93702, 93703, 93704}, gathering = {81425, 81426, 81427, 81428, 81429, 81430} },           -- Herbalism
  [773] = { treatise = {95131}, weeklyQuest = {93693}, treasure = {93536, 93537} },                                                             -- Inscription
  [755] = { treatise = {95133}, weeklyQuest = {93694}, treasure = {93538, 93539} },                                                             -- Jewelcrafting
  [165] = { treatise = {95134}, weeklyQuest = {93695}, treasure = {93540, 93541} },                                                             -- Leatherworking
  [186] = { treatise = {95135}, weeklyQuest = {93705, 93706, 93707, 93708, 93709}, gathering = {88673, 88674, 88675, 88676, 88677, 88678} },     -- Mining
  [393] = { treatise = {95136}, weeklyQuest = {93710, 93711, 93712, 93713, 93714}, gathering = {88534, 88549, 88537, 88536, 88530, 88529} },     -- Skinning
  [197] = { treatise = {95137}, weeklyQuest = {93696}, treasure = {93542, 93543} },                                                             -- Tailoring
}
ns.ProfessionKnowledge = KNOWLEDGE

-- Display / iteration order of the sources. `treatise`/`weeklyQuest` are single weekly checkboxes
-- (one treatise item; the weekly quest counts once however many of its any-of options exist), so
-- they contribute 0/1. `treasure`/`gathering` award knowledge per distinct pickup, so they count.
local SOURCE_ORDER = { "treatise", "weeklyQuest", "treasure", "gathering" }
local BOOLEAN_SOURCE = { treatise = true, weeklyQuest = true }
ns.ProfessionKnowledgeSources = SOURCE_ORDER

-- Summarise one profession's weekly knowledge from an injected quest-completion checker. Boolean
-- sources contribute 0/1 (done when ANY of their quests is flagged); count sources contribute
-- #completed / #quests. Returns a per-source `{done,total}` plus the aggregate `done`/`total`.
-- Pure — no WoW API — so it's unit-tested (spec/professionknowledge_spec.lua).
---@param entry table<string, integer[]>            the KNOWLEDGE row for a profession
---@param isCompleted fun(questID: integer): boolean
---@return { done: integer, total: integer, [string]: { done: integer, total: integer } }
function ns.SummarizeProfessionKnowledge(entry, isCompleted)
  local summary = { done = 0, total = 0 }
  for _, src in ipairs(SOURCE_ORDER) do
    local quests = entry[src]
    if quests then
      local done = 0
      if BOOLEAN_SOURCE[src] then
        for _, q in ipairs(quests) do
          if isCompleted(q) then done = 1; break end
        end
        summary[src] = { done = done, total = 1 }
      else
        for _, q in ipairs(quests) do
          if isCompleted(q) then done = done + 1 end
        end
        summary[src] = { done = done, total = #quests }
      end
      summary.done = summary.done + summary[src].done
      summary.total = summary.total + summary[src].total
    end
  end
  return summary
end

-- Merge a fresh summary over the stored one, keeping the higher per-source `done`. A transient
-- early read at login (quest log not yet populated → every flag reads false) would otherwise wipe
-- stored progress; weekly completion only rises within a reset window, so max is safe (and the
-- weekly `resetOn` clears the stored value at the boundary, so this never carries across weeks).
-- Pure — unit-tested alongside the summariser.
---@param fresh { done: integer, total: integer, [string]: { done: integer, total: integer } }
---@param current { done: integer, total: integer, [string]: { done: integer, total: integer } }?
---@return { done: integer, total: integer, [string]: { done: integer, total: integer } }
function ns.MergeProfessionKnowledge(fresh, current)
  if not current then return fresh end
  fresh.done, fresh.total = 0, 0
  for _, src in ipairs(SOURCE_ORDER) do
    local f = fresh[src]
    if f then
      local c = current[src]
      if c and c.done > f.done then f.done = c.done end
      fresh.done = fresh.done + f.done
      fresh.total = fresh.total + f.total
    end
  end
  return fresh
end

---@class ProfessionKnowledgeSource
---@field done integer
---@field total integer

---@class ProfessionKnowledgeEntry
---@field treatise ProfessionKnowledgeSource?
---@field weeklyQuest ProfessionKnowledgeSource?
---@field treasure ProfessionKnowledgeSource?
---@field gathering ProfessionKnowledgeSource?
---@field done integer  weekly knowledge points collected this reset
---@field total integer weekly knowledge points available this reset

---@class Character
---@field professionKnowledge ProfessionKnowledgeBroker?

---@class ProfessionKnowledgeBroker: Broker
---@field data table<integer, ProfessionKnowledgeEntry>?  keyed by PARENT skill line ID

local ProfKnowledge = ns:RegisterBroker("professionKnowledge")
ProfKnowledge.fields = {
  data = {
    missing = false,
    resetOn = ns.RESET_WEEKLY,
    -- Called at login and on QUEST_TURNED_IN; only reads hidden quest flags, so no crafting window
    -- is needed. Broker:Reset nils the field at the weekly boundary.
    get = function(_, toon, current)
      local isCompleted = C_QuestLog.IsQuestFlaggedCompleted
      local profs = toon.basic and toon.basic.professions
      -- basic not captured yet (very first login) — keep any stored value rather than wipe it.
      if not profs then return current end
      local result = {}
      for _, slot in ipairs({ "primary", "secondary" }) do
        local p = profs[slot]
        local entry = p and p.skillID and KNOWLEDGE[p.skillID]
        if entry then
          local summary = ns.SummarizeProfessionKnowledge(entry, isCompleted)
          result[p.skillID] = ns.MergeProfessionKnowledge(summary, current and current[p.skillID])
        end
      end
      return result
    end,
    -- QUEST_TURNED_IN fires on every turn-in; debounce a burst into one profession re-scan.
    event = "QUEST_TURNED_IN",
    eventDelay = 1000,
  },
}

ns:registerDump("knowledge", "Weekly Prof Knowledge", "dump weekly profession knowledge", function(self, out)
  local data = self.currentData.professionKnowledge and self.currentData.professionKnowledge.data
  if not data or not next(data) then
    out:line("No weekly profession knowledge tracked for this character.")
    return
  end
  local profInfo = self.api and self.api.professionInfo
  for skillID, entry in pairs(data) do
    local info = profInfo and profInfo["sl" .. skillID]
    out:line((info and info.name or ("Skill " .. skillID)) .. ": " .. entry.done .. "/" .. entry.total)
    for _, src in ipairs(SOURCE_ORDER) do
      local s = entry[src]
      if s then out:line("  " .. src .. ": " .. s.done .. "/" .. s.total) end
    end
  end
end)
