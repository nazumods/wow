---@type Warbandeer_Collected
local ns = select(2, ...)
local ui = ns.ui
local Class, find, any = ns.lua.Class, ns.lua.lists.find, ns.lua.maps.any
local CleanFrame, Label, TableFrame = ui.CleanFrame, ui.Label, ui.TableFrame
local C_Timer = C_Timer
local getParts = C_TransmogSets.GetSetPrimaryAppearances

-- The singleton tip and the set it currently describes. _group/_set guard the
-- async name-load re-render against a stale set; _parent/_position are kept so
-- RefreshInfoTip can re-render in place after a rating change.
local _tooltip, _group, _set, _parent, _position

---Singleton tooltip listing a transmog set's pieces per armor slot, colored by collected status.
---@class InfoTip: CleanFrame
---@field name Label set name header
---@field status Label wanted/rank line (inline-colored), set per-set in render
---@field items TableFrame one row per armor slot (head..hands)
local InfoTip = Class(CleanFrame, function(self)
  local h = 4

  self.name = Label:new{
    parent = self,
    position = {
      TopLeft = {2, -2},
    },
    text = "Name",
  }
  h = h + self.name:Height()

  -- Wanted/rank line just under the name. Seeded with the shift-click hint so it
  -- reserves a line's height here; render() rewrites it per set.
  self.status = Label:new{
    parent = self,
    fontObj = "GameFontNormalSmall",
    position = {
      TopLeft = {self.name, ui.edge.BottomLeft, 0, -2},
    },
    text = "Shift-click to mark wanted",
  }
  h = h + self.status:Height() + 2

  self.items = TableFrame:new{
    parent = self,
    position = {
      TopLeft = {self.status, ui.edge.BottomLeft, 0, -2},
    },
    headerHeight = 0,
    headerWidth = 60,
    rowInfo = {
      { name = "Head", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Shoulder", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Back", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Chest", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Waist", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Legs", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Feet", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Wrist", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Hands", backdrop = {color = ns.Colors.TransparentBlack} },
    },
    colInfo = {
      { backdrop = {color = ns.Colors.TransparentBlack} }
    },
    data = {{""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}},
  }
  h = h + self.items:Height() + 2

  self:Height(h)
  self:Width(self.items:Width() + 4)
end, {
  -- defaults for inherited settings
  parent = UIParent,
  strata = "DIALOG",
  background = {0, 0, 0, 0.7},
  inset = 3,
  position = {
    TopLeft = {20, -20},
  },
})
---@class Warbandeer_Collected
---@field InfoTip InfoTip
ns.InfoTip = InfoTip

-- Item names from GetSourcesForSlot load asynchronously, so the first hover can
-- render before they're cached (blank rows). We request the items to load and
-- re-render until the names resolve, capped so a genuinely nameless source can't
-- loop forever.
local _retryTimer, _retries
local function cancelRetry()
  if _retryTimer then _retryTimer:Cancel(); _retryTimer = nil end
end

-- Build + position + show the tip for one set. _group/_set are committed here so
-- the async name-load retry can tell whether it's still rendering this set.
local function render(group, set, parent, position)
  if not _tooltip then
    _tooltip = InfoTip:new{
      position = false,
    }
  end
  _group, _set, _parent, _position = group, set, parent, position
  _tooltip.name:Text(set.name)

  -- Wanted/rank line. Inline color codes let one Label carry the gold star and a
  -- tier-colored letter; falls back to the shift-click hint when unrated.
  local race = ns:PlayerRace()
  local rank = ns:EffectiveRank(set.id, race)
  local bits = {}
  if ns:IsWanted(set.id) then bits[#bits + 1] = "|cffffd100★ Wanted|r" end
  if rank then
    local tag = ns:RaceRank(set.id, race) and ("Tier " .. rank .. " (race)") or ("Tier " .. rank)
    bits[#bits + 1] = "|cff" .. ns.RankHex(rank) .. tag .. "|r"
  end

  local parts = getParts(set.id)
  local scanned = ns.db.sets[group.id] and ns.db.sets[group.id][set.id]
  -- A PTR-only set the live client has no data for: GetSetPrimaryAppearances /
  -- GetSourcesForSlot return nothing, so there's no per-slot list to show. Mark it
  -- upcoming (ratings still apply) instead of rendering nine "missing" rows. On a
  -- PTR client the set is real, parts resolve, and the normal slot list renders.
  local upcoming = not scanned and #parts == 0
  if upcoming then bits[#bits + 1] = "|cff8cc8ffNot yet on live (PTR)|r" end
  _tooltip.status:Text(#bits > 0 and table.concat(bits, "   ") or "|cff808080Shift-click to mark wanted|r")

  local incomplete = false
  if upcoming then
    for i = 1, 9 do _tooltip.items.data[i][1] = "" end
  else
    local primary = {}
    for _,p in ipairs(parts) do primary[p.appearanceID] = true end

    local fallback   -- built lazily when a slot's per-slot source lookup is empty
    for i,slot in ipairs({1,3,15,5,6,7,8,9,10}) do
      local sources = C_TransmogSets.GetSourcesForSlot(set.id, slot)
      local _, p = find(sources, function(s) return primary[s.sourceID] end)
      local name, isCollected
      if p then
        isCollected = any(sources, function(s) return s.isCollected end)
        name = p.name
        if not name or name == "" then
          -- Name not cached yet: nudge the item to load and flag a re-render.
          incomplete = true
          local info = C_TransmogCollection.GetSourceInfo(p.sourceID)
          if info and info.itemID then C_Item.RequestLoadItemDataByID(info.itemID) end
        end
      else
        -- Per-slot API gave nothing (Trading Post / variant set): bucket the set's
        -- pieces by equip location, matching the dressing-room slots.
        fallback = fallback or ns.SetSlotPieces(set.id)
        local fb = fallback[slot]
        if fb then
          isCollected = fb.isCollected
          name = C_Item.GetItemNameByID(fb.itemID)
          if not name or name == "" then incomplete = true; C_Item.RequestLoadItemDataByID(fb.itemID) end
        end
      end
      _tooltip.items.data[i][1] = name and {
        text = name,
        color = isCollected and { 0, 104/255, 55/255} or {165/255, 0, 38/255},
       } or ""
    end
  end
  _tooltip.items:update()
  -- Clear the previous hover's anchor before re-pointing: the tip is a reused
  -- singleton, and InfoTipPosition flips between a TopLeft/TopRight cell anchor
  -- by screen side, so stacking points would anchor it to two cells at once
  -- (retail rejects that as an "anchor family connection").
  _tooltip:ClearAllPoints()
  _tooltip:Position(position)
  _tooltip:Show()
  _tooltip:Level(parent:Level() + 1)

  -- find the widest one and resize the column
  local w = 0
  for _,r in ipairs(_tooltip.items.cells) do
    w = max(w, r[1].label._widget:GetUnboundedStringWidth())
  end
  _tooltip.items.cols[1]:Width(w)
  _tooltip.items:Width(4 + _tooltip.items.headerWidth + w)

  _tooltip:Width(4 + max(
    _tooltip.name:Width(),
    _tooltip.status:Width(),
    4 + _tooltip.items.headerWidth + w
  ))

  -- Re-render shortly if any name is still loading, as long as the tip is still
  -- showing this set and we haven't exhausted our attempts.
  cancelRetry()
  if incomplete and _retries > 0 then
    _retries = _retries - 1
    _retryTimer = C_Timer.NewTimer(0.15, function()
      _retryTimer = nil
      if _group == group and _set == set and _tooltip and _tooltip._widget:IsVisible() then
        render(group, set, parent, position)
      end
    end)
  end
end

---Show the shared InfoTip for a transmog set, positioned relative to a cell.
---@class Warbandeer_Collected
---@field ShowInfoTip fun(group: table, set: table, parent: Frame, position: table) group/set are entries from ns.Sets; position is a LibNUI position spec
ns.ShowInfoTip = function(group, set, parent, position)
  cancelRetry()
  _retries = 12   -- ~1.8s of re-renders while item names load in
  render(group, set, parent, position)
end

---Hide the shared InfoTip (no-op if never shown).
---@class Warbandeer_Collected
---@field HideInfoTip fun()
ns.HideInfoTip = function()
  cancelRetry()
  if _tooltip then _tooltip:Hide() end
end

---Re-render the currently shown tip in place, so a wanted/rank change made while
---hovering (e.g. shift-click) updates the status line immediately. No-op if hidden.
---@class Warbandeer_Collected
---@field RefreshInfoTip fun()
ns.RefreshInfoTip = function()
  if _tooltip and _tooltip._widget:IsVisible() and _group and _set then
    render(_group, _set, _parent, _position)
  end
end
