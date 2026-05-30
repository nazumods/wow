local _, ns = ...
local ui = ns.ui
local insert, filter = table.insert, ns.lua.lists.filter
local alpha = ns.Colors.alpha
local Class, TableFrame, Texture, Label, Button = ns.lua.Class, ui.TableFrame, ui.Texture, ui.Label, ui.Button

local ClassSummary = Class(TableFrame, function(self)
  ns.SummaryColumnsDelayed(self)

  self.data = {}
  local n = 1
  local bags = 0
  local reagent = 0
  local toons = self:GetCharacters()
  for _,t in pairs(toons) do
    insert(self.data, self:GetRowData(t))
    if t.basic.level == ns.wow.maxLevel then n = n + 1 end
    if t.items and t.items.reagentBag and t.items.reagentBag.slots < 36 then
      reagent = reagent + 1
    end
    if t.items and t.items.bags then
      for i = 1, #t.items.bags-1 do -- skip reagent bag
        if t.items.bags[i].slots < 34 then
          bags = bags + 1
        end
      end
    end
  end
  self:update()

  local halfWhite = alpha(WHITE_FONT_COLOR, 0.5)
  local divider = Texture:new{
    parent = self,
    position = {
      TopLeft = {self.rows[n], ui.edge.TopLeft, -20, 0},
      TopRight = {self.cells[n][3], ui.edge.TopRight, 0, -1},
      Height = 1,
    },
    color = alpha(WHITE_FONT_COLOR, 0.5),
  }
  -- bump the first sub-max row down 1px to clear the divider
  if n > 1 and self.rows[n] then
    self.rows[n]:TopLeft(self.rows[n - 1], ui.edge.BottomLeft, 0, -1)
    self:Height(self:Height() + 1)
  end
  local counter = Label:new{
    parent = self,
    position = {
      BottomRight = {divider, ui.edge.TopLeft, 15, 1},
    },
    text = n - 1,
    color = alpha(WHITE_FONT_COLOR, 0.5),
  }
  local subCounter = Label:new{
    parent = self,
    position = {
      TopRight = {divider, ui.edge.BottomLeft, 15, -1},
    },
    text = #toons - n,
    color = alpha(WHITE_FONT_COLOR, 0.5),
  }

  -- missing bag count
  local bagsLine = Texture:new{
    parent = self,
    position = {
      TopLeft = {self.cols[7], ui.edge.Bottom, 0, 0},
      Width = 1,
      Height = 10,
    },
    color = halfWhite,
  }
  Label:new{
    parent = self,
    position = {
      TopRight = {bagsLine, ui.edge.TopLeft, -1, -1},
    },
    color = halfWhite,
    text = bags,
  }
  Label:new{
    parent = self,
    position = {
      TopLeft = {bagsLine, ui.edge.TopRight, 1, -1},
    },
    color = halfWhite,
    text = reagent,
  }
end, {
  isAlliance = true,
  colInfo = ns.lua.lists.map(ns.SummaryColumns, function(c) return c.colInfo end),
})

function ClassSummary:GetCharacters()
  local toons = ns.api.GetAllCharacters() -- returns a copy
  toons = filter(toons, function(t)
    return t.isAlliance == self.isAlliance
  end)
  -- sort by level, then ilvl, then name
  table.sort(toons, function(c1, c2)
    if c1.basic.level ~= c2.basic.level then return c1.basic.level > c2.basic.level end
    if c1.equipment.ilvl ~= c2.equipment.ilvl then return c1.equipment.ilvl > c2.equipment.ilvl end
    return c1.name < c2.name
  end)
  return toons
end

function ClassSummary:GetRowData(toon)
  return ns.lua.lists.map(ns.SummaryColumns, function(c) return c.getData(toon) end)
end

function ClassSummary:OnBeforeShow()
  for i,t in pairs(self:GetCharacters()) do
    self.data[i] = self:GetRowData(t)
  end
  self:update()
end

local SummaryView = Class(ui.Frame, function(self)
  self.alliance = ClassSummary:new{
    parent = self,
    position = {
      TopLeft = {2, 0},
    },
  }
  self.horde = ClassSummary:new{
    parent = self,
    position = {
      TopLeft = {2, 0},
    },
    isAlliance = false,
  }

  self:layout()
end, {
  name = "summary",
  _title = "Summary",
  _showAlliance = true,
  _showHorde = false,
})
SummaryView.name = "summary"
ns.views.SummaryView = SummaryView

function SummaryView:layout()
  local a = self._showAlliance
  self.alliance:SetShown(a)
  self.horde:SetShown(not a)

  if a then
    self:Width(self.alliance:Width() + 4)
    self:Height(self.alliance:Height() + 2)
  else
    self:Width(self.horde:Width() + 4)
    self:Height(self.horde:Height() + 2)
  end
end

function SummaryView:toggleFaction()
  self._showAlliance = not self._showAlliance
  self._showHorde = not self._showAlliance
  self:layout()
  self:refreshFilterButtons()
  if ns.MainWindow then ns.MainWindow:Fit() end
end

function SummaryView:refreshFilterButtons()
  if not self._filter then return end
  self._filter.alliance:Alpha(self._showAlliance and 1 or 0.3)
  self._filter.horde:Alpha(self._showHorde and 1 or 0.3)
end

function SummaryView:BuildFilter(parent)
  local box = ui.Frame:new{
    parent = parent,
    position = {
      Height = 20,
      Width = 44,
    },
  }
  local function btn(iconPath, isAlliance, position)
    local b = Button:new{
      parent = box,
      position = position,
      glow = false,
      OnClick = function() self:toggleFaction() end,
    }
    b.icon = Texture:new{
      parent = b,
      layer = ui.layer.Artwork,
      path = iconPath,
      position = { All = true },
    }
    return b
  end
  box.alliance = btn(ns.icons.Alliance, true, {
    Left = {0, 0},
    Size = {20, 20},
  })
  box.horde = btn(ns.icons.Horde, false, {
    Left = {box.alliance, ui.edge.Right, 4, 0},
    Size = {20, 20},
  })
  self._filter = box
  self:refreshFilterButtons()
  return box
end

function SummaryView:OnBeforeShow()
  ns.api:RefreshCurrentCharacterField("weeklies", "keystone")
  ns.api:RefreshCurrentCharacterField("weeklies", "dungeons")
  self.alliance:OnBeforeShow()
  self.horde:OnBeforeShow()
end
