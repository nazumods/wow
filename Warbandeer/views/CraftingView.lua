---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local insert = table.insert
local floor = math.floor
local Class, Frame, TableFrame, Texture = ns.lua.Class, ui.Frame, ui.TableFrame, ui.Texture
local theme = ns.theme
local Colors, ColorS = ns.Colors, ns.Colors.Strings
local C_GREEN, C_WHITE, C_ORANGE, C_GREY, C_END = ColorS.GREEN, ColorS.WHITE, ColorS.ORANGE, ColorS.GREY, ColorS.END

-- Crafting professions in display order.  hasCon = has a Midnight concentration
-- resource (the 8 crafters).  Skinning/Fishing/Cooking are included for their learned
-- recipe %, but show an em-dash for concentration.  Mining/Herbalism are excluded.
local PROF_ORDER = { 171, 164, 333, 202, 773, 755, 165, 197, 393, 356, 185 }
local PROF_INFO = {
  [171] = { name = "Alchemy",        hasCon = true  },
  [164] = { name = "Blacksmithing",  hasCon = true  },
  [333] = { name = "Enchanting",     hasCon = true  },
  [202] = { name = "Engineering",    hasCon = true  },
  [773] = { name = "Inscription",    hasCon = true  },
  [755] = { name = "Jewelcrafting",  hasCon = true  },
  [165] = { name = "Leatherworking", hasCon = true  },
  [197] = { name = "Tailoring",      hasCon = true  },
  [393] = { name = "Skinning",       hasCon = false },
  [356] = { name = "Fishing",        hasCon = false },
  [185] = { name = "Cooking",        hasCon = false },
}

local INTENT_LABEL = { main = "Main Crafter", secondary = "Secondary", gatherer = "Gatherer" }

-- Expansion filter.  Only Midnight is wired for now; DF/TWW are greyed placeholders
-- until their recipe/concentration data is captured (separate session).
local EXP_LABEL = { df = "Dragonflight", tww = "The War Within", midnight = "Midnight" }
local EXPANSIONS = {
  { key = "df",       label = "Dragonflight",   enabled = false },
  { key = "tww",      label = "The War Within", enabled = false },
  { key = "midnight", label = "Midnight",       enabled = true  },
}

local PROF_COL_W, CRAFTER_COL_W, SKILL_COL_W, CONC_COL_W, RECIPE_COL_W = 104, 104, 52, 72, 78
local VIEW_WIDTH = PROF_COL_W + CRAFTER_COL_W + SKILL_COL_W + CONC_COL_W + RECIPE_COL_W

local TRANSPARENT = { color = Colors.TransparentBlack }

-- Column headers: muted + uppercased, matching SummaryView. Outer
-- columns are inset (hPadL/hPadR) so cells don't sit against the table edges.
local function buildColInfo()
  local cols = {
    -- inset the Profession cells both sides (hPadL/hPadR) so long names like
    -- Leatherworking don't run up against the Crafter column; padding insets the
    -- header label to match (header uses the symmetric `padding`, cells use hPad*)
    { name = "Profession", width = PROF_COL_W,    backdrop = TRANSPARENT, justifyH = ui.justify.Left,
      hPadL = 8, hPadR = 8, padding = 8 },
    { name = "Crafter",    width = CRAFTER_COL_W, backdrop = TRANSPARENT, justifyH = ui.justify.Left },
    { name = "Skill",      width = SKILL_COL_W,   backdrop = TRANSPARENT, justifyH = ui.justify.Center,
      tooltip = "Main crafter's skill in the selected expansion" },
    { name = "Conc",       width = CONC_COL_W,    backdrop = TRANSPARENT, justifyH = ui.justify.Center,
      tooltip = "Main crafter's concentration" },
    { name = "Recipes",    width = RECIPE_COL_W,  backdrop = TRANSPARENT, justifyH = ui.justify.Center, hPadR = 8,
      tooltip = "Learned recipe %" },
  }
  for _, c in ipairs(cols) do
    c.name = c.name:upper()
  end
  return cols
end

-- A 1px divider line above the row, created once per row
-- frame and reused. Returns the texture so callers can Show/Hide it.
local function ensureDivider(row)
  if not row._divider then
    row._divider = Texture:new{
      parent = row,
      layer = ui.layer.Overlay,
      position = {
        TopLeft = {row, ui.edge.TopLeft, 0, 0},
        TopRight = {row, ui.edge.TopRight, 0, 0},
        Height = 1,
      },
      color = theme.colors.divider,
    }
  end
  return row._divider
end

local function tipAt(cell)
  ns.AnchorTip(cell)
  ui.tip:ClearLines()
end

-- ─── View ─────────────────────────────────────────────────────────────────────

---@class CraftingView: Frame
local CraftingView = Class(Frame, function(self)
  self._expansion = "midnight"
  self.tbl = TableFrame:new{
    parent   = self,
    colInfo  = buildColInfo(),
    autosize = true,   -- size each column to its widest cell (Conc was clipping)
    padding  = 8,      -- breathing room added per autosized column
    backdrop = TRANSPARENT,  -- glass surface shows through; rows carry the dividers
    position = { TopLeft = {} },
  }
  self._numCols = 5
  self:Width(VIEW_WIDTH)
  self:Height(self.tbl:Height())
end, {
  name       = "crafting",
  _title     = "Crafting",
  background = theme.colors.window,
})
CraftingView.name = "crafting"
ns.views.CraftingView = CraftingView

-- ─── Cell builders ────────────────────────────────────────────────────────────

-- Class-coloured main crafter name; dimmed when it's only the highest-skill fallback.
-- Tooltip lists every toon that has the profession and their intent.
function CraftingView:crafterCell(info, mainCrafter, isFlagged, profToons)
  if not mainCrafter then
    return { text = C_GREY .. "—" .. C_END, justifyH = ui.justify.Left }
  end
  local color = Colors[mainCrafter.classKey] or { 1, 1, 1 }
  if not isFlagged then color = Colors.alpha(color, 0.55) end
  return {
    text     = mainCrafter.name,
    color    = color,
    justifyH = ui.justify.Left,
    onEnter  = function(cell)
      tipAt(cell)
      ui.tip:AddLine(info.name)
      for _, e in ipairs(profToons) do
        local c = Colors[e.toon.classKey] or { 1, 1, 1 }
        local label = INTENT_LABEL[e.intent] or "Unset"
        ui.tip:AddLine(e.toon.name .. "  |cff9d9d9d" .. label .. " (" .. e.skill .. ")|r", c[1], c[2], c[3])
      end
      if not isFlagged then
        ui.tip:AddLine("No main crafter set — showing highest skill", 0.6, 0.6, 0.6)
      end
      ui.tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
  }
end

-- Main crafter's skill in the selected expansion, from the professions broker.
-- Returns skillLevel, maxSkillLevel (or nil, nil if not captured).
local function expansionSkill(mainCrafter, id, expName)
  local details = mainCrafter and mainCrafter.professions and mainCrafter.professions.details
  local detail  = details and details[id]
  if not detail or not detail.expansions then return nil, nil end
  for _, exp in ipairs(detail.expansions) do
    if exp.name == expName then return exp.skillLevel, exp.maxSkillLevel end
  end
  return nil, nil
end

-- Main crafter's skill for the selected expansion — just the number, colour-coded
-- by progress toward the expansion cap.
function CraftingView:skillCell(id, mainCrafter)
  local skill, max = expansionSkill(mainCrafter, id, EXP_LABEL[self._expansion])
  if not skill then
    return { text = C_GREY .. "—" .. C_END, justifyH = ui.justify.Center }
  end
  local col = C_WHITE
  if max and max > 0 then
    if     skill >= max       then col = C_GREEN
    elseif skill >= max * 0.5 then col = C_WHITE
    else                           col = C_ORANGE
    end
  end
  return {
    text     = col .. skill .. C_END,
    justifyH = ui.justify.Center,
    onEnter  = function(cell)
      tipAt(cell)
      ui.tip:AddLine(EXP_LABEL[self._expansion] .. " skill")
      ui.tip:AddLine(skill .. " / " .. (max or "?"))
      ui.tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
  }
end

-- Main crafter's concentration, projected to now.  Em-dash for non-concentration profs.
function CraftingView:concCell(id, info, mainCrafter)
  if not info.hasCon then
    return { text = C_GREY .. "—" .. C_END, justifyH = ui.justify.Center }
  end
  local entry = mainCrafter and mainCrafter.concentration
            and mainCrafter.concentration.data and mainCrafter.concentration.data[id]
  if not entry then
    return { text = C_GREY .. "—" .. C_END, justifyH = ui.justify.Center }
  end
  local qty, max, est = ns.data.EstimateConcentration(entry)
  local col = C_WHITE
  if max and max > 0 then
    local pct = qty / max
    if     pct >= 0.8 then col = C_GREEN
    elseif pct >= 0.3 then col = C_WHITE
    else                   col = C_ORANGE
    end
  end
  return {
    text     = col .. (est and "~" or "") .. qty .. "/" .. (max or "?") .. C_END,
    justifyH = ui.justify.Center,
    onEnter  = function(cell)
      tipAt(cell)
      ui.tip:AddLine(info.name .. " concentration")
      ui.tip:AddLine(qty .. " / " .. (max or "?") .. (est and "  (estimated)" or ""))
      ui.tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
  }
end

-- Learned recipe % for the selected expansion, from the main crafter's captured data.
function CraftingView:recipeCell(id, mainCrafter)
  local details = mainCrafter and mainCrafter.professions and mainCrafter.professions.details
  local bucket  = details and details[id] and details[id].recipes
              and details[id].recipes[self._expansion]
  if not bucket or not bucket.total or bucket.total == 0 then
    return { text = C_GREY .. "—" .. C_END, justifyH = ui.justify.Center }
  end
  local learned = #bucket.learned
  local pct     = floor(learned / bucket.total * 100 + 0.5)
  local col     = C_ORANGE
  if     pct >= 90 then col = C_GREEN
  elseif pct >= 50 then col = C_WHITE
  end
  return {
    text     = col .. pct .. "%" .. C_END,
    justifyH = ui.justify.Center,
    onEnter  = function(cell)
      tipAt(cell)
      ui.tip:AddLine(EXP_LABEL[self._expansion] .. " recipes")
      ui.tip:AddLine(learned .. " / " .. bucket.total .. " learned")
      ui.tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
  }
end

-- Make every cell drive the row's hover highlight and open the row's main
-- crafter in the Detail view on click, chaining onto any existing cell
-- onEnter/onLeave/onClick (so the per-column tooltips keep working). Cells are
-- decorated in place — buildRow builds a fresh cell table per call, so there are
-- no shared-table aliasing concerns (unlike SummaryView). The row resolves live
-- via self.tbl.rows[rowIdx] so it stays correct across rebuilds.
function CraftingView:decorateRow(cells, rowIdx, crafter)
  for _, cell in ipairs(cells) do
    local onEnter, onLeave, onClick = cell.onEnter, cell.onLeave, cell.onClick
    cell.onEnter = function(s)
      local row = self.tbl.rows[rowIdx]
      if row then row:backdropColor(theme.colors.hover) end
      if onEnter then onEnter(s) end
    end
    cell.onLeave = function(s)
      local row = self.tbl.rows[rowIdx]
      if row then row:backdropColor(0, 0, 0, 0) end
      if onLeave then onLeave(s) end
    end
    cell.onClick = function(s)
      if onClick then onClick(s) end
      local w = ns.MainWindow
      if crafter and w then
        w.views.detail:Select(crafter)
        w:view("detail")
      end
    end
  end
  return cells
end

function CraftingView:buildRow(id, toons, rowIdx)
  local info = PROF_INFO[id]
  local mainCrafter, isFlagged = ns.data.GetMainCrafter(id, toons)
  local profToons = ns.data.GetProfToons(id, toons)
  local cells = {
    { text = info.name, justifyH = ui.justify.Left },
    self:crafterCell(info, mainCrafter, isFlagged, profToons),
    self:skillCell(id, mainCrafter),
    self:concCell(id, info, mainCrafter),
    self:recipeCell(id, mainCrafter),
  }
  return self:decorateRow(cells, rowIdx, mainCrafter)
end

-- ─── Filter ───────────────────────────────────────────────────────────────────

function CraftingView:BuildFilter(parent)
  local box = ns.FilterDropdown:new{
    parent   = parent,
    options  = EXPANSIONS,
    selected = self._expansion,
    onSelect = function(_, key)
      self._expansion = key
      self:OnBeforeShow()
      if ns.MainWindow then ns.MainWindow:Fit() end
    end,
  }
  self._filter = box
  return box
end

-- ─── Lifecycle ────────────────────────────────────────────────────────────────

function CraftingView:OnBeforeShow()
  local toons = ns.api.GetAllCharacters()

  -- Only render rows for professions present somewhere in the warband.
  local present = {}
  for _, id in ipairs(PROF_ORDER) do
    if #ns.data.GetProfToons(id, toons) > 0 then insert(present, id) end
  end

  for _ = #self.tbl.rows + 1, #present do self.tbl:addRow({}) end
  self.tbl:ResizeRows(#present)

  local emptyRow = {}
  for _ = 1, self._numCols do insert(emptyRow, "") end

  local rowData = {}
  for i, id in ipairs(present) do
    insert(rowData, self:buildRow(id, toons, i))
    -- transparent rows; the glass surface shows through and a 1px divider above
    -- each populated row carries the chrome (matches SummaryView)
    self.tbl.rows[i]:backdropColor(0, 0, 0, 0)
    ensureDivider(self.tbl.rows[i]):Show()
  end
  for i = #present + 1, #self.tbl.rows do
    insert(rowData, emptyRow)
    self.tbl.rows[i]:backdropColor(0, 0, 0, 0)
    if self.tbl.rows[i]._divider then self.tbl.rows[i]._divider:Hide() end
  end

  self.tbl.data = rowData
  self.tbl:update()
  self.tbl:Autosize()   -- recompute column widths now that cells are populated

  self:Width(self.tbl:Width())
  self:Height(self.tbl:Height())
end
