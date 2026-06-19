---@class Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local theme = ns.theme
local select = select
local insert, sort = table.insert, table.sort
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
local ROW_HEAD_H = 18      -- headline line (item + ilvl gain)
local ROW_SUB_H = 13       -- source sub-line (smaller font)
local ROW_H = ROW_HEAD_H + ROW_SUB_H  -- one suggestion row spans two lines
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

-- A row's headline (top line): the item's own [Name] (rarity-coloured) + the ilvl
-- gain, tinted by source — green held in the character's own bags/bank, gold from the
-- warband bank, orange a world-quest reward, cyan a vendor purchase — with the item's
-- icon inline.  Where the upgrade comes from is spelled out on the sub-line below.
---@param r table an upgrade result of any source (carries link + ilvlGain)
---@param gainColor number[] theme colour for the "+N ilvl" gain
local function headline(r, gainColor)
  return ("%s%s  |cff%s+%d ilvl|r"):format(iconTex(r.link), r.link, hex(gainColor), r.ilvlGain)
end

-- The smaller sub-line: what to do / where the upgrade comes from.  Rendered muted in
-- its own (bodySmall) Label, so the full text has the row's width instead of sharing
-- the headline and truncating.
--   ready  → the slot it fills ("Main Hand")
--   WQ     → "WQ: <title> — <zone>" (go do this quest)
--   vendor → "Buy: <quartermaster> (<zone>) — <cost>" (go buy this piece)
---@param r UpgradeResult
local function readySub(r) return prettySlot(r.slot) end
---@param r WorldQuestUpgrade
local function wqSub(r)
  return r.zone and ("WQ: %s — %s"):format(r.title, r.zone) or ("WQ: %s"):format(r.title)
end
---@param r VendorUpgrade
local function vendorSub(r)
  local where = r.zone and ("%s (%s)"):format(r.quartermaster, r.zone) or r.quartermaster
  return ("Buy: %s — %s"):format(where, r.cost)
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

-- Grab (or lazily create) a pooled suggestion row: a hover-highlighting frame with a
-- headline label (item + ilvl gain) and a smaller sub-line beneath it (the slot / the
-- quest / the vendor).  Carries the equipped item (`_itemLink`) and the suggested
-- upgrade (`_compareLink`) so the shared item tooltip lays the upgrade beside the
-- equipped piece (or shows the upgrade alone when the slot is empty).  World-quest and
-- vendor rows also carry `_mapID` (WQ rows a `_questID` too): clicking opens the world
-- map to the quest / quartermaster's zone, and super-tracks the quest when there is one.
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
  -- World-quest / vendor rows open the map to the quest / quartermaster (and
  -- super-track the quest) on click; ready upgrades carry no _mapID and instead
  -- flash the held item across the open bags / bank (the upgrade link is _compareLink
  -- for an equipped slot, else _itemLink when the slot is empty).
  frame:SetScript("OnMouseUp", function(_, button)
    if button ~= "LeftButton" then return end
    if frame._mapID then
      if OpenWorldMap then OpenWorldMap(frame._mapID) end
      -- OpenWorldMap defaults the canvas to the player's *current* zone, so a WQ in a
      -- different zone wouldn't show — force the quest's zone once the frame is up.
      if WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(frame._mapID) end
      if frame._questID and SetSuperTrackedQuestID then SetSuperTrackedQuestID(frame._questID) end
    else
      ns.FlashItem(frame._compareLink or frame._itemLink)
    end
  end)

  -- Headline (item + ilvl gain) on the top band; source detail on a smaller muted
  -- line beneath, each spanning the row's full width so neither truncates the other.
  row.label = Label:new{
    parent = frame, fontInfo = theme.fonts.body,
    justifyH = ui.justify.Left, wordWrap = false,
    position = {
      TopLeft = {frame, ui.edge.TopLeft, 0, 0},
      Right   = {frame, ui.edge.Right, 0, 0}, Height = ROW_HEAD_H,
    },
  }
  row.sub = Label:new{
    parent = frame, fontInfo = theme.fonts.bodySmall, color = c.muted,
    justifyH = ui.justify.Left, wordWrap = false,
    position = {
      TopLeft = {row.label, ui.edge.BottomLeft, 0, 0},
      Right   = {frame, ui.edge.Right, 0, 0}, Height = ROW_SUB_H,
    },
  }

  self._rows[i] = row
  return row
end

-- Fill the box for `char` and return its content height (0 when the upgrade addon
-- is absent — the box hides and reserves no space).  Gathers upgrade candidates from
-- every source — ready gear the character owns (held green / warband gold), active
-- world-quest rewards (orange), buyable faction-quartermaster gear (cyan) — keeps the
-- single biggest upgrade per slot, and orders them by ilvl gain so the most impactful
-- action leads regardless of source (no point doing a world quest or pulling from the
-- bank when a vendor sells a better piece).  Lists at most MAX_ROWS rows, or the empty
-- state when there are none.  Caller sets the box width before calling.
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
  -- Populate one row from a candidate (its headline + sub-line already rendered),
  -- wiring the hover comparison (upgrade beside the equipped piece, or the upgrade
  -- alone for an empty slot).  Returns false once the row cap is hit.
  local function addRow(c)
    n = n + 1
    local row = self:_row(n)
    row.frame:Width(innerW)
    local eq = slots[c.slot] and slots[c.slot].link
    if eq then
      row.frame._itemLink, row.frame._compareLink = eq, c.link
    else
      row.frame._itemLink, row.frame._compareLink = c.link, nil
    end
    -- nil for ready upgrades; a WorldQuest/Vendor candidate carries _mapID → clickable.
    row.frame._questID, row.frame._mapID = c.questID, c.mapID
    row.label:Text(c.text)
    row.sub:Text(c.sub)
    row.frame:Show()
    return n < MAX_ROWS
  end

  -- Collect candidates from every source, each tagged with its upgrade size (the
  -- priority) and a source rank used only to break ties — at equal gain prefer the
  -- cheapest action: gear already owned (held/warband) > a world quest > a vendor buy.
  -- Items the character can't equip yet (required level too high) are dropped here.
  -- `head`/`sub` render the row's two lines (headline + source detail).
  local cands = {}
  local function collect(list, head, sub, srcRank)
    for _, r in ipairs(list) do
      local req = reqLevel(r.link)
      if not (req and req > level) then
        insert(cands, { slot = r.slot, gain = r.ilvlGain, link = r.link,
          text = head(r), sub = sub(r), srcRank = srcRank, questID = r.questID, mapID = r.mapID })
      end
    end
  end
  collect(api:CharacterUpgrades(char.name),
    function(r)
      local wb = (r.where == "warband" or r.betterElsewhere) or false
      return headline(r, wb and theme.colors.gold or theme.colors.green)
    end, readySub, 0)
  -- World-quest + vendor sources degrade to nothing on an older ShadowsOfUI-Upgrade.
  if api.WorldQuestUpgrades then
    collect(api:WorldQuestUpgrades(char.name),
      function(r) return headline(r, theme.colors.orange) end, wqSub, 1)
  end
  if api.VendorUpgrades then
    collect(api:VendorUpgrades(char.name),
      function(r) return headline(r, theme.colors.cyan) end, vendorSub, 2)
  end

  -- One row per slot: keep the biggest upgrade for each (a better vendor piece
  -- replaces a smaller bank/world-quest one rather than both showing), then order the
  -- slots by gain so the most impactful action leads.
  local bySlot = {}
  for _, c in ipairs(cands) do
    local cur = bySlot[c.slot]
    if not cur or c.gain > cur.gain or (c.gain == cur.gain and c.srcRank < cur.srcRank) then
      bySlot[c.slot] = c
    end
  end
  local ranked = {}
  for _, c in pairs(bySlot) do insert(ranked, c) end
  sort(ranked, function(a, b)
    if a.gain ~= b.gain then return a.gain > b.gain end
    return a.srcRank < b.srcRank
  end)

  for _, c in ipairs(ranked) do
    if not addRow(c) then break end
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
