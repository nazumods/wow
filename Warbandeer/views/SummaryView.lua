local _, ns = ...
local ui = ns.ui
local insert, filter = table.insert, ns.lua.lists.filter
local alpha = ns.Colors.alpha
local Class, TableFrame, Texture, Button = ns.lua.Class, ui.TableFrame, ui.Texture, ui.Button

local ClassSummary = Class(TableFrame, function(self)
  ns.SummaryColumnsDelayed(self)

  self.data = {}
  local n = 1
  local toons = self:GetCharacters()
  for _,t in pairs(toons) do
    insert(self.data, self:GetRowData(t))
    if t.basic.level == ns.wow.maxLevel then n = n + 1 end
  end
  self:update()

  -- swap the striped row backdrops for a 1px top border in the same darker tone
  local rowBorder = {255, 255, 255, 0.05}
  for i, row in ipairs(self.rows) do
    if toons[i].basic.level < ns.wow.maxLevel then
      row:backdropColor(0, 0, 0, 0.1)
    end
    Texture:new{
      parent = row,
      layer = ui.layer.Overlay,
      position = {
        TopLeft = {row, ui.edge.TopLeft, 0, 0},
        TopRight = {row, ui.edge.TopRight, 0, 0},
        Height = 1,
      },
      color = rowBorder,
    }
  end

  self:setFooter(self:GetFooterData(toons))
end, {
  isAlliance = true,
  colInfo = ns.lua.lists.map(ns.SummaryColumns, function(c) return c.colInfo end),
  backdrop = {color = ns.Colors.TransparentBlack},
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

-- per-column footer cell data, keyed by column index (columns without a
-- getFooter are left absent so they render no footer cell)
function ClassSummary:GetFooterData(toons)
  local footer = {}
  for i,c in ipairs(ns.SummaryColumns) do
    if c.getFooter then footer[i] = c.getFooter(toons) end
  end
  return footer
end

function ClassSummary:OnBeforeShow()
  self.data = {}
  local toons = self:GetCharacters()
  for i,t in ipairs(toons) do
    self.data[i] = self:GetRowData(t)
  end
  self:update()
  self:setFooter(self:GetFooterData(toons))
end

local SummaryView = Class(ui.Frame, function(self)
  -- default to the current character's faction on first open
  local current = ns.api:GetCharacterData()
  self._showAlliance = not current or current.isAlliance
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
  name   = "summary",
  _title = "Summary",
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
  if ns.MainWindow then ns.MainWindow:Fit() end
end

function SummaryView:BuildFilter(parent)
  local box = ui.Frame:new{
    parent = parent,
    position = {
      Height = 20,
      Width = 20,
    },
  }
  local b = Button:new{
    parent = box,
    position = {
      Left = {0, 0},
      Size = {20, 20},
    },
    glow = false,
    OnClick = function() self:toggleFaction() end,
  }
  b.icon = Texture:new{
    parent = b,
    layer = ui.layer.Artwork,
    atlas = "tokens-changeFaction-small",
    position = { All = true },
  }
  -- dimmed at rest, full opacity on hover
  b:Alpha(0.8)
  b.OnEnter = function(self) self:Alpha(1) end
  b.OnLeave = function(self) self:Alpha(0.8) end
  self._filter = box
  return box
end

function SummaryView:OnBeforeShow()
  ns.api:RefreshCurrentCharacterField("weeklies", "keystone")
  ns.api:RefreshCurrentCharacterField("weeklies", "dungeons")
  ns.api:RefreshCurrentCharacterField("weeklies", "vault")
  ns.api:RefreshCurrentCharacterField("weeklies", "hasUnclaimedVault")
  self.alliance:OnBeforeShow()
  self.horde:OnBeforeShow()
end
