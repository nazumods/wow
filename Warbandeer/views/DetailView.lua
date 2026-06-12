---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local insert = table.insert
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local Button, Tooltip = ui.Button, ui.Tooltip
local LabeledBar, StatCard, FilterDropdown = ns.LabeledBar, ns.StatCard, ns.FilterDropdown
local theme = ns.theme
local Colors = ns.Colors
local BottomLeft, BottomRight = ui.edge.BottomLeft, ui.edge.BottomRight
local BreakUpLargeNumbers = BreakUpLargeNumbers
local C_TradeSkillUI = C_TradeSkillUI

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
local CONTENT_TOP = P + PORTRAIT + GAP          -- stat strip top
local PROF_HEADER_Y = CONTENT_TOP + STRIP_H + GAP -- professions header top

-- ─── Gear list (right column) ─────────────────────────────────────────────────
local GEAR_PAD = 12                             -- gear panel inner padding
local GEAR_ROW_H = 20                           -- one gear row
local GEAR_HEADER_GAP = 8                       -- header → first row
local GEAR_ICON_W, GEAR_ICON_GAP = 18, 8        -- left slot-icon column / gap to name
local GEAR_ILVL_W, GEAR_TRACK_W = 30, 28        -- right-aligned ilvl / track columns
local GEAR_COL_GAP = 8                          -- gap between name/ilvl/track
local GEAR_NAME_MIN, GEAR_NAME_MAX = 150, 280   -- autosize clamp for the name column
local GEAR_X = P + PANEL_W + GAP                -- gear panel left edge

-- Width left of the name column (slot icon + gap).
local GEAR_LEAD_W = GEAR_ICON_W + GEAR_ICON_GAP
-- Width contributed by everything right of the name column (gaps + ilvl + track).
local GEAR_EXTRAS_W = GEAR_COL_GAP + GEAR_ILVL_W + GEAR_COL_GAP + GEAR_TRACK_W
local function gearInnerW(nameW) return GEAR_LEAD_W + nameW + GEAR_EXTRAS_W end
local function gearPanelW(nameW) return gearInnerW(nameW) + 2 * GEAR_PAD end

-- Slot → transmog-nav-slot atlas. Only appearance slots have these atlases, so the
-- non-transmoggable slots (Neck/Finger/Trinket) map to nil and render a blank icon
-- column (space still reserved so the name column stays aligned across rows).
local GEAR_SLOT_ATLAS = {
  Head     = "transmog-nav-slot-head",
  Shoulder = "transmog-nav-slot-shoulder",
  Back     = "transmog-nav-slot-back",
  Chest    = "transmog-nav-slot-chest",
  Wrist    = "transmog-nav-slot-wrist",
  Hands    = "transmog-nav-slot-hands",
  Waist    = "transmog-nav-slot-waist",
  Legs     = "transmog-nav-slot-legs",
  Feet     = "transmog-nav-slot-feet",
  MainHand = "transmog-nav-slot-mainhand",
  OffHand  = "transmog-nav-slot-secondaryhand",
}

-- Rarity color pulled straight from the stored item link's color prefix, so it works
-- for any character without relying on the item being in this client's cache. Modern
-- links color by quality name (|cnIQ<n>: where n is Enum.ItemQuality); older ones use
-- the literal |cffRRGGBB hex. Handle both.
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS
---@return number, number, number
local function rarityColor(link)
  if link then
    local iq = link:match("|cnIQ(%d+):")
    if iq then
      local q = ITEM_QUALITY_COLORS[tonumber(iq)]
      if q then return q.r, q.g, q.b end
    end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    if hex then
      return tonumber(hex:sub(1, 2), 16) / 255,
             tonumber(hex:sub(3, 4), 16) / 255,
             tonumber(hex:sub(5, 6), 16) / 255
    end
  end
  local t = theme.colors.text
  return t[1], t[2], t[3]
end

local VIEW_WIDTH = GEAR_X + gearPanelW(GEAR_NAME_MIN) + P

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
---@field _gearRows table[]      pooled gear rows
---@field _numGearRows integer   number of gear rows currently visible
local DetailView = Class(Frame, function(self)
  local c = theme.colors
  self._char = ns.api:GetCharacterData()
  self._profRows = {}
  self._numRows = 0
  self._gearRows = {}
  self._numGearRows = 0

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

  -- Gear list down the right column: one row per equipped slot.
  self.gearPanel = Frame:new{
    parent = self, background = c.module,
    position = { TopLeft = {GEAR_X, -CONTENT_TOP}, Width = gearPanelW(GEAR_NAME_MIN), Height = STRIP_H },
  }
  self.gearHeader = Label:new{
    parent = self.gearPanel, fontInfo = theme.fonts.caps, color = c.muted,
    text = "GEAR",
    position = { TopLeft = {GEAR_PAD, -GEAR_PAD} },
  }

  self:Width(VIEW_WIDTH)
  self:Height(PROF_HEADER_Y + 40)
end, {
  name   = "detail",
  background = theme.colors.window,
})
DetailView.name = "detail"
DetailView._title = "Detail"
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
    -- Click the bar to open that profession's window (no-op for alts you're not on).
    onClick = function()
      if row._skillID then C_TradeSkillUI.OpenTradeSkill(row._skillID) end
    end,
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

-- ─── Gear rows ─────────────────────────────────────────────────────────────────

-- Grab (or lazily create) a pooled gear row: item name (truncated) on the left,
-- with the item level and upgrade-track badge right-aligned.
---@return table
function DetailView:_gearRow(i)
  local row = self._gearRows[i]
  if row then return row end

  local c = theme.colors
  local prev = self._gearRows[i - 1]
  local frame = Frame:new{
    parent = self.gearPanel,
    position = {
      TopLeft = prev and {prev.frame, BottomLeft, 0, 0}
                     or  {self.gearHeader, BottomLeft, 0, -GEAR_HEADER_GAP},
      Width  = gearInnerW(GEAR_NAME_MIN),  -- resized to fit content in OnBeforeShow
      Height = GEAR_ROW_H,
    },
  }
  row = { frame = frame }

  -- Slot icon pinned to the left (blank for non-transmoggable slots; see GEAR_SLOT_ATLAS).
  row.icon = Texture:new{
    parent = frame, layer = ui.layer.Artwork,
    position = { Left = {frame, ui.edge.Left, 0, 0}, Width = GEAR_ICON_W, Height = GEAR_ICON_W },
  }
  -- Track badge pinned to the right, ilvl left of it, name fills the remaining space.
  row.track = Label:new{
    parent = frame, fontInfo = theme.fonts.stat, color = c.gold,
    justifyH = ui.justify.Right,
    position = { Right = {frame, ui.edge.Right, 0, 0}, Width = GEAR_TRACK_W },
  }
  row.ilvl = Label:new{
    parent = frame, fontInfo = theme.fonts.stat,
    justifyH = ui.justify.Right,
    position = { Right = {row.track, ui.edge.Left, -GEAR_COL_GAP, 0}, Width = GEAR_ILVL_W },
  }
  row.name = Label:new{
    parent = frame, fontInfo = theme.fonts.body,
    justifyH = ui.justify.Left, wordWrap = false,
    position = {
      Left  = {row.icon, ui.edge.Right, GEAR_ICON_GAP, 0},
      Right = {row.ilvl, ui.edge.Left, -GEAR_COL_GAP, 0},
    },
  }

  self._gearRows[i] = row
  return row
end

-- Populate a visible gear row for an equipped item. `slotKey` selects the slot icon.
function DetailView:_showGear(i, item, slotKey)
  local row = self:_gearRow(i)
  local atlas = GEAR_SLOT_ATLAS[slotKey]
  if atlas then
    row.icon:Atlas(atlas, false)
    row.icon:Show()
  else
    row.icon:Hide()  -- non-transmoggable slot: reserve the column, leave it blank
  end
  row.name:Text(item.name or ""):Color(rarityColor(item.link))
  local ilvl = item.ilvl or 0
  row.ilvl:Text(tostring(ilvl)):Color(ns.IlvlColorObj(ilvl))
  if item.track and item.trackLevel and item.trackLevel > 0 then
    row.track:Text(item.track:sub(1, 1) .. item.trackLevel)
  else
    row.track:Text("")
  end
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

-- Direct navigation (the rail's Detail glyph or `/wb detail`) always shows the
-- logged-in character with fresh data; a character picked via Select sticks only
-- until the user navigates here directly again.
function DetailView:OnNavigate()
  self._char = ns.api:GetCharacterData()
  if self._filter and self._filter.label then
    self._filter.label:Text(self._char.name .. CHEVRON)
  end
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
  local raceList = char.isAlliance and ns.api.ALLIANCE_RACES or ns.api.HORDE_RACES
  self.subtitle:Text((raceList[char.raceIdx] or char.race) .. " " .. char.className)
  self.realm:Text(char.realm)

  local ilvl = (char.equipment and char.equipment.ilvl) or 0
  self.ilvlCard:Amount(string.format("%.1f", ilvl), ns.IlvlColorObj(ilvl))
  local hrs = (char.playtime and char.playtime.total and math.floor(char.playtime.total / 3600)) or 0
  self.playCard:Amount(BreakUpLargeNumbers(hrs) .. " hrs", c.text)

  -- The two flexible slots plus Fishing/Cooking, so a main cook/fisher can be set too.
  local profs = char.basic.professions or {}
  local i = 0
  for _, slot in ipairs({ "primary", "secondary", "fishing", "cooking" }) do
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

  -- Gear list (right column): one row per equipped slot, in slot order. The name
  -- column autosizes to the longest equipped item name (clamped to a min/max).
  local slots = (char.equipment and char.equipment.slots) or {}
  local g, maxNameW = 0, 0
  for _, slotKey in ipairs(ns.gearSlots) do
    local item = slots[slotKey]
    if item then
      g = g + 1
      self:_showGear(g, item, slotKey)
      local w = self._gearRows[g].name:StringWidth()
      if w > maxNameW then maxNameW = w end
    end
  end
  for j = g + 1, self._numGearRows do
    self._gearRows[j].frame:Hide()
  end
  self._numGearRows = g

  -- Size the name column to content, then the rows / panel / view to match.
  local nameW = math.max(GEAR_NAME_MIN, math.min(GEAR_NAME_MAX, math.ceil(maxNameW)))
  local innerW = gearInnerW(nameW)
  for j = 1, g do self._gearRows[j].frame:Width(innerW) end
  self.gearPanel:Width(gearPanelW(nameW))

  -- Left column height (identity + stats + professions).
  local leftH = PROF_HEADER_Y + self.profHeader:Height()
  if i > 0 then leftH = leftH + 8 + i * ROW_H + (i - 1) * ROW_GAP end
  leftH = leftH + P

  -- Right column height (gear panel).
  local gearH = GEAR_PAD + self.gearHeader:Height()
  if g > 0 then gearH = gearH + GEAR_HEADER_GAP + g * GEAR_ROW_H end
  gearH = gearH + GEAR_PAD
  self.gearPanel:Height(gearH)
  local rightH = CONTENT_TOP + gearH + P

  self:Width(GEAR_X + gearPanelW(nameW) + P)
  self:Height(math.max(leftH, rightH))
end

function DetailView:update() end
