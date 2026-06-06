local _, ns = ...
local ui = ns.ui
local insert = table.insert
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label
local Button, Tooltip = ui.Button, ui.Tooltip
local Colors, ColorS = ns.Colors, ns.Colors.Strings
local C_GREY, C_END = ColorS.GREY, ColorS.END

local PAD = 10
local VIEW_WIDTH = 320
local ROW_H = 22
local INTENT_BTN_W = 120

-- Inline down-arrow (atlas markup: |A:atlasName:height:width|a). The minimal
-- scrollbar arrow already points down and is a neutral grey, so no rotation/tint.
local CHEVRON = "  |A:UI-HUD-ActionBar-PageDownArrow-Disabled:12:12|a"

local INTENT_LABEL = { main = "Main Crafter", secondary = "Secondary", gatherer = "Gatherer" }
-- Editor options.  `key = false` is the "clear" sentinel (stored as nil).
local INTENT_OPTIONS = {
  { key = "main",      label = "Main Crafter" },
  { key = "secondary", label = "Secondary"    },
  { key = "gatherer",  label = "Gatherer"     },
  { key = false,       label = C_GREY .. "Unset" .. C_END },
}

-- ─── View ─────────────────────────────────────────────────────────────────────

---@class DetailView: Frame
---@field _char Character        currently displayed character
---@field _profRows table[]      pooled profession-intent rows
---@field _numRows integer       number of rows currently visible
local DetailView = Class(Frame, function(self)
  self._char = ns.api:GetCharacterData()
  self._profRows = {}
  self._numRows = 0

  self.heading = Label:new{
    parent = self,
    position = { TopLeft = {PAD, -PAD} },
  }
  self.realm = Label:new{
    parent = self,
    font = ui.fonts.GameFontHighlightSmall,
    position = { TopLeft = {self.heading, ui.edge.BottomLeft, 0, -6} },
  }
  self.ilvl = Label:new{
    parent = self,
    font = ui.fonts.GameFontHighlightSmall,
    position = { TopLeft = {self.realm, ui.edge.BottomLeft, 0, -4} },
  }
  self.profHeader = Label:new{
    parent = self,
    color = NORMAL_FONT_COLOR,
    text = "Professions",
    position = { TopLeft = {self.ilvl, ui.edge.BottomLeft, 0, -12} },
  }

  self:Width(VIEW_WIDTH)
  self:Height(300)
end, {
  name   = "detail",
  _title = "Detail",
})
DetailView.name = "detail"
ns.views.DetailView = DetailView

-- ─── Profession intent rows ─────────────────────────────────────────────────

-- Grab (or lazily create) a pooled profession row.  Each row carries a name label
-- on the left and an intent dropdown button on the right whose menu writes through
-- to the profIntent DB for the row's current profession / displayed character.
---@return table
function DetailView:_profRow(i)
  local row = self._profRows[i]
  if row then return row end

  local prev = self._profRows[i - 1]
  local frame = Frame:new{
    parent = self,
    position = {
      TopLeft = prev and {prev.frame, ui.edge.BottomLeft, 0, -4}
                     or  {self.profHeader, ui.edge.BottomLeft, 0, -8},
      Width   = VIEW_WIDTH - 2 * PAD,
      Height  = ROW_H,
    },
  }
  row = { frame = frame }

  row.name = Label:new{
    parent   = frame,
    position = { Left = {} },
  }

  row.button = Button:new{
    parent   = frame,
    glow     = false,
    position = { Right = {}, Width = INTENT_BTN_W, Height = ROW_H - 2 },
    OnClick  = function() row.menu:Toggle() end,
  }
  row.label = Label:new{
    parent   = row.button,
    position = { Center = {} },
  }

  local lines = {}
  for _, opt in ipairs(INTENT_OPTIONS) do
    insert(lines, {
      text       = opt.label,
      background = { 0, 0, 0, 0 },
      onEnter    = function(line) line.background:Color(1, 1, 1, 0.2) end,
      onLeave    = function(line) line.background:Color(1, 1, 1, 0) end,
      onClick    = function()
        row.menu:Hide()
        ns.data.SetProfIntent(self._char.name, row._skillID, opt.key or nil)
        self:_setIntentLabel(row, opt.key or nil)
      end,
    })
  end
  row.menu = Tooltip:new{
    position = {
      TopRight = { row.button, ui.edge.BottomRight, 0, 2 },
      Width    = INTENT_BTN_W,
    },
    lines = lines,
  }

  self._profRows[i] = row
  return row
end

function DetailView:_setIntentLabel(row, intent)
  row.label:Text((INTENT_LABEL[intent] or "Unset") .. CHEVRON)
end

-- Populate a visible row for a profession.
function DetailView:_showProf(i, prof)
  local row = self:_profRow(i)
  row._skillID = prof.skillID
  row.name:Text(prof.name .. " " .. C_GREY .. "(" .. (prof.skillLevel or 0) .. ")" .. C_END)
  self:_setIntentLabel(row, ns.data.GetProfIntent(self._char.name, prof.skillID))
  row.frame:Show()
end

-- ─── Filter (character picker) ──────────────────────────────────────────────

local function sortedCharacters()
  local toons = {}
  for _, t in ipairs(ns.api.GetAllCharacters()) do insert(toons, t) end
  table.sort(toons, function(a, b) return a.name < b.name end)
  return toons
end

function DetailView:BuildFilter(parent)
  local box = Frame:new{ parent = parent, position = { Height = 20, Width = 130 } }

  box.button = Button:new{
    parent   = box,
    position = { All = true },
    glow     = false,
    OnClick  = function() box.menu:Toggle() end,
  }
  box.label = Label:new{
    parent   = box.button,
    position = { Center = {} },
    text     = self._char.name .. CHEVRON,
  }

  local lines = {}
  for _, toon in ipairs(sortedCharacters()) do
    local c = Colors[toon.classKey] or { 1, 1, 1 }
    insert(lines, {
      text       = toon.name,
      color      = c,
      background = { 0, 0, 0, 0 },
      onEnter    = function(line) line.background:Color(1, 1, 1, 0.2) end,
      onLeave    = function(line) line.background:Color(1, 1, 1, 0) end,
      onClick    = function()
        box.menu:Hide()
        self:Select(toon)
      end,
    })
  end
  box.menu = Tooltip:new{
    position = {
      TopRight = { box, ui.edge.BottomRight, 0, 2 },
      Width    = 130,
    },
    -- The warband can hold many characters; cap the menu height and scroll.
    maxHeight = 320,
    lines     = lines,
  }

  self._filter = box
  return box
end

-- Select a character to display. Used by the titlebar picker and by clicking a
-- character on the Overview. Updates the picker label, rebuilds the body, and
-- refits the window. No-op if the character is already shown.
---@param toon Character
function DetailView:Select(toon)
  if not toon or self._char == toon then return end
  self._char = toon
  if self._filter and self._filter.label then
    self._filter.label:Text(toon.name .. CHEVRON)
  end
  self:OnBeforeShow()
  if ns.MainWindow then ns.MainWindow:Fit() end
end

-- ─── Lifecycle ────────────────────────────────────────────────────────────────

function DetailView:OnBeforeShow()
  local char = self._char
  local color = Colors[char.classKey] or { 1, 1, 1 }

  self.heading:Text("Level " .. char.basic.level .. " " .. char.race .. " " .. char.className)
  self.heading:Color(color)
  self.realm:Text(C_GREY .. char.realm .. C_END)
  self.ilvl:Text("Item Level " .. ns.IlvlColor(char.equipment and char.equipment.ilvl or 0))

  -- Only the two flexible profession slots carry a meaningful crafter/gatherer intent.
  local profs = char.basic.professions or {}
  local i = 0
  for _, slot in ipairs({ "primary", "secondary" }) do
    local p = profs[slot]
    if p and p.skillID then
      i = i + 1
      self:_showProf(i, p)
    end
  end
  if i == 0 then
    self.profHeader:Text(C_GREY .. "No professions" .. C_END)
  else
    self.profHeader:Text("Professions")
  end
  for j = i + 1, self._numRows do
    self._profRows[j].frame:Hide()
  end
  self._numRows = i

  -- Height accumulates the fixed gaps baked into each element's anchor offset.
  local h = PAD
            + self.heading:Height()    + 6
            + self.realm:Height()      + 4
            + self.ilvl:Height()       + 12
            + self.profHeader:Height()
  if i > 0 then
    h = h + 8 + i * ROW_H + (i - 1) * 4
  end
  self:Height(h + PAD)
end

function DetailView:update() end
