local _, ns = ...
local ui = ns.ui
local insert = table.insert
local floor = math.floor
local Class, Frame, TableFrame = ns.lua.Class, ui.Frame, ui.TableFrame
local Button, Label, Tooltip = ui.Button, ui.Label, ui.Tooltip
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
-- Inline down-arrow (atlas markup: |A:atlasName:height:width|a). The minimal
-- scrollbar arrow already points down and is a neutral grey, so no rotation/tint.
local CHEVRON = "  |A:UI-HUD-ActionBar-PageDownArrow-Disabled:12:12|a"
local EXPANSIONS = {
  { key = "df",       label = "Dragonflight",   enabled = false },
  { key = "tww",      label = "The War Within", enabled = false },
  { key = "midnight", label = "Midnight",       enabled = true  },
}

local PROF_COL_W, CRAFTER_COL_W, CONC_COL_W, RECIPE_COL_W = 104, 104, 72, 78
local VIEW_WIDTH = PROF_COL_W + CRAFTER_COL_W + CONC_COL_W + RECIPE_COL_W

local TRANSPARENT = { color = Colors.TransparentBlack }

local function rowBgColor(i)
  return i % 2 == 0 and { 0, 0, 0, 0.4 } or { 0, 0, 0, 0.2 }
end

local function buildColInfo()
  return {
    { name = "Profession", width = PROF_COL_W,    backdrop = TRANSPARENT, justifyH = ui.justify.Left },
    { name = "Crafter",    width = CRAFTER_COL_W, backdrop = TRANSPARENT, justifyH = ui.justify.Left },
    { name = "Conc",       width = CONC_COL_W,    backdrop = TRANSPARENT, justifyH = ui.justify.Center,
      tooltip = "Main crafter's concentration" },
    { name = "Recipes",    width = RECIPE_COL_W,  backdrop = TRANSPARENT, justifyH = ui.justify.Center,
      tooltip = "Learned recipe %" },
  }
end

local function tipAt(cell)
  ui.tip:AnchorTo(cell, "ANCHOR_BOTTOMRIGHT", -10, 10)
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
    position = { TopLeft = {} },
  }
  self._numCols = 4
  self:Width(VIEW_WIDTH)
  self:Height(self.tbl:Height())
end, {
  name   = "crafting",
  _title = "Crafting",
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

function CraftingView:buildRow(id, toons)
  local info = PROF_INFO[id]
  local mainCrafter, isFlagged = ns.data.GetMainCrafter(id, toons)
  local profToons = ns.data.GetProfToons(id, toons)
  return {
    { text = info.name, justifyH = ui.justify.Left },
    self:crafterCell(info, mainCrafter, isFlagged, profToons),
    self:concCell(id, info, mainCrafter),
    self:recipeCell(id, mainCrafter),
  }
end

-- ─── Filter ───────────────────────────────────────────────────────────────────

function CraftingView:BuildFilter(parent)
  local box = Frame:new{ parent = parent, position = { Height = 20, Width = 96 } }

  box.button = Button:new{
    parent   = box,
    position = { All = true },
    glow     = false,
    OnClick  = function() box.menu:Toggle() end,
  }
  box.label = Label:new{
    parent   = box.button,
    position = { Center = {} },
    text     = EXP_LABEL[self._expansion] .. CHEVRON,
  }

  local lines = {}
  for _, e in ipairs(EXPANSIONS) do
    insert(lines, {
      text       = e.enabled and e.label or (C_GREY .. e.label .. C_END),
      background = { 0, 0, 0, 0 },
      onEnter    = function(line) line.background:Color(1, 1, 1, 0.2) end,
      onLeave    = function(line) line.background:Color(1, 1, 1, 0) end,
      onClick    = function()
        if not e.enabled then return end
        box.menu:Hide()
        if self._expansion == e.key then return end
        self._expansion = e.key
        box.label:Text(e.label .. CHEVRON)
        self:OnBeforeShow()
        if ns.MainWindow then ns.MainWindow:Fit() end
      end,
    })
  end
  box.menu = Tooltip:new{
    position = {
      TopRight = { box, ui.edge.BottomRight, 0, 2 },
      Width    = 120,
    },
    lines = lines,
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

  local emptyRow = {}
  for _ = 1, self._numCols do insert(emptyRow, "") end

  local rowData = {}
  for i, id in ipairs(present) do
    insert(rowData, self:buildRow(id, toons))
    self.tbl.rows[i]:backdropColor(unpack(rowBgColor(i)))
  end
  for i = #present + 1, #self.tbl.rows do
    insert(rowData, emptyRow)
    self.tbl.rows[i]:backdropColor(0, 0, 0, 0)
  end

  self.tbl.data = rowData
  self.tbl:update()
  self.tbl:Autosize()   -- recompute column widths now that cells are populated

  self:Width(self.tbl:Width())
  self:Height(self.tbl:Height())
end
