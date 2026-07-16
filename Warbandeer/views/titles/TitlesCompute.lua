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
---@field earned boolean     the warband has it (an alt owns it, or the current character knows it)
---@field accountWide boolean  the current (logged-in) character knows it ⇒ available warband-wide
---@field owners string[]    names of characters that have earned it (empty when unearned)
---@field earnable boolean   unearned AND Epithet reports it obtainable == "yes"
---@field unearnable boolean  unearned AND Epithet marks it not obtainable (obtainable == "no"/"feat")
---@field epithet table?     the matched Epithet catalog entry (nil without Epithet)

---@class TitlesCounts
---@field total integer
---@field earned integer
---@field unearned integer
---@field earnable integer
---@field unearnable integer  unearned and Epithet marks it not obtainable (no/feat)

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

  local list, earnedN, earnableN, unearnableN = {}, 0, 0, 0
  for _, t in ipairs(universe or {}) do
    local o = owners[t.id]
    -- `current` (the logged-in character knows it) is the account-wide oracle. A title counts as
    -- earned by the warband either because an alt owns it OR because the current character knows it
    -- (an account-wide title the alts' stored lists may not have caught up to yet).
    local accountWide = t.current == true
    local earned = o ~= nil or accountWide
    local ep = epithetById and epithetById[t.id]
    local obtainable = ep and ep.obtainable
    -- Earnable / unearnable partition the *unearned* titles by Epithet's obtainability. Both need an
    -- Epithet entry, so with Epithet absent nothing is either (the view keeps those as plain
    -- "Unearned"); an unearned title with an entry but no yes/no/feat verdict stays neither too.
    local earnable = (not earned) and obtainable == "yes"
    local unearnable = (not earned) and (obtainable == "no" or obtainable == "feat")
    if earned then earnedN = earnedN + 1 end
    if o then sort(o, function(a, b) return a < b end) end
    if earnable then earnableN = earnableN + 1 end
    if unearnable then unearnableN = unearnableN + 1 end
    insert(list, {
      id = t.id, name = t.name, earned = earned, accountWide = accountWide,
      owners = o or {}, earnable = earnable, unearnable = unearnable, epithet = ep or nil,
    })
  end

  sort(list, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
  end)

  local total = #list
  return {
    list = list,
    counts = {
      total = total, earned = earnedN, unearned = total - earnedN,
      earnable = earnableN, unearnable = unearnableN,
    },
  }
end
