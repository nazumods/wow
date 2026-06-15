---@class Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local theme = ns.theme
local select = select
local GetItemInfo = C_Item.GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon
local OpenWorldMap = C_Map and C_Map.OpenWorldMap
local SetSuperTrackedQuestID = C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID

-- Suggested box: a priority-ordered to-do list of the cheapest, highest-value
-- gear actions a character can take *right now* — ready upgrades it already owns
-- (held in bags / personal bank) or can pull from the warband bank, computed by
-- ShadowsOfUI-Upgrade (OptionalDep, via ShadowsOfUI_UpgradeApi).  Each row is one
-- actionable line (icon + item + ilvl gain + slot); hovering compares the upgrade
-- against the equipped piece.  Items the character can't equip yet (required level
-- above its own) are excluded — this is "what to do immediately", not a wishlist.
-- Degrades to a hidden, zero-height box when the upgrade addon isn't loaded.

local PAD = 12             -- panel inner padding (matches the gear panel)
local HEADER_GAP = 8       -- header → first row
local ROW_H = 20           -- one suggestion row
local MAX_ROWS = 5         -- cap; the rest are implied by the gear list's ▲ marks

-- |cff hex for an embedded colour escape from a {r,g,b} (0–1) theme colour.
local function hex(c)
  return ("%02x%02x%02x"):format(
    math.floor((c[1] or 1) * 255 + 0.5),
    math.floor((c[2] or 1) * 255 + 0.5),
    math.floor((c[3] or 1) * 255 + 0.5))
end

-- Human-friendly slot name: "MainHand" → "Main Hand", "Finger1" → "Finger 1".
local function prettySlot(s)
  return (s:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2"))
end

-- Required character level of an item link (5th GetItemInfo return), or nil when
-- the item isn't cached on this client (an alt's warband gear may not be).
local function reqLevel(link) return link and select(5, GetItemInfo(link)) or nil end

-- The item's icon as an inline texture escape, or "" when unavailable.
local function iconTex(link)
  local icon = GetItemIcon and GetItemIcon(link)
  return icon and ("|T%d:0|t "):format(icon) or ""
end

-- One ready-upgrade row's label: the item's own [Name] (rarity-coloured) + the ilvl
-- gain (green when held in the character's own bags/bank, gold when it lives in the
-- warband bank) + the slot, with the item's icon inline.
---@param r UpgradeResult
---@param warband boolean
local function lineText(r, warband)
  local gainHex = hex(warband and theme.colors.gold or theme.colors.green)
  local mutedHex = hex(theme.colors.muted)
  return ("%s%s  |cff%s+%d ilvl|r  |cff%s%s|r"):format(
    iconTex(r.link), r.link, gainHex, r.ilvlGain, mutedHex, prettySlot(r.slot))
end

-- One world-quest row's label: the reward [Name] + ilvl gain in orange (a future
-- action, distinct from the green/gold ready upgrades) + the source quest, so it
-- reads "this WQ reward would upgrade you — go do it".
---@param r WorldQuestUpgrade
local function wqLineText(r)
  local gainHex = hex(theme.colors.orange)
  local mutedHex = hex(theme.colors.muted)
  local where = r.zone and ("%s — %s"):format(r.title, r.zone) or r.title
  return ("%s%s  |cff%s+%d ilvl|r  |cff%sWQ: %s|r"):format(
    iconTex(r.link), r.link, gainHex, r.ilvlGain, mutedHex, where)
end

-- One vendor row's label: the piece [Name] + ilvl gain in cyan (a purchase action,
-- distinct from the held/warband/WQ sources) + "Buy from <quartermaster> — <cost>",
-- so it reads "this quartermaster sells an upgrade — go buy it".
---@param r VendorUpgrade
local function vendorLineText(r)
  local gainHex = hex(theme.colors.cyan)
  local mutedHex = hex(theme.colors.muted)
  local where = r.zone and ("%s (%s)"):format(r.quartermaster, r.zone) or r.quartermaster
  return ("%s%s  |cff%s+%d ilvl|r  |cff%sBuy: %s — %s|r"):format(
    iconTex(r.link), r.link, gainHex, r.ilvlGain, mutedHex, where, r.cost)
end

---@class SuggestedBox: Frame
---@field _rows table[]   pooled suggestion rows
---@field _n integer       number of rows currently visible
---@field header Label
---@field empty Label
local SuggestedBox = Class(Frame, function(self)
  local c = theme.colors
  self._rows = {}
  self._n = 0

  self.header = Label:new{
    parent = self, fontInfo = theme.fonts.caps, color = c.muted,
    text = "SUGGESTED",
    position = { TopLeft = {PAD, -PAD} },
  }
  self.empty = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = c.muted,
    justifyH = ui.justify.Left, wordWrap = false,
    text = "Nothing pressing — looking good!",
    position = { TopLeft = {self.header, ui.edge.BottomLeft, 0, -HEADER_GAP} },
  }
end, {
  background = theme.colors.module,
})
ns.SuggestedBox = SuggestedBox

-- Grab (or lazily create) a pooled suggestion row: a hover-highlighting frame whose
-- label fills it, carrying the equipped item (`_itemLink`) and the suggested upgrade
-- (`_compareLink`) so the shared item tooltip lays the upgrade beside the equipped
-- piece (or shows the upgrade alone when the slot is empty).  World-quest and vendor
-- rows also carry `_mapID` (WQ rows a `_questID` too): clicking opens the world map to
-- the quest / quartermaster's zone, and super-tracks the quest when there is one.
---@return table
function SuggestedBox:_row(i)
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
    if frame._itemLink then ns.ShowItemTooltip(frame, frame._itemLink, frame._compareLink, true) end
  end)
  frame:SetScript("OnLeave", function()
    hi:Hide()
    ns.HideItemTooltip()
  end)
  -- World-quest rows open the map to the quest (and super-track it) on click; ready
  -- upgrades carry no _mapID, so a click is a no-op for them.
  frame:SetScript("OnMouseUp", function(_, button)
    if button ~= "LeftButton" or not frame._mapID then return end
    if OpenWorldMap then OpenWorldMap(frame._mapID) end
    -- OpenWorldMap defaults the canvas to the player's *current* zone, so a WQ in a
    -- different zone wouldn't show — force the quest's zone once the frame is up.
    if WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(frame._mapID) end
    if frame._questID and SetSuperTrackedQuestID then SetSuperTrackedQuestID(frame._questID) end
  end)

  row.label = Label:new{
    parent = frame, fontInfo = theme.fonts.body,
    justifyH = ui.justify.Left, wordWrap = false,
    position = { Left = {frame, ui.edge.Left, 0, 0}, Right = {frame, ui.edge.Right, 0, 0} },
  }

  self._rows[i] = row
  return row
end

-- Fill the box for `char` and return its content height (0 when the upgrade addon
-- is absent — the box hides and reserves no space).  Lists at most MAX_ROWS rows:
-- the ready upgrades the character can equip right now (priority order = ilvl gain)
-- first, then active world-quest rewards that would upgrade a slot (a future action,
-- orange) if there's room, or the empty state when there are none.  Caller sets the
-- box width before calling.
---@param char Character
---@return number height
function SuggestedBox:Populate(char)
  local api = ShadowsOfUI_UpgradeApi
  if not api then self:Hide(); return 0 end
  self:Show()

  local slots = (char.equipment and char.equipment.slots) or {}
  local level = char.basic.level or 0
  local innerW = self:Width() - 2 * PAD

  local n = 0
  -- Populate one row from an upgrade result + its rendered label, wiring the hover
  -- comparison (upgrade beside the equipped piece, or the upgrade alone for an
  -- empty slot).  Returns false once the row cap is hit.
  local function addRow(r, text)
    n = n + 1
    local row = self:_row(n)
    row.frame:Width(innerW)
    local eq = slots[r.slot] and slots[r.slot].link
    if eq then
      row.frame._itemLink, row.frame._compareLink = eq, r.link
    else
      row.frame._itemLink, row.frame._compareLink = r.link, nil
    end
    -- nil for ready upgrades; a WorldQuestUpgrade carries these → row becomes clickable.
    row.frame._questID, row.frame._mapID = r.questID, r.mapID
    row.label:Text(text)
    row.frame:Show()
    return n < MAX_ROWS
  end

  for _, r in ipairs(api:CharacterUpgrades(char.name)) do
    local req = reqLevel(r.link)
    if not (req and req > level) then  -- skip what the character can't equip yet
      if not addRow(r, lineText(r, (r.where == "warband" or r.betterElsewhere) or false)) then break end
    end
  end

  -- World-quest rewards fill any remaining rows (degrades to nothing on an older
  -- ShadowsOfUI-Upgrade without the method).
  if n < MAX_ROWS and api.WorldQuestUpgrades then
    for _, r in ipairs(api:WorldQuestUpgrades(char.name)) do
      local req = reqLevel(r.link)
      if not (req and req > level) then
        if not addRow(r, wqLineText(r)) then break end
      end
    end
  end

  -- Faction-quartermaster pieces fill any remaining rows (a buy action, cyan;
  -- degrades to nothing on an older ShadowsOfUI-Upgrade without the method).
  if n < MAX_ROWS and api.VendorUpgrades then
    for _, r in ipairs(api:VendorUpgrades(char.name)) do
      local req = reqLevel(r.link)
      if not (req and req > level) then
        if not addRow(r, vendorLineText(r)) then break end
      end
    end
  end

  for i = n + 1, self._n do self._rows[i].frame:Hide() end
  self._n = n

  local h = PAD + self.header:Height() + HEADER_GAP
  if n > 0 then
    self.empty:Hide()
    h = h + n * ROW_H
  else
    self.empty:Show()
    h = h + self.empty:Height()
  end
  h = h + PAD
  self:Height(h)
  return h
end
