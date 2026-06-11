---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui

local Class, TableFrame, Texture, Button, Label =
  ns.lua.Class, ui.TableFrame, ui.Texture, ui.Button, ui.Label
local theme = ns.theme
local insert = table.insert
local Armor = ns.wow.Armor

-- Base column layout. Restyled at load (below):
-- muted, uppercased headers; the first column inset off the table edge. Columns
-- stay transparent so the void window surface shows through behind the rows.
local TRANSPARENT = { color = ns.Colors.TransparentBlack }
local BASE_COLS = {
  -- faction
  { width = 20, justifyH = ui.justify.Left, backdrop = TRANSPARENT },
  -- role
  { width = 20, justifyH = ui.justify.Left, backdrop = TRANSPARENT, padLeft = 2 },
  { name = "Character", width = 105, justifyH = ui.justify.Left, backdrop = TRANSPARENT, padLeft = 2 },
  { name = "Lvl",  width = 30, justifyH = ui.justify.Left, backdrop = TRANSPARENT },
  { name = "iLvl", width = 35, justifyH = ui.justify.Left, backdrop = TRANSPARENT },
  --
  { name = "Head", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Neck", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Shdr", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Back", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Chst", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Wrst", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Hand", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Wast", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Legs", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Feet", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Fgr1", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Fgr2", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Tnk1", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "Tnk2", width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "MH",   width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
  { name = "OH",   width = 60, justifyH = ui.justify.Center, backdrop = TRANSPARENT },
}

-- Shallow-copy each column with uppercased headers (icon-only columns have no
-- name and are unaffected; the muted header color comes from the theme). Shared
-- across all four armor tables — GearView never mutates colInfo (no
-- addCol/addRow with custom info), so a single list is safe.
local COL_INFO = ns.lua.lists.map(BASE_COLS, function(c)
  local info = {}
  for k, v in pairs(c) do info[k] = v end
  if info.name and info.name ~= "" then info.name = info.name:upper() end
  return info
end)

local getNameString = function(toon)
  local current = ns.api.GetCurrentCharacter()
  local s = toon.name
  if s == current then
    s = s.." |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14|t"
  end
  return {
    text = s,
    color = ns.Colors[toon.classKey or toon.className],
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      ui.tip:AddLine(toon.realm)
      ui.tip:AddLine(toon.specializationActive)
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

local function slotStr(slot)
  if not slot then return "" end
  local text = ns.IlvlColor(slot.ilvl)
  if slot.track and slot.trackLevel and slot.trackLevel > 0 then
    text = text .. "(" .. slot.track:sub(1,1) .. slot.trackLevel .. ")"
  end
  return { text = text, justifyH = ui.justify.Center }
end

local getILvlString = function(toon)
  local lines = {}
  if toon.equipment then
    for slot, item in pairs(toon.equipment.slots) do
      insert(lines, slot.." "..ns.IlvlColor(item.ilvl))
    end
  end
  return {
    text = toon.basic.level < ns.wow.maxLevel and (ITEM_STANDARD_COLOR:WrapTextInColorCode(toon.equipment.ilvl)) or ns.IlvlColor(toon.equipment.ilvl),
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      for _,l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

-- One TableFrame per armor type: transparent rows with a
-- 1px divider above each, still-levelling characters dimmed, row hover highlight +
-- click-to-open-Detail (mirrors SummaryView's ClassSummary).
---@class GearTable: TableFrame
---@field armorType string
local GearTable = Class(TableFrame, function(self)
  local toons = self:GetCharacters()
  self._toons = toons
  self.data = {}
  for i, t in ipairs(toons) do
    self.data[i] = self:decorateRow(self:GetRowData(t), i)
  end
  self:update()

  for i, row in ipairs(self.rows) do
    if toons[i].basic.level < ns.wow.maxLevel then
      row:backdropColor(0, 0, 0, 0.22)
    end
    Texture:new{
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
end, {
  armorType = "Cloth",
  backdrop = { color = ns.Colors.TransparentBlack },
})

---@return table
function GearTable:GetCharacters()
  local toons = ns.api.GetAllCharacters() -- returns a copy
  local filtered = {}
  for _, t in ipairs(toons) do
    if Armor.byClass[t.classKey] == self.armorType then
      insert(filtered, t)
    end
  end
  table.sort(filtered, ns.byLevelIlvl)
  return filtered
end

---@param toon table
---@return table
function GearTable:GetRowData(toon)
  -- 5 leading columns (faction, role, name, level, ilvl) then one cell per gear slot
  if not (toon.equipment and toon.equipment.slots) then
    local empty = {}
    for i = 1, 5 + #ns.gearSlots do empty[i] = "" end
    return empty
  end
  local row = {
    ns.factionIcon[toon.isAlliance],
    toon.basic.specialization and ns.icons[toon.basic.specialization.role] or "",
    getNameString(toon),
    toon.basic.level,
    getILvlString(toon),
  }
  for _, slot in ipairs(ns.gearSlots) do
    row[#row + 1] = slotStr(toon.equipment.slots[slot])
  end
  return row
end

-- Make every cell drive the row hover highlight + click-to-open-Detail, chaining
-- onto any existing cell handlers (so the per-column tooltips keep working). Each
-- cell is a shallow COPY of the source data — several cells are shared table
-- objects (e.g. ns.factionIcon[...]), so mutating in place would chain wrappers
-- across every row sharing the object. Plain string/number cells become {text=...}.
---@param cells table  the row's per-column cell data array
---@param i integer    row index
---@return table cells
function GearTable:decorateRow(cells, i)
  for n, cell in ipairs(cells) do
    local src = type(cell) == "table" and cell or {text = cell}
    local copy = {}
    for k, v in pairs(src) do copy[k] = v end
    local onEnter, onLeave, onClick = src.onEnter, src.onLeave, src.onClick
    copy.onEnter = function(s)
      local row = self.rows[i]
      if row then row:backdropColor(theme.colors.hover) end
      if onEnter then onEnter(s) end
    end
    copy.onLeave = function(s)
      local row, toon = self.rows[i], self._toons[i]
      if row then
        row:backdropColor(0, 0, 0, (toon and toon.basic.level < ns.wow.maxLevel) and 0.22 or 0)
      end
      if onLeave then onLeave(s) end
    end
    copy.onClick = function(s)
      if onClick then onClick(s) end
      local toon, w = self._toons[i], ns.MainWindow
      if toon and w then
        w.views.detail:Select(toon)
        w:view("detail")
      end
    end
    cells[n] = copy
  end
  return cells
end

function GearTable:OnBeforeShow()
  local toons = self:GetCharacters()
  self._toons = toons
  self.data = {}
  for i, t in ipairs(toons) do
    self.data[i] = self:decorateRow(self:GetRowData(t), i)
  end
  self:update()
end

-- Armor-type accent colour for the active filter button.
local ACTIVE = theme.colors.gold

---@class GearView: Frame
local GearView = Class(ui.Frame, function(self)
  -- default to the current character's armor type on first open
  local current = ns.api:GetCharacterData()
  self._armorType = (current and Armor.byClass[current.classKey]) or Armor.types[1]

  self._tables = {}
  for _, armorType in ipairs(Armor.types) do
    self._tables[armorType] = GearTable:new{
      parent = self,
      position = { TopLeft = {0, 0} },
      colInfo = COL_INFO,
      armorType = armorType,
    }
  end

  self:layout()
end, {
  name   = "gear",
  _title = "Gear",
  background = theme.colors.window,
})
GearView.name = "gear"
ns.views.GearView = GearView

function GearView:layout()
  local active
  for _, armorType in ipairs(Armor.types) do
    local shown = armorType == self._armorType
    self._tables[armorType]:SetShown(shown)
    if shown then active = self._tables[armorType] end
  end
  self:Width(active:Width())
  self:Height(active:Height())
end

function GearView:selectArmor(armorType)
  if self._armorType == armorType then return end
  self._armorType = armorType
  self:updateFilter()
  self:layout()
  if ns.MainWindow then ns.MainWindow:Fit() end
end

-- Armor-type filter: a horizontal strip of four bordered buttons (Cloth / Leather
-- / Mail / Plate), one active at a time. Replaces the old TabFrame tabs. Each
-- button is a faint-bordered box with a mono-caps label; the active one is tinted
-- gold (border + label), inactive ones muted.
function GearView:BuildFilter(parent)
  local BW, BH, GAP, PAD = 60, 20, 4, 6
  local count = #Armor.types
  local box = ui.Frame:new{
    parent = parent,
    position = { Width = count * BW + (count - 1) * GAP, Height = BH },
  }

  self._armorButtons = {}
  for i, armorType in ipairs(Armor.types) do
    local b = ui.Frame:new{
      parent = box,
      position = {
        Left = i == 1 and {0, 0} or {box, ui.edge.Left, (i - 1) * (BW + GAP), 0},
        Width = BW, Height = BH,
      },
    }
    b.border = Texture:new{
      parent = b, layer = ui.layer.Background,
      position = { All = true },
    }
    Texture:new{
      parent = b, layer = ui.layer.Border, color = {0.05, 0.05, 0.06, 0.92},
      position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
    }
    b.button = Button:new{
      parent = b,
      position = { All = true },
      glow = false,
      OnClick = function() self:selectArmor(armorType) end,
    }
    b.label = Label:new{
      parent = b.button,
      fontInfo = {theme.fonts.caps[1], 10},
      justifyH = ui.justify.Center,
      position = { Left = {PAD, 0}, Right = {-PAD, 0} },
      text = armorType:upper(),
    }
    self._armorButtons[armorType] = b
  end

  self._filter = box
  self:updateFilter()
  return box
end

-- Tint each button to reflect the active armor type (gold accent vs. muted).
function GearView:updateFilter()
  if not self._armorButtons then return end
  for _, armorType in ipairs(Armor.types) do
    local b = self._armorButtons[armorType]
    local active = armorType == self._armorType
    local col = active and ACTIVE or theme.colors.muted
    b.label:Color(col)
    local bc = active and ACTIVE or theme.colors.border
    b.border:Color(bc[1], bc[2], bc[3], active and 0.9 or 0.4)
    b.button:Alpha(active and 1 or 0.75)
  end
end

function GearView:OnBeforeShow()
  for _, armorType in ipairs(Armor.types) do
    self._tables[armorType]:OnBeforeShow()
  end
  self:layout()
end
