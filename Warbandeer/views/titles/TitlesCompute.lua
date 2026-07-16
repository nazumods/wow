---@type Warbandeer
local ns = select(2, ...)
local sort, insert = table.sort, table.insert

-- Pure title categorisation: the warband's earned / unearned / earnable split. Given the live
-- title universe (all valid player titles), each tracked character's earned id list, and
-- (optionally) the Epithet catalog keyed by titleID, produce one enriched, name-sorted list plus
-- the per-status counts the Titles view pages by. Keeping this WoW/Epithet-free is what makes it
-- busted-testable (see Warbandeer/spec/titles_spec.lua) — the live client + Epithet reads are the
-- impure shell in views/titles/TitlesData.lua.

---@class TitleEntry
---@field id integer         titleMaskID (joins GetTitleName/IsTitleKnown + Epithet titleID)
---@field name string        trimmed display name
---@field earned boolean     at least one warband character has earned it
---@field owners string[]    names of characters that have earned it (empty when unearned)
---@field earnable boolean   unearned AND Epithet reports it obtainable == "yes"
---@field epithet table?     the matched Epithet catalog entry (nil without Epithet)

---@class TitlesCounts
---@field total integer
---@field earned integer
---@field unearned integer
---@field earnable integer

---@class TitlesResult
---@field list TitleEntry[]
---@field counts TitlesCounts

---@class Warbandeer
---@field ComputeTitles fun(universe: {id:integer,name:string}[], characters: {name:string,known:{id:integer}[]?}[], epithetById: table<integer,table>?): TitlesResult

-- Categorise the title universe against the warband's earned sets. `epithetById` nil ⇒ no
-- enrichment (no `epithet` field, nothing earnable), leaving earned/unearned fully intact.
function ns.ComputeTitles(universe, characters, epithetById)
  -- owners[id] = list of character names that have earned title id (sorted per entry below).
  local owners = {}
  for _, c in ipairs(characters or {}) do
    if c.known then
      for _, rec in ipairs(c.known) do
        local o = owners[rec.id]
        if not o then o = {}; owners[rec.id] = o end
        insert(o, c.name)
      end
    end
  end

  local list, earnedN, earnableN = {}, 0, 0
  for _, t in ipairs(universe or {}) do
    local o = owners[t.id]
    local earned = o ~= nil
    local ep = epithetById and epithetById[t.id]
    local earnable = (not earned) and ep ~= nil and ep.obtainable == "yes"
    if earned then
      earnedN = earnedN + 1
      sort(o, function(a, b) return a < b end)
    end
    if earnable then earnableN = earnableN + 1 end
    insert(list, {
      id = t.id, name = t.name, earned = earned,
      owners = o or {}, earnable = earnable, epithet = ep or nil,
    })
  end

  sort(list, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
  end)

  local total = #list
  return {
    list = list,
    counts = { total = total, earned = earnedN, unearned = total - earnedN, earnable = earnableN },
  }
end
