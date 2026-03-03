local _, ns = ...
local ui = ns.ui
local Class, find, any = ns.lua.Class, ns.lua.lists.find, ns.lua.maps.any
local CleanFrame, Label, TableFrame = ui.CleanFrame, ui.Label, ui.TableFrame
local getParts = C_TransmogSets.GetSetPrimaryAppearances
local RequestLoadItemData = C_Item.RequestLoadItemDataByID
local GetItemInfo = C_Item.GetItemInfo

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

  self.items = TableFrame:new{
    parent = self,
    position = {
      TopLeft = {self.name, ui.edge.BottomLeft, 0, -2},
      BottomRight = {self, ui.edge.BottomRight, -2, 2},
    },
    headerHeight = 0,
    headerWidth = 60,
    rowInfo = {
      { name = "Head", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Shoulder", backdrop = {color = ns.Colors.TransparentBlack} },
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
    data = {{""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}},
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
ns.InfoTip = InfoTip

local _tooltip = nil

ui.ShowInfoTip = function(group, set, parent, position)
  if not _tooltip then
    _tooltip = InfoTip:new{
      position = false,
    }
  end
  if not ns.db.sets[group.id] or not ns.db.sets[group.id][set.id] then
    _tooltip:Hide()
    return
  end
  local data = ns.db.sets[group.id][set.id]

  _tooltip.name:Text(set.name)

  local parts = getParts(set.id)
  local primary = {}
  for _,p in ipairs(parts) do primary[p.appearanceID] = true end

  for i,slot in ipairs({1,3,5,6,7,8,9,10}) do
    local sources = C_TransmogSets.GetSourcesForSlot(set.id, slot)
    local isCollected = any(sources, function(s) return s.isCollected end)
    local _, p = find(sources, function(s) return primary[s.sourceID] end)
    _tooltip.items.data[i][1] = p and {
      text = p.name,
      color = isCollected and { 0, 104/255, 55/255} or {165/255, 0, 38/255},
     } or ""
  end
  _tooltip.items:update()
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
    4 + _tooltip.items.headerWidth + w
  ))
end

-- function ns:ITEM_DATA_LOAD_RESULT()
--   if not self.requests then return end
--   self.requests = self.requests - 1
--   if self.requests == 0 then
--   end
-- end
-- ns:registerEvent("ITEM_DATA_LOAD_RESULT")

ui.HideInfoTip = function()
  if _tooltip then
    _tooltip:Hide()
  end
end
