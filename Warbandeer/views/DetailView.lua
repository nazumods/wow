local _, ns = ...
local ui = ns.ui
local insert = table.insert
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local Button, Tooltip = ui.Button, ui.Tooltip
local LabeledBar, StatCard, FilterDropdown = ns.LabeledBar, ns.StatCard, ns.FilterDropdown
local theme = ns.theme
local Colors = ns.Colors
local BottomLeft, BottomRight = ui.edge.BottomLeft, ui.edge.BottomRight
local BreakUpLargeNumbers = BreakUpLargeNumbers

-- ─── Layout ─────────────────────────────────────────────────────────────────────
local P, GAP = 12, 12          -- outer padding / section gap
local PORTRAIT = 56            -- class-icon portrait edge
local STRIP_H = 56             -- stat-card height
local ICON_W, ICON_GAP = 28, 10  -- profession icon
local BAR_W = 150              -- labelled bar width
local DD_GAP, DD_W = 12, 124   -- intent dropdown gap / width
local ROW_PAD = 12             -- inner padding of a profession panel
local ROW_H, ROW_GAP = 44, 8   -- profession panel height / gap between panels

local PANEL_W = ROW_PAD + ICON_W + ICON_GAP + BAR_W + DD_GAP + DD_W + ROW_PAD
local VIEW_WIDTH = P + PANEL_W + P
local CONTENT_TOP = P + PORTRAIT + GAP          -- stat strip top
local PROF_HEADER_Y = CONTENT_TOP + STRIP_H + GAP -- professions header top

-- vertical centring of each element inside a profession panel
local ICON_Y, BAR_Y, DD_Y = (ROW_H - ICON_W) / 2, 8, (ROW_H - 20) / 2
local BAR_X = ROW_PAD + ICON_W + ICON_GAP
local DD_X = BAR_X + BAR_W + DD_GAP

-- Inline down-arrow (atlas markup: |A:atlasName:height:width|a) for the picker.
local CHEVRON = "  |A:UI-HUD-ActionBar-PageDownArrow-Disabled:12:12|a"

-- Intent editor options. `key = false` is the "clear" sentinel (stored as nil).
local INTENT_OPTIONS = {
  { key = "main",      label = "Main Crafter" },
  { key = "secondary", label = "Secondary"    },
  { key = "gatherer",  label = "Gatherer"     },
  { key = false,       label = "Unset"        },
}
-- Bar fill tint per intent, so picking an intent recolours the bar. Unset reads as
-- a neutral grey track.
local INTENT_COLOR = {
  main      = theme.colors.orange,
  secondary = theme.colors.gold,
  gatherer  = theme.colors.green,
}
local function intentColor(intent) return INTENT_COLOR[intent] or theme.colors.track end

-- ─── View ─────────────────────────────────────────────────────────────────────

---@class DetailView: Frame
---@field _char Character        currently displayed character
---@field _profRows table[]      pooled profession rows
---@field _numRows integer       number of rows currently visible
local DetailView = Class(Frame, function(self)
  local c = theme.colors
  self._char = ns.api:GetCharacterData()
  self._profRows = {}
  self._numRows = 0

  -- Portrait: class icon framed by a class-coloured border, with a level badge.
  self.portraitBorder = Texture:new{
    parent = self, layer = ui.layer.Background,
    position = { TopLeft = {P, -P}, Width = PORTRAIT, Height = PORTRAIT },
  }
  self.portrait = Texture:new{
    parent = self, layer = ui.layer.Artwork,
    position = { TopLeft = {P + 2, -(P + 2)}, Width = PORTRAIT - 4, Height = PORTRAIT - 4 },
  }
  self.badge = Texture:new{
    parent = self, layer = ui.layer.Overlay, color = {0, 0, 0, 0.65},
    position = {
      BottomLeft  = {self.portrait, BottomLeft, 0, 0},
      BottomRight = {self.portrait, BottomRight, 0, 0},
      Height = 16,
    },
  }
  self.level = Label:new{
    parent = self, layer = ui.layer.Overlay, fontInfo = theme.fonts.caps, color = c.text,
    position = { Center = {self.badge, ui.edge.Center, 0, 0} },
  }

  -- Identity block to the right of the portrait.
  local textX = P + PORTRAIT + 14
  self.heading = Label:new{
    parent = self, fontInfo = theme.fonts.headline,
    position = { TopLeft = {textX, -(P + 6)} },
  }
  self.subtitle = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = c.muted,
    position = { TopLeft = {self.heading, BottomLeft, 0, -4} },
  }
  self.realm = Label:new{
    parent = self, fontInfo = theme.fonts.subcaps, color = c.muted,
    position = { TopLeft = {self.subtitle, BottomLeft, 0, -4} },
  }

  -- Stat strip: Item Level + Playtime (no per-character M+ rating is tracked).
  local cardW = (PANEL_W - GAP) / 2
  self.ilvlCard = StatCard:new{
    parent = self, caption = "Item Level",
    position = { TopLeft = {P, -CONTENT_TOP}, Width = cardW, Height = STRIP_H },
  }
  self.playCard = StatCard:new{
    parent = self, caption = "Playtime",
    position = { TopLeft = {P + cardW + GAP, -CONTENT_TOP}, Width = cardW, Height = STRIP_H },
  }

  self.profHeader = Label:new{
    parent = self, fontInfo = theme.fonts.caps, color = c.muted,
    text = "PROFESSIONS",
    position = { TopLeft = {P, -PROF_HEADER_Y} },
  }

  self:Width(VIEW_WIDTH)
  self:Height(PROF_HEADER_Y + 40)
end, {
  name   = "detail",
  _title = "Detail",
  background = theme.colors.window,
})
DetailView.name = "detail"
ns.views.DetailView = DetailView

-- ─── Profession rows ─────────────────────────────────────────────────────────

-- Grab (or lazily create) a pooled profession panel: icon on the left, a labelled
-- progress bar (skill / max) in the middle, and an intent dropdown on the right
-- whose menu writes through to profIntent for this row's profession / character.
---@return table
function DetailView:_profRow(i)
  local row = self._profRows[i]
  if row then return row end

  local prev = self._profRows[i - 1]
  local panel = Frame:new{
    parent = self,
    background = theme.colors.module,
    position = {
      TopLeft = prev and {prev.panel, BottomLeft, 0, -ROW_GAP}
                     or  {self.profHeader, BottomLeft, 0, -8},
      Width  = PANEL_W,
      Height = ROW_H,
    },
  }
  row = { panel = panel }

  row.icon = Texture:new{
    parent = panel, layer = ui.layer.Artwork,
    position = { TopLeft = {ROW_PAD, -ICON_Y}, Width = ICON_W, Height = ICON_W },
  }
  row.bar = LabeledBar:new{
    parent = panel,
    width = BAR_W,
    position = { TopLeft = {BAR_X, -BAR_Y} },
  }
  row.dropdown = FilterDropdown:new{
    parent    = panel,
    options   = INTENT_OPTIONS,
    width     = DD_W,
    menuWidth = DD_W,
    position  = { TopLeft = {DD_X, -DD_Y} },
    onSelect  = function(_, key)
      ns.data.SetProfIntent(self._char.name, row._skillID, key or nil)
      row.bar:BarColor(intentColor(key or nil))
    end,
  }

  self._profRows[i] = row
  return row
end

-- Populate a visible row for a profession.
function DetailView:_showProf(i, prof)
  local row = self:_profRow(i)
  row._skillID = prof.skillID
  if prof.icon then row.icon:Texture(prof.icon) end

  local maxSkill = prof.maxSkill or 0
  local skill = prof.skillLevel or 0
  local value = maxSkill > 0 and (skill .. " / " .. maxSkill) or tostring(skill)
  row.bar:Label(prof.name or ""):Value(value):Fill(maxSkill > 0 and skill / maxSkill or 0)

  local intent = ns.data.GetProfIntent(self._char.name, prof.skillID)
  row.bar:BarColor(intentColor(intent))
  row.dropdown:Select(intent or false)
  row.panel:Show()
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
  local c = theme.colors
  local color = Colors[char.classKey] or { 1, 1, 1 }

  local atlas = ns.icons.classes[char.classId]
  if atlas then self.portrait:Atlas(atlas, false) end
  self.portraitBorder:Color(color[1], color[2], color[3], 1)
  self.level:Text(char.basic.level)
  self.heading:Text(char.name):Color(color)
  self.subtitle:Text(char.race .. " " .. char.className)
  self.realm:Text(char.realm)

  local ilvl = (char.equipment and char.equipment.ilvl) or 0
  self.ilvlCard:Amount(string.format("%.1f", ilvl), ns.IlvlColorObj(ilvl))
  local hrs = (char.playtime and char.playtime.total and math.floor(char.playtime.total / 3600)) or 0
  self.playCard:Amount(BreakUpLargeNumbers(hrs) .. " hrs", c.text)

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
  self.profHeader:Text(i == 0 and "NO PROFESSIONS" or "PROFESSIONS")
  for j = i + 1, self._numRows do
    self._profRows[j].panel:Hide()
  end
  self._numRows = i

  local h = PROF_HEADER_Y + self.profHeader:Height()
  if i > 0 then h = h + 8 + i * ROW_H + (i - 1) * ROW_GAP end
  self:Height(h + P)
end

function DetailView:update() end
