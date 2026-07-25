---@type Warbandeer_Characters
local ns = select(2, ...)
local GetNumTitles = GetNumTitles
local GetTitleName = GetTitleName
local IsTitleKnown = IsTitleKnown
local GetBuildInfo = GetBuildInfo
local GetLocale = GetLocale
local GetServerTime = GetServerTime
local strtrim = strtrim
local ipairs = ipairs

-- The account-wide **title catalog**: the whole player-title universe (earned AND unearned) as
-- id -> display name, plus the account-wide classification. Per-character `titles.known`
-- (data/titles.lua) already persists the names of titles a character has EARNED, so the two gaps
-- an offline reader can't close from it are exactly what lives here: names for titles nobody has
-- earned, and the account-wide flag.
--
-- Account-wide, not per character — the universe is identical for every character, so it lives
-- once at `db.titleCatalog` (the data/travelerslog.lua pattern) rather than duplicated per toon.
--
-- `accountWide` is the logged-in character's `IsTitleKnown`, the same oracle Warbandeer's Titles
-- view uses live (views/titles/TitlesData.lua): account-wide titles propagate to every character,
-- so a title the scanning character knows reads as warband-wide. That makes it an observation by
-- ONE character, not a proven property — hence `scannedBy`, so a consumer can cross-reference the
-- other characters' stored `titles.known` sets and tighten the inference itself.
--
-- Names follow the CLIENT LOCALE (unlike a wago `Name_lang` extract, which is enUS-only), so
-- `locale` is recorded beside them.

---@class TitleCatalog
---@field build string  client build number the scan came from (GetBuildInfo's 2nd return)
---@field locale string  client locale the names are in (e.g. "enUS")
---@field scannedAt integer  server time of the scan
---@field scannedBy string  name of the character that scanned — whose view `accountWide` is
---@field names table<integer, string>  titleMaskID -> trimmed display name (earned + unearned)
---@field accountWide table<integer, true>  titleMaskIDs the scanning character knows
---@field count integer  titles in `names`
---@field accountWideCount integer  entries in `accountWide`

---@class WarbandeerCharactersDB
---@field titleCatalog TitleCatalog?  account-wide title universe; nil until first login after this shipped

-- Pure shaper (WoW-API-free, unit-tested): scan rows -> the stored catalog. Rows are
-- `{ id, name, known }`; an unnamed row is dropped, a repeated id keeps its first name. The
-- returned tables are fresh every call, so a title the client no longer reports simply vanishes
-- on the next scan — there are no stale keys to clean up.
---@param rows { id: integer, name: string, known: boolean? }[]
---@param meta { build: string?, locale: string?, scannedAt: integer?, scannedBy: string? }?
---@return TitleCatalog
function ns.ShapeTitleCatalog(rows, meta)
  local names, accountWide, count, known = {}, {}, 0, 0
  for _, r in ipairs(rows or {}) do
    if r.id and r.name and r.name ~= "" and names[r.id] == nil then
      names[r.id] = r.name
      count = count + 1
      if r.known then
        accountWide[r.id] = true
        known = known + 1
      end
    end
  end
  meta = meta or {}
  return {
    build = meta.build, locale = meta.locale,
    scannedAt = meta.scannedAt, scannedBy = meta.scannedBy,
    names = names, accountWide = accountWide,
    count = count, accountWideCount = known,
  }
end

-- The live client scan: every valid player title as `{ id, name, known }`. Mirrors the earned-list
-- scan in data/titles.lua but WITHOUT the IsTitleKnown gate, so it yields the full universe.
-- GetTitleName's 2nd return (playerTitle) filters mask ids that aren't displayable titles; strtrim
-- drops a prefix/suffix title's edge spacing.
local function scanRows()
  local rows = {}
  for i = 1, GetNumTitles() do
    local name, playerTitle = GetTitleName(i)
    if name and playerTitle then
      local clean = strtrim(name)
      if clean ~= "" then rows[#rows + 1] = { id = i, name = clean, known = IsTitleKnown(i) } end
    end
  end
  return rows
end

-- Re-scan and replace the stored catalog. Bails keeping the last catalog when the client reports
-- no titles at all (pre-data login), so a cold read never blanks a good snapshot.
local function refresh()
  local rows = scanRows()
  if #rows == 0 then return end
  local _, build = GetBuildInfo()
  ns.db.titleCatalog = ns.ShapeTitleCatalog(rows, {
    build = build,
    locale = GetLocale(),
    scannedAt = GetServerTime(),
    scannedBy = ns.currentPlayer,
  })
end

---Login-time setup: take a fresh scan and re-scan whenever the earned set changes.
---KNOWN_TITLES_UPDATE arrives in bursts, so it's debounced onto one trailing scan (1s, matching
---the `titles` broker's own eventDelay).
---@class Warbandeer_Characters
---@field InitTitleCatalog fun()
function ns:InitTitleCatalog()
  refresh()
  ns:registerEvent("KNOWN_TITLES_UPDATE", function()
    ns:debounce("titleCatalog", 1000, refresh)
  end)
end
