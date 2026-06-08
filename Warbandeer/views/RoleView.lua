local _, ns = ...
local max = math.max
local ui = ns.ui

local insert = table.insert
local Class, Frame, TableFrame, Texture = ns.lua.Class, ui.Frame, ui.TableFrame, ui.Texture
local Colors = ns.Colors
local theme = ns.theme

local TransparentBackdrop = {color = Colors.TransparentBlack}

-- Faction crests normalized to a common 16px width (the shared Colors.Strings.Icons
-- render Alliance at 16 but Horde at 19, so names in a column wouldn't line up across
-- factions). HeaderSpacer is a same-width transparent inline texture so the spec
-- header text lines up with the names below it (which are pushed right by the crest).
local AllianceIcon = "|TInterface\\TargetingFrame\\UI-PVP-ALLIANCE:16:16:0:0:64:64:0:32:0:38|t"
local HordeIcon    = "|TInterface\\TargetingFrame\\UI-PVP-HORDE:16:16:0:0:64:64:0:38:0:36|t"
local HeaderSpacer = "|T:16:16:0:0|t "

-- Per-character name cell: faction crest + name, with a hover highlight and
-- click-through to the Detail view (mirrors GearView/SummaryView). Each name is
-- its own cell (a spec column stacks one toon per row), so the highlight + click
-- target the individual character rather than the whole row.
local function nameCell(toon)
  return {
    text = (toon.isAlliance and AllianceIcon or HordeIcon) .. " " .. toon.name,
    onEnter = function(cell)
      if not cell._hl then
        cell._hl = Texture:new{
          parent = cell,
          layer = ui.layer.Background,
          position = { All = true },
          color = theme.colors.hover,
        }
      else
        cell._hl:Show()
      end
    end,
    onLeave = function(cell)
      if cell._hl then cell._hl:Hide() end
    end,
    onClick = function()
      local w = ns.MainWindow
      if w then
        w.views.detail:Select(toon)
        w:view("detail")
      end
    end,
  }
end

local ClassTable = Class(TableFrame, function(self)
  Texture:new{
    parent = self,
    position = {
      TopLeft = {self, ui.edge.TopLeft, -2, 2},
      TopRight = {self, ui.edge.TopRight, 2, 0},
    },
    color = Colors[self.classKey],
  }

  self.offsetX = self.headerWidth
  self.offsetY = self.headerHeight
  self.rowArea:TopLeft(0, -self.offsetY)

  self:addRow({
    name = self.className,
    backdrop = TransparentBackdrop,
    color = Colors[self.classKey],
  })
  local specIdx = {}
  for i,spec in ipairs(self.specs) do
    specIdx[spec] = i
    self:addCol({
      name = HeaderSpacer .. spec,
      width = 105,
      justifyH = ui.justify.Left,
      color = theme.colors.muted,
      backdrop = TransparentBackdrop,
    })
  end
  self:Width(#self.specs * 105 + self.headerWidth)

  self.data = {}
  local counts = {}
  local toons = ns.api.GetAllCharacters()
  for _,t in pairs(toons) do
    if t.classKey == self.classKey and t.basic and t.basic.specialization then
      local spec = t.basic.specialization.primary or t.basic.specialization.active
      local idx = specIdx[spec]
      if idx then
        counts[idx] = (counts[idx] or 0) + 1
        if counts[idx] > #self.data then
          self:addRow({ backdrop = TransparentBackdrop })
          insert(self.data, {})
        end
        self.data[counts[idx]][idx] = nameCell(t)
      end
    end
  end
  self:update()
end)

local Classes = {"Priest", "Rogue", "Warrior", "Hunter", "Monk", "Evoker", "Paladin", "DeathKnight", "Mage", "Shaman", "Warlock", "DemonHunter", "Druid"}
local RoleView = Class(Frame, function(self)
  local widthMax = 20
  local width = 20
  local height = 20
  local last = nil
  local offsetY = -10
  local n = 1
  local rh = 0 -- max row height
  for _,c in ipairs(Classes) do
    if n > 3 then
      n = 1
      offsetY = offsetY - rh - 20
      height = height + rh + 20
      widthMax = max(widthMax, width)
      width = 20
      rh = 0
      last = nil
    end
    self[c] = self:table(c, last and {last, ui.edge.TopRight, 20, 0} or {10, offsetY})
    width = width + self[c]:Width() + 20
    rh = max(rh, self[c]:Height())
    last = self[c]
    n = n + 1
  end
  widthMax = max(widthMax, width)
  height = height + rh

  self:Width(widthMax)
  self:Height(height)
end, {
  name = "roles",
  _title = "Roles",
})
RoleView.name = "roles"
ns.views.RoleView = RoleView

function RoleView:table(classKey, pos)
  return ClassTable:new{
    parent = self,
    position = {
      TopLeft = pos,
    },
    headerWidth = 110,
    className = ns.wow.ClassByKey[classKey],
    classKey = classKey,
    specs = ns.wow.Specializations[classKey],
  }
end
