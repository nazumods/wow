---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local insert = table.insert
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local unpack = unpack
local Button, Tooltip = ui.Button, ui.Tooltip
local LabeledBar, StatCard, FilterDropdown = ns.LabeledBar, ns.StatCard, ns.FilterDropdown
local theme = ns.theme
local Colors = ns.Colors
local BottomLeft, BottomRight = ui.edge.BottomLeft, ui.edge.BottomRight
local BreakUpLargeNumbers = BreakUpLargeNumbers
local C_TradeSkillUI = C_TradeSkillUI
local GetItemInfo, select = GetItemInfo, select

-- Wire a gear/prof-gear row for hover: a row highlight plus the shared item tooltip
-- (`ns.ShowItemTooltip`). The row stores its current item link in `frame._itemLink`
-- and, for an equipped slot with a suggested upgrade, that upgrade's link in
-- `frame._upgradeLink` (both updated each time it's populated), so a single set of
-- scripts survives row pooling. We always suppress the "Upgrade for:" block here
-- (the suggestion is shown as a side-by-side comparison instead).
local function attachItemTip(frame)
  local hi = Texture:new{
    parent = frame, layer = ui.layer.Background, color = theme.colors.hover,
    position = { All = true, Hide = true },
  }
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function()
    hi:Show()
    if frame._itemLink then ns.ShowItemTooltip(frame, frame._itemLink, frame._upgradeLink, true) end
  end)
  frame:SetScript("OnLeave", function()
    hi:Hide()
    ns.HideItemTooltip()
  end)
end

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
local GEAR_ROW_H = 20                           -- gear row head line (icon + name + ilvl + track)
local GEAR_UP_H = 14                            -- extra height for the suggested-upgrade sub-line
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

-- Required character level of an item link (5th GetItemInfo return), or nil when
-- the item isn't cached on this client (alt's bank/warband gear may not be).
---@return integer?
local function reqLevel(link) return link and select(5, GetItemInfo(link)) or nil end

local VIEW_WIDTH = GEAR_X + gearPanelW(GEAR_NAME_MIN) + P

-- vertical centring of each element inside a profession panel
local ICON_Y, BAR_Y, DD_Y = (ROW_H - ICON_W) / 2, 8, (ROW_H - 20) / 2
local BAR_X = ROW_PAD + ICON_W + ICON_GAP
local DD_X = BAR_X + BAR_W + DD_GAP

-- Profession-gear sub-rows: the equipped profession tool / accessories listed
-- beneath each profession panel. Indented to line up under the progress bar, with
-- the crafted-quality tier icon right-aligned.
local PG_ROW_H   = 18                            -- one profession-gear row
local PG_TOP_GAP = 6                             -- panel bottom → first gear row
local PG_TIER_W  = 16                            -- right-aligned crafted-tier icon edge
local PG_COL_GAP = 8                             -- gap between name and tier icon
local PG_INDENT  = BAR_X                         -- left inset within the panel
local PG_ROW_W   = PANEL_W - ROW_PAD - PG_INDENT -- gear-row content width
-- Crafted-quality tier icon atlas (1-5 stars). The "-Small" variant is sized for
-- inline list use; built by string so we don't depend on the LoD Professions UI.
local function tierAtlas(tier) return ("Professions-Icon-Quality-Tier%d-Small"):format(tier) end

-- Inline down-arrow (atlas markup: |A:atlasName:height:width|a) for the picker.
local CHEVRON = "  |A:UI-HUD-ActionBar-PageDownArrow-Disabled:12:12|a"

-- Intent editor options. `key = false` is the "clear" sentinel (stored as nil).
local INTENT_OPTIONS = {
  { key = "main",      label = "Main Crafter" },
  { key = "secondary", label = "Secondary"    },
  { key = "gatherer",  label = "Gatherer"     },
  { key = false,       label = "Unset"        },
}
-- Bar fill tint per intent, so picking an intent recolours the bar. Progression is
-- independent of intent: an unset profession still shows a filled, warm-neutral bar
-- (muted tan) so real skill reads as progressed; intent only overrides the tint.
local INTENT_COLOR = {
  main      = theme.colors.orange,
  secondary = theme.colors.gold,
  gatherer  = theme.colors.green,
}
local function intentColor(intent) return INTENT_COLOR[intent] or theme.colors.muted end

-- ─── View ─────────────────────────────────────────────────────────────────────

---@class DetailView: Frame
---@field _char Character        currently displayed character
---@field _profRows table[]      pooled profession rows (each owns a `gearRows` sub-pool)
---@field _numRows integer       number of rows currently visible
---@field _gearRows table[]      pooled equipped-gear rows (right column)
---@field _numGearRows integer   number of equipped-gear rows currently visible
---@field portraitBorder Texture
---@field portrait Texture
---@field badge Texture
---@field level Label
---@field heading Label
---@field subtitle Label
---@field realm Label
---@field ilvlCard StatCard
---@field playCard StatCard
---@field profHeader Label
---@field gearPanel Frame
---@field gearHeader Label
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
  row = { panel = panel, gearRows = {}, _numGearRows = 0 }

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

-- Grab (or lazily create) a pooled profession-gear sub-row for profession block
-- `row`: item name (rarity-coloured, truncated) on the left, the crafted-quality
-- tier icon right-aligned. Parented to the panel, anchored beneath it (or the
-- previous sub-row).
---@return table
function DetailView:_profGearRow(row, j)
  local sub = row.gearRows[j]
  if sub then return sub end

  local c = theme.colors
  local prev = row.gearRows[j - 1]
  local frame = Frame:new{
    parent = row.panel,
    position = {
      TopLeft = prev and {prev.frame, BottomLeft, 0, 0}
                     or  {row.panel, BottomLeft, PG_INDENT, -PG_TOP_GAP},
      Width  = PG_ROW_W,
      Height = PG_ROW_H,
    },
  }
  sub = { frame = frame }
  attachItemTip(frame)

  -- Crafted-quality tier icon pinned right (vertically centred), name fills the rest.
  sub.tier = Texture:new{
    parent = frame, layer = ui.layer.Artwork,
    position = { Right = {frame, ui.edge.Right, 0, 0}, Width = PG_TIER_W, Height = PG_TIER_W },
  }
  sub.name = Label:new{
    parent = frame, fontInfo = theme.fonts.body, color = c.muted,
    justifyH = ui.justify.Left, wordWrap = false,
    position = {
      Left  = {frame, ui.edge.Left, 0, 0},
      Right = {sub.tier, ui.edge.Left, -PG_COL_GAP, 0},
    },
  }

  row.gearRows[j] = sub
  return sub
end

-- Populate a visible row for a profession. The panel re-anchors beneath `anchor`
-- (the previous panel or the header — both left-aligned) with `gap` above it; for
-- a panel that follows another, `gap` already includes the previous panel's gear
-- list height, so the panels stay left-aligned while clearing the gear rows that
-- hang below them. Lists this profession's equipped gear beneath the panel.
function DetailView:_showProf(i, prof, anchor, gap)
  local row = self:_profRow(i)
  row._skillID = prof.skillID
  if prof.icon then row.icon:Texture(prof.icon) end

  row.panel:ClearAllPoints()
  row.panel:TopLeft(anchor, BottomLeft, 0, -gap)

  local maxSkill = prof.maxSkill or 0
  local skill = prof.skillLevel or 0
  local value = maxSkill > 0 and (skill .. " / " .. maxSkill) or tostring(skill)
  row.bar:Label(prof.name or ""):Value(value):Fill(maxSkill > 0 and skill / maxSkill or 0)

  local intent = ns.data.GetProfIntent(self._char.name, prof.skillID)
  row.bar:BarColor(intentColor(intent))
  row.dropdown:Select(intent or false)
  row.panel:Show()

  -- Profession gear: the tool + accessories equipped in this profession's slots,
  -- listed beneath the panel in inventory-slot order (tool first).
  local profGear = self._char.professions and self._char.professions.gear
                   and self._char.professions.gear[prof.skillID]
  local items = {}
  if profGear and profGear.slots then
    for invSlot, item in pairs(profGear.slots) do
      if item.name or item.link then insert(items, { slot = invSlot, item = item }) end
    end
    table.sort(items, function(a, b) return a.slot < b.slot end)
  end

  local g = 0
  for _, entry in ipairs(items) do
    g = g + 1
    local item = entry.item
    local sub = self:_profGearRow(row, g)
    sub.frame._itemLink = item.link
    sub.name:Text(item.name or "?"):Color(rarityColor(item.link))
    if item.tier and item.tier > 0 then
      sub.tier:Atlas(tierAtlas(item.tier), false)
      sub.tier:Show()
    else
      sub.tier:Hide()
    end
    sub.frame:Show()
  end
  for j = g + 1, row._numGearRows do row.gearRows[j].frame:Hide() end
  row._numGearRows = g
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
  attachItemTip(frame)

  -- Head-line elements are centred on the top GEAR_ROW_H band of the frame, so a
  -- row that grows taller for its upgrade sub-line keeps the item line at the top.
  local headY = -GEAR_ROW_H / 2
  -- Slot icon pinned to the left (Warbandeer gear atlas; see _showGear).
  row.icon = Texture:new{
    parent = frame, layer = ui.layer.Artwork,
    position = { Left = {frame, ui.edge.TopLeft, 0, headY}, Width = GEAR_ICON_W, Height = GEAR_ICON_W },
  }
  -- Track badge pinned to the right, ilvl left of it, name fills the remaining space.
  row.track = Label:new{
    parent = frame, fontInfo = theme.fonts.stat, color = c.gold,
    justifyH = ui.justify.Right,
    position = { Right = {frame, ui.edge.TopRight, 0, headY}, Width = GEAR_TRACK_W },
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
  -- Suggested upgrade, smaller, beneath the item name (hidden when none). Spans the
  -- name column out to the frame's right edge (name right + the ilvl/track extras),
  -- both points level with the name's bottom so the line isn't vertically stretched.
  row.upgrade = Label:new{
    parent = frame, fontInfo = theme.fonts.bodySmall,
    justifyH = ui.justify.Left, wordWrap = false,
    position = {
      TopLeft  = {row.name, BottomLeft, 0, -2},
      TopRight = {row.name, BottomRight, GEAR_EXTRAS_W, -2},
    },
  }

  self._gearRows[i] = row
  return row
end

-- Populate a visible gear row for an equipped item. `slotKey` selects the slot icon.
-- Returns the row's content height (taller when a suggested-upgrade sub-line shows).
---@return number
function DetailView:_showGear(i, item, slotKey)
  local row = self:_gearRow(i)
  -- Slot art from Warbandeer's gear atlas (one cell per slot, all slots covered).
  local spec = ns.gearSlotIcon[slotKey]
  row.icon:Texture(spec.path)
  row.icon:Coords(unpack(spec.coords))
  row.icon:Show()
  row.frame._itemLink = item.link
  row.name:Text(item.name or ""):Color(rarityColor(item.link))
  local ilvl = item.ilvl or 0
  row.ilvl:Text(tostring(ilvl)):Color(ns.IlvlColorObj(ilvl))
  if item.track and item.trackLevel and item.trackLevel > 0 then
    row.track:Text(item.track:sub(1, 1) .. item.trackLevel)
  else
    row.track:Text("")
  end

  -- Suggested upgrade for this slot, on a smaller line beneath the item name,
  -- mirroring the tooltip: the item link's own appearance ([Name] in rarity colour)
  -- + the ilvl gain (tinted green held / gold warband-bank) + "@ lvl N" in red when
  -- the item needs a level this character hasn't reached yet. The link is stashed on
  -- the frame so the hover tooltip can show it beside the equipped item.
  local upLink, upGain, upWarband = ns.UpgradeSuggestion(self._char.name, slotKey)
  row.frame._upgradeLink = upLink
  local h = GEAR_ROW_H
  if upLink then
    local text = upLink .. ("  +%d ilvl"):format(upGain or 0)
    local req = reqLevel(upLink)
    if req and req > (self._char.basic.level or 0) then
      text = text .. ("  |cffff4040@ lvl %d|r"):format(req)
    end
    row.upgrade:Text(text):Color(upWarband and theme.colors.gold or theme.colors.green)
    row.upgrade:Show()
    h = h + GEAR_UP_H
  else
    row.upgrade:Text(""):Hide()  -- clear so a pooled row's stale width doesn't skew autosize
  end
  row.frame:Height(h)
  row.frame:Show()
  return h
end

-- ─── Filter (character picker) ──────────────────────────────────────────────

local function sortedCharacters()
  local toons = {}
  for _, t in ipairs(ns.api.GetAllCharacters()) do insert(toons, t) end
  table.sort(toons, function(a, b) return a.name < b.name end)
  return toons
end

-- Titlebar character picker (shown only while the Detail view is active).
---@param parent Frame
---@return Frame
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
  local h = self.heading:Text(char.name)
  ---@cast h Label
  h:Color(color)
  local raceList = char.isAlliance and ns.api.ALLIANCE_RACES or ns.api.HORDE_RACES
  self.subtitle:Text((raceList[char.raceIdx] or char.race) .. " " .. char.className)
  self.realm:Text(char.realm)

  local ilvl = (char.equipment and char.equipment.ilvl) or 0
  self.ilvlCard:Amount(string.format("%.1f", ilvl), ns.IlvlColorObj(ilvl))
  local hrs = (char.playtime and char.playtime.total and math.floor(char.playtime.total / 3600)) or 0
  self.playCard:Amount(BreakUpLargeNumbers(hrs) .. " hrs", c.text)

  -- The two flexible slots plus Fishing/Cooking, so a main cook/fisher can be set too.
  -- Each panel re-anchors beneath the previous block (panel + its gear list), so the
  -- running Y below tracks the left column's content height for sizing.
  local profs = char.basic.professions or {}
  local i = 0
  local anchor = self.profHeader
  local pendingGap = 8                            -- gap above the next panel
  local profsBottomY = PROF_HEADER_Y + self.profHeader:Height()
  for _, slot in ipairs({ "primary", "secondary", "fishing", "cooking" }) do
    local p = profs[slot]
    if p and p.skillID then
      i = i + 1
      self:_showProf(i, p, anchor, pendingGap)
      profsBottomY = profsBottomY + pendingGap + ROW_H
      -- The gear list hangs below the panel; fold its height into the next gap so
      -- the following panel stays left-aligned with this one yet clears the rows.
      local g = self._profRows[i]._numGearRows
      local gearExtent = g > 0 and (PG_TOP_GAP + g * PG_ROW_H) or 0
      profsBottomY = profsBottomY + gearExtent
      anchor = self._profRows[i].panel
      pendingGap = ROW_GAP + gearExtent
    end
  end
  self.profHeader:Text(i == 0 and "NO PROFESSIONS" or "PROFESSIONS")
  for j = i + 1, self._numRows do
    self._profRows[j].panel:Hide()  -- hiding the panel cascades to its gear sub-rows
  end
  self._numRows = i

  -- Gear list (right column): one row per equipped slot, in slot order. The name
  -- column autosizes to the longest equipped item name (clamped to a min/max).
  local slots = (char.equipment and char.equipment.slots) or {}
  local g, maxNameW, gearRowsH = 0, 0, 0
  for _, slotKey in ipairs(ns.gearSlots) do
    local item = slots[slotKey]
    if item then
      g = g + 1
      gearRowsH = gearRowsH + self:_showGear(g, item, slotKey)
      local w = self._gearRows[g].name:StringWidth()
      if w > maxNameW then maxNameW = w end
      -- The upgrade sub-line starts under the name but may run into the ilvl/track
      -- columns; widen the name column so it isn't truncated.
      local uw = self._gearRows[g].upgrade:StringWidth() - GEAR_EXTRAS_W
      if uw > maxNameW then maxNameW = uw end
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

  -- Left column height (identity + stats + professions, including each profession's
  -- gear list). `profsBottomY` accumulated the content bottom while laying out rows.
  local leftH = profsBottomY + P

  -- Right column height (gear panel).
  local gearH = GEAR_PAD + self.gearHeader:Height()
  if g > 0 then gearH = gearH + GEAR_HEADER_GAP + gearRowsH end
  gearH = gearH + GEAR_PAD
  self.gearPanel:Height(gearH)
  local rightH = CONTENT_TOP + gearH + P

  self:Width(GEAR_X + gearPanelW(nameW) + P)
  self:Height(math.max(leftH, rightH))
end

function DetailView:update() end
