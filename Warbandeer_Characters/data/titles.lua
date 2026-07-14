---@type Warbandeer_Characters
local ns = select(2, ...)
local GetNumTitles = GetNumTitles
local IsTitleKnown = IsTitleKnown
local GetTitleName = GetTitleName
local GetCurrentTitle = GetCurrentTitle
local strtrim = strtrim
local sort = table.sort

-- The `titles` broker records the player titles the character has earned — the same set the
-- character's Titles pane (PaperDollFrame) lists. Only the logged-in character's titles are
-- readable, so `known` is a last-seen snapshot (like the glyphs broker). We walk every title
-- mask id (1..GetNumTitles) and keep the ones the character IsTitleKnown AND that GetTitleName
-- reports as a real player title (its second return) — mirroring Blizzard's own GetKnownTitles
-- guard, which skips mask ids that aren't displayable titles. `current` is the featured title's
-- mask id (the one shown after the character's name), or nil when no title is active.

-- Every earned player title as { id = titleMaskID, name = <trimmed display name> }, sorted by
-- name for a stable list. GetTitleName returns the raw fragment (leading/trailing spaces mark a
-- prefix/suffix title) plus a playerTitle flag; strtrim gives the clean display name.
local function scanKnown()
  local list = {}
  for i = 1, GetNumTitles() do
    if IsTitleKnown(i) then
      local name, playerTitle = GetTitleName(i)
      if name and playerTitle then
        list[#list + 1] = { id = i, name = strtrim(name) }
      end
    end
  end
  sort(list, function(a, b) return a.name < b.name end)
  return list
end

-- The featured title's mask id (shown after the character's name), validated against the live
-- title range + known state; nil when the character has no title active.
local function currentTitle()
  local id = GetCurrentTitle()
  if id and id > 0 and id <= GetNumTitles() and IsTitleKnown(id) then return id end
  return nil
end

-- The featured title's trimmed display name (nil when none), stored alongside the id so the
-- Summary column can render an alt's title without a live per-render lookup.
local function currentTitleName()
  local id = currentTitle()
  local name = id and GetTitleName(id)
  return name and strtrim(name) or nil
end

---@class TitleRecord
---@field id integer titleMaskID
---@field name string trimmed display name

---@class TitlesBroker: Broker
---@field known TitleRecord[]?  earned player titles (last-seen; logged-in character only)
---@field current integer?  featured/active titleMaskID (nil when no title is active)
---@field currentName string?  featured/active title display name (nil when none) — Summary column source

---@class Character
---@field titles TitlesBroker?

local Titles = ns:RegisterBroker("titles")

Titles.fields = {
  -- KNOWN_TITLES_UPDATE fires when the set of earned titles changes; debounce a burst into one
  -- scan. The login refresh() queues this field too, so an alt's list is captured the next time
  -- it plays even if no title event fires that session.
  known = {
    missing = false,
    get = function() return scanKnown() end,
    event = "KNOWN_TITLES_UPDATE",
    eventDelay = 1000,
  },
  -- The featured title changes on selection (UNIT_NAME_UPDATE for the player) and when a title is
  -- learned or lost (KNOWN_TITLES_UPDATE).
  current = {
    missing = false,
    get = function() return currentTitle() end,
    event = { "KNOWN_TITLES_UPDATE", "UNIT_NAME_UPDATE" },
    eventDelay = 1000,
  },
  -- The featured title's display name, captured beside `current` so the Summary column renders an
  -- alt's title straight from the cache (no live GetTitleName per row).
  currentName = {
    missing = false,
    get = function() return currentTitleName() end,
    event = { "KNOWN_TITLES_UPDATE", "UNIT_NAME_UPDATE" },
    eventDelay = 1000,
  },
}

-- `/wbc dump titles` (+ `wdump titles`): the in-game verification probe. Prints the live scan
-- count, the featured title, and every scanned title (marking the featured one), plus what's
-- stored for the current character so a stale/empty cache is distinguishable from an empty scan.
ns:registerDump("titles", "Player Titles",
  "Earned player titles + featured title for the current character",
  function(_, out)
    local toon = ns.currentData
    if not toon then out:line("No current character."); return end
    local known = scanKnown()
    local current = currentTitle()
    local currentName
    for _, e in ipairs(known) do if e.id == current then currentName = e.name end end
    out:line(("Live scan: %d title(s); featured %s"):format(#known,
      current and (currentName or "?") .. " (" .. current .. ")" or "none"))
    local stored = toon.titles and toon.titles.known
    local storedFeatured = toon.titles and toon.titles.current
    out:line(("Stored: %d title(s)%s"):format(stored and #stored or 0,
      storedFeatured and (", featured %s (%d)"):format(
        (toon.titles.currentName or "?"), storedFeatured) or ""))
    for _, e in ipairs(known) do
      out:line(("  [%d] %s%s"):format(e.id, e.name, e.id == current and "  <FEATURED>" or ""))
    end
  end)
