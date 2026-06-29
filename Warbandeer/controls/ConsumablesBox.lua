---@class Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local theme = ns.theme
local GetItemInfo = C_Item.GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon
local RequestItem = C_Item and C_Item.RequestLoadItemDataByID

-- Consumables box: the spec's recommended raid/M+ consumables — flask, combat potion,
-- food, weapon buff, augment rune — sourced from ClassCodex via ShadowsOfUI_UpgradeApi
-- (OptionalDep), mirroring ClassCodex's own "Consumables" panel.  Each category can be
-- hidden from the Warbandeer settings (db.settings.consumables[key] = false).  Degrades to
-- a hidden, zero-height box when ShadowsOfUI-Upgrade / ClassCodex isn't loaded, the spec has
-- no consumables data, or every category is toggled off.

local PAD = 12             -- panel inner padding (matches the gear panel)
local HEADER_GAP = 8       -- header → first row
local ROW_H = 20           -- one consumable row
local CAT_W = 100          -- left category-label column ("Combat Potion" etc.)

-- The category taxonomy (order + label) ClassCodex's consumables block uses, shared with the
-- settings subcategory (consumablesSettings.lua). Keys match ClassCodex's `.consumables` fields;
-- a key the spec data omits simply renders no row.
---@type { key: string, label: string }[]
ns.ConsumableCats = {
  { key = "flask",        label = "Flask" },
  { key = "combatPotion", label = "Combat Potion" },
  { key = "food",         label = "Food" },
  { key = "weaponBuff",   label = "Weapon Buff" },
  { key = "augmentRune",  label = "Augment Rune" },
}

-- An item's display string ({icon} colored [link]) + a hyperlink for the tooltip. A cached
-- item gives a rarity-colored link straight off; an uncached one (an alt's data, a freshly
-- patched item) shows the ClassCodex name and a bare item link, and requests a load so the
-- next render colors it.
---@param itemId integer
---@param fallbackName string?
---@return string display, string link
local function itemDisplay(itemId, fallbackName)
  local icon = GetItemIcon and GetItemIcon(itemId)
  local iconStr = icon and ("|T%d:0|t "):format(icon) or ""
  local _, link = GetItemInfo(itemId)
  if link then return iconStr .. link, link end
  if RequestItem then RequestItem(itemId) end
  return iconStr .. (fallbackName or ("item:" .. itemId)), ("item:" .. itemId)
end

---@class ConsumablesBox: Frame
---@field _rows table[]   pooled consumable rows
---@field _n integer       number of rows currently visible
---@field header Label
local ConsumablesBox = Class(Frame, function(self)
  local c = theme.colors
  self._rows = {}
  self._n = 0

  self.header = Label:new{
    parent = self, fontInfo = theme.fonts.caps, color = c.muted,
    text = "CONSUMABLES",
    position = { TopLeft = {PAD, -PAD} },
  }
end, {
  background = theme.colors.module,
})
ns.ConsumablesBox = ConsumablesBox

-- Grab (or lazily create) a pooled row: a hover-highlighting frame with a muted category
-- label on the left and the item (icon + rarity-colored name) filling the rest. The current
-- item link is stashed on the frame (`_itemLink`) so the shared item tooltip can show it.
---@param i integer
---@return table
function ConsumablesBox:_row(i)
  local row = self._rows[i]
  if row then return row end

  local c = theme.colors
  local prev = self._rows[i - 1]
  local frame = Frame:new{
    parent = self,
    position = {
      TopLeft = prev and {prev.frame, ui.edge.BottomLeft, 0, 0}
                     or  {self.header, ui.edge.BottomLeft, 0, -HEADER_GAP},
      Width  = PAD,  -- resized to the panel's inner width in Populate
      Height = ROW_H,
    },
  }
  row = { frame = frame }

  local hi = Texture:new{
    parent = frame, layer = ui.layer.Background, color = c.hover,
    position = { All = true, Hide = true },
  }
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function()
    hi:Show()
    if frame._itemLink then ns.ShowItemTooltip(frame, frame._itemLink, nil, true) end
  end)
  frame:SetScript("OnLeave", function()
    hi:Hide()
    ns.HideItemTooltip()
  end)

  row.cat = Label:new{
    parent = frame, fontInfo = theme.fonts.body, color = c.muted,
    justifyH = ui.justify.Left, wordWrap = false,
    position = { Left = {frame, ui.edge.Left, 0, 0}, Width = CAT_W },
  }
  row.item = Label:new{
    parent = frame, fontInfo = theme.fonts.body,
    justifyH = ui.justify.Left, wordWrap = false,
    position = {
      Left  = {frame, ui.edge.Left, CAT_W, 0},
      Right = {frame, ui.edge.Right, 0, 0},
    },
  }

  self._rows[i] = row
  return row
end

-- Fill the box for `char` and return its content height (0 when there's nothing to show —
-- the box hides and reserves no space). Lists each enabled category ClassCodex has a pick
-- for; the caller sets the box width before calling.
---@param char Character
---@return number height
function ConsumablesBox:Populate(char)
  local api = ShadowsOfUI_UpgradeApi
  local data = api and api.RecommendedConsumables and api:RecommendedConsumables(char.name)
  if not data then self:Hide(); return 0 end

  local hidden = (ns.db.settings.consumables) or {}
  local innerW = self:Width() - 2 * PAD

  local n = 0
  for _, cat in ipairs(ns.ConsumableCats) do
    local entry = hidden[cat.key] ~= false and data[cat.key]
    local itemId = type(entry) == "table" and entry.itemId
    if itemId then
      n = n + 1
      local row = self:_row(n)
      row.frame:Width(innerW)
      local display, link = itemDisplay(itemId, entry.name)
      row.cat:Text(cat.label)
      row.item:Text(display)
      row.frame._itemLink = link
      row.frame:Show()
    end
  end

  for i = n + 1, self._n do self._rows[i].frame:Hide() end
  self._n = n

  if n == 0 then self:Hide(); return 0 end
  self:Show()
  local h = PAD + self.header:Height() + HEADER_GAP + n * ROW_H + PAD
  self:Height(h)
  return h
end
