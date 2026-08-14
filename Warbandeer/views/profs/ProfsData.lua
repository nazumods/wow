---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Texture = ui.Texture
local theme = ns.theme
local insert, sort = table.insert, table.sort

-- Shared data + cell/data helpers for the Professions view. Exposed on `ns.profs`
-- (loaded before ProfsView.lua) so the view shell and its char-list methods read the
-- same column factories, gradient cells, and per-expansion skill aggregation.

-- Ordered expansion columns (chronological). Abbreviations are kept short so the
-- column headers stay compact (WotLK -> WLK avoids one outlier-wide header).
local EXP_ORDER = { "Clsc", "TBC", "WLK", "Cata", "MoP", "WoD", "Leg", "BfA", "SL", "DF", "TWW", "Mid" }
local EXP_ABBR = {
  ["Classic"]      = "Clsc",
  ["Outland"]      = "TBC",
  ["Northrend"]    = "WLK",
  ["Cataclysm"]    = "Cata",
  ["Pandaria"]     = "MoP",
  ["Draenor"]      = "WoD",
  ["Legion"]       = "Leg",
  -- BfA is the only faction-split profession tier: Alliance trains "Kul Tiran <Prof>",
  -- Horde trains "Zandalari <Prof>". Both expansionNames map to the one BfA column (#910).
  ["Kul Tiran"]    = "BfA",
  ["Zandalari"]    = "BfA",
  ["Shadowlands"]  = "SL",
  ["Dragon Isles"] = "DF",
  ["Khaz Algar"]   = "TWW",
  ["Midnight"]     = "Mid",
}

-- Professions in display order (no Fishing — no expansion sub-skills).
local PROF_ORDER = {
  "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering", "Fishing",
  "Herbalism", "Inscription", "Jewelcrafting", "Leatherworking",
  "Mining", "Skinning", "Tailoring",
}

-- Column widths.  ICON + CHAR == PROF so expansion columns align between the two tables.
-- CHAR/EXP are sized to fit their header label plus the sortable-column sort arrow.
local PROF_COL_W    = 114   -- profession-name column in the summary grid (= ICON + CHAR)
local ICON_COL_W    = 20    -- faction icon in the character list
local CHAR_COL_W    = 94    -- character name; fits "CHARACTER" + sort arrow
local EXP_COL_W     = 48    -- expansion column; fits the widest label ("CATA") + sort arrow
local CHAR_LIST_H   = 180   -- height of the scrollable character-list area

local VIEW_WIDTH    = PROF_COL_W + #EXP_ORDER * EXP_COL_W  -- 638

-- Transparent rows/columns let the void window surface show
-- through; the selected grid row reads as a muted-gold wash, empty cells dim.
local TRANSPARENT = { color = { 0, 0, 0, 0 } }
local SELECTED    = theme.colors.selected
local DIM         = { 0.82, 0.776, 0.671, 0.35 } -- muted at low alpha (— cells)

-- ─── Column-info factories ────────────────────────────────────────────────────
-- Headers are uppercased (the muted color comes from the theme); columns stay
-- transparent so the void window surface shows through behind the rows.

local function makeGridColInfo()
  local cols = {
    -- cells inset via hPadL; the header label insets via the symmetric `padding`
    -- (left inset only matters under left-justification) so the two line up
    { name = "PROFESSION", width = PROF_COL_W, backdrop = TRANSPARENT,
      justifyH = ui.justify.Left, hPadL = 8, padding = 8 },
  }
  for _, abbr in ipairs(EXP_ORDER) do
    insert(cols, { name = abbr:upper(), width = EXP_COL_W, backdrop = TRANSPARENT,
      justifyH = ui.justify.Left })
  end
  return cols
end

local function makeCharColInfo()
  local cols = {
    { width = ICON_COL_W, backdrop = TRANSPARENT },   -- faction icon: not sortable
    -- Name sorts A→Z (ascending first); expansion columns sort by skill, biggest first.
    { name = "CHARACTER", width = CHAR_COL_W, backdrop = TRANSPARENT,
      justifyH = ui.justify.Left, sortable = true, sortKey = "name" },
  }
  for _, abbr in ipairs(EXP_ORDER) do
    insert(cols, { name = abbr:upper(), width = EXP_COL_W, backdrop = TRANSPARENT,
      justifyH = ui.justify.Left, sortable = true, sortKey = abbr, descFirst = true })
  end
  return cols
end

-- Returns the pre-built empty row used to clear stale cells in the char table.
local function makeEmptyRow(numCols)
  local r = {}
  for _ = 1, numCols do insert(r, "") end
  return r
end

-- Lazily attach a 1px top divider to a pooled table row (mirrors the other
-- restyled table views). Returns the texture so callers can show/hide it.
local function rowDivider(row)
  if not row._divider then
    row._divider = Texture:new{
      parent = row,
      layer = ui.layer.Overlay,
      position = {
        TopLeft = { row, ui.edge.TopLeft, 0, 0 },
        TopRight = { row, ui.edge.TopRight, 0, 0 },
        Height = 1,
      },
      color = theme.colors.divider,
    }
  end
  return row._divider
end

-- ─── Cell helpers ─────────────────────────────────────────────────────────────

local function skillCell(best, max, onClick)
  if not best or best == 0 then
    return { text = "—", color = DIM, onClick = onClick }
  end
  return {
    text    = tostring(best),
    color   = best >= max and theme.colors.green or theme.colors.text,
    onClick = onClick,
  }
end

-- ─── Data helpers ─────────────────────────────────────────────────────────────

-- For each profession, find the best skill per expansion across all characters.
-- Returns { [profName] -> { [expAbbr] -> { best, max } } }
local function buildBestSkills(toons)
  local result = {}
  for _, toon in ipairs(toons) do
    local profs = toon.basic.professions
    if profs then
      for _, slot in ipairs({ "primary", "secondary", "fishing", "cooking" }) do
        local prof = profs[slot]
        if prof and prof.name then
          if not result[prof.name] then result[prof.name] = {} end
          local pData  = result[prof.name]
          local detail = toon.professions
                      and toon.professions.details
                      and toon.professions.details[prof.skillID]
          if detail and detail.expansions then
            for _, exp in ipairs(detail.expansions) do
              local abbr = EXP_ABBR[exp.name]
              if abbr then
                if not pData[abbr] or exp.skillLevel > pData[abbr].best then
                  pData[abbr] = { best = exp.skillLevel, max = exp.maxSkillLevel }
                end
              end
            end
          end
        end
      end
    end
  end
  return result
end

-- Build a sorted character list for a given profession name.
-- Returns { { toon, prof, detail } ... } sorted by skill desc then name asc.
local function buildCharList(toons, profName)
  local list = {}
  for _, toon in ipairs(toons) do
    local profs = toon.basic.professions
    if profs then
      for _, slot in ipairs({ "primary", "secondary", "fishing", "cooking" }) do
        local prof = profs[slot]
        if prof and prof.name == profName then
          local detail = toon.professions
                      and toon.professions.details
                      and toon.professions.details[prof.skillID]
          insert(list, { toon = toon, prof = prof, detail = detail })
          break
        end
      end
    end
  end
  sort(list, function(a, b)
    if a.prof.skillLevel ~= b.prof.skillLevel then return a.prof.skillLevel > b.prof.skillLevel end
    return a.toon.name < b.toon.name
  end)
  return list
end

-- A character entry's skill level for one expansion column (abbr), or -inf when the
-- character never learned that tier — so "—" rows park at the worst end and flip
-- cleanly with the sort direction.
local function entrySkill(entry, abbr)
  local detail = entry.detail
  if detail and detail.expansions then
    for _, exp in ipairs(detail.expansions) do
      if EXP_ABBR[exp.name] == abbr then return exp.skillLevel end
    end
  end
  return -math.huge
end

-- Sort a char-list `entries` array in place for a TableFrame column sort. `key` is
-- "name" (by character name) or an expansion abbr (by that tier's skill level, missing
-- last). Character name is always the ascending tiebreak, so equal values keep a stable
-- order (table.sort is unstable). Returns `entries` for chaining.
---@param entries table[]  { toon, prof, detail } entries from buildCharList
---@param key any          "name" or an expansion abbr
---@param desc boolean     descending when true
---@return table[]
local function sortCharEntries(entries, key, desc)
  sort(entries, function(a, b)
    if key == "name" then
      if a.toon.name ~= b.toon.name then
        if desc then return a.toon.name > b.toon.name else return a.toon.name < b.toon.name end
      end
      return false
    end
    local sa, sb = entrySkill(a, key), entrySkill(b, key)
    if sa ~= sb then
      if desc then return sa > sb else return sa < sb end
    end
    return a.toon.name < b.toon.name
  end)
  return entries
end

---@class Warbandeer
---@field profs table  shared data + helpers for the Professions view (see views/profs/ProfsData.lua)
ns.profs = {
  EXP_ORDER = EXP_ORDER, EXP_ABBR = EXP_ABBR, PROF_ORDER = PROF_ORDER,
  CHAR_LIST_H = CHAR_LIST_H, VIEW_WIDTH = VIEW_WIDTH,
  TRANSPARENT = TRANSPARENT, SELECTED = SELECTED, DIM = DIM,
  makeGridColInfo = makeGridColInfo, makeCharColInfo = makeCharColInfo,
  makeEmptyRow = makeEmptyRow, rowDivider = rowDivider, skillCell = skillCell,
  buildBestSkills = buildBestSkills, buildCharList = buildCharList,
  sortCharEntries = sortCharEntries,
}
