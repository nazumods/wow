---@type Warbandeer
local ns = select(2, ...)
local GetNumTitles = GetNumTitles
local GetTitleName = GetTitleName
local IsTitleKnown = IsTitleKnown
local strtrim = strtrim
local insert = table.insert
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS

-- Layout constants + the impure "shell" for the Titles view: the live client title scan, the
-- per-character earned-list gather, and the optional Epithet catalog read. Kept apart from the
-- pure categoriser (views/titles/TitlesCompute.lua, ns.ComputeTitles) so the WoW/Epithet reads
-- stay out of the busted-tested core. Exposed on `ns.titles` (loaded before TitlesView.lua).

local ROW_H, CONTENT_W, SCROLLBAR_W = 24, 360, 20
local ICON, MARK_W = 16, 80
local MAX_H = 18 * ROW_H -- viewport cap; longer lists scroll

-- Every valid player title as { id = titleMaskID, name = <trimmed display name> }. Mirrors the
-- Warbandeer_Characters titles broker's scan but WITHOUT the IsTitleKnown gate, so it yields the
-- full universe (earned + unearned). GetTitleName's 2nd return (playerTitle) filters the mask ids
-- that aren't displayable titles; strtrim drops a prefix/suffix title's edge spacing.
local function scanUniverse()
  local list = {}
  for i = 1, GetNumTitles() do
    local name, playerTitle = GetTitleName(i)
    if name and playerTitle then
      local clean = strtrim(name)
      -- `current` = the logged-in character knows this title. Account-wide titles propagate to
      -- every character, so the live current-character IsTitleKnown is the account-wide oracle:
      -- true ⇒ the title is warband-wide; false while an alt owns it ⇒ character-specific.
      if clean ~= "" then insert(list, { id = i, name = clean, current = IsTitleKnown(i) }) end
    end
  end
  return list
end

-- Each tracked character as { name, classKey, known } for ns.ComputeTitles — `known` is the titles
-- broker's earned list ({id,name}[]), read straight off the character (last-seen; logged-in char
-- only). classKey rides along so the view can class-colour a title's owners in the tooltip.
local function gatherCharacters()
  local chars = {}
  for _, c in ipairs(ns.api.GetAllCharacters()) do
    insert(chars, { name = c.name, classKey = c.classKey, known = c.titles and c.titles.known })
  end
  return chars
end

-- Rarity colour markup for an Epithet entry's quality (`q`, 1-5), or nil when there's no Epithet
-- entry / quality (caller then falls back to its earned/unearned colour). `ITEM_QUALITY_COLORS[q]
-- .hex` is `GenerateHexColorMarkup()` output — already the full `|cffRRGGBB` escape, so it's
-- returned as-is (prepending another `|c` double-prefixes it and leaks a literal `|c`).
local function rarityCode(ep)
  local q = ep and ep.q
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  return c and c.hex or nil
end

-- The installed Epithet addon's catalog re-keyed by titleID for a direct join to the client's
-- title mask ids. Epithet stores it as the plain SavedVariable _G.EpithetData.titles, keyed by
-- lowercased title text; each entry carries a titleID. Returns nil when Epithet isn't loaded (or
-- exposes no usable titles), so the view degrades to earned/unearned only. Read live every refresh
-- — Epithet is a raw SavedVar with no change callback to hook.
local function epithetById()
  local data = _G.EpithetData
  local titles = data and data.titles
  if type(titles) ~= "table" then return nil end
  local byId, any = {}, false
  for _, entry in pairs(titles) do
    local id = type(entry) == "table" and entry.titleID
    if id then byId[id] = entry; any = true end
  end
  return any and byId or nil
end

---@class Warbandeer
---@field titles table  layout constants + impure client/Epithet readers for the Titles view
ns.titles = {
  ROW_H = ROW_H, CONTENT_W = CONTENT_W, SCROLLBAR_W = SCROLLBAR_W,
  ICON = ICON, MARK_W = MARK_W, MAX_H = MAX_H,
  scanUniverse = scanUniverse,
  gatherCharacters = gatherCharacters,
  epithetById = epithetById,
  rarityCode = rarityCode,
}
