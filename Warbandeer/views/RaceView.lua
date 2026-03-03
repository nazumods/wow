local _, ns = ...
local max = math.max
local ui = ns.ui
local lists = ns.lua.lists

local insert, CopyTable, Map = table.insert, CopyTable, ns.lua.maps.map
local Class, Frame, TableFrame, Texture = ns.lua.Class, ui.Frame, ui.TableFrame, ui.Texture
local Colors, alpha = ns.Colors, ns.Colors.alpha

local TransparentBackdrop = {color = Colors.TransparentBlack}

-- classes in armor type order
local Classes = {
  "Priest", "Mage", "Warlock",
  "Demon Hunter", "Druid", "Monk", "Rogue",
  "Evoker", "Hunter", "Shaman",
  "Death Knight", "Paladin", "Warrior"
}
local Races = lists.values(ns.api.ALLIANCE_RACES, ns.api.HORDE_RACES)

local RaceView = Class(TableFrame, function(self)
  -- define a row with the correct number of cells
  local emptyRow = Map(Classes, function(c) return {} end)
  -- copy it for each row
  for i=1,#Races do
    insert(self.data, CopyTable(emptyRow))
  end

  local h = self:Height()
  local toons = ns.api.GetAllCharacters()
  for _,t in pairs(toons) do
    -- raceIdx is the index into the faction race array used above,
    -- so if its horde we need to offset by the number of alliance races
    local rowIdx = t.raceIdx + (t.isAlliance and 0 or #ns.api.ALLIANCE_RACES)
    local colIdx = ns.lua.lists.find(Classes, t.className)
    if self.data[rowIdx][colIdx].text ~= nil then
      self.data[rowIdx][colIdx].text = self.data[rowIdx][colIdx].text .. "\n" .. t.name
      self.data[rowIdx][colIdx].count = self.data[rowIdx][colIdx].count + 1
      if self.data[rowIdx][colIdx].count > 1 then
        h = h + 14
      end
      local row = self.rows[rowIdx]
      row:Height(max(row:Height(), self.data[rowIdx][colIdx].count * 14 + 4))
    else
      self.data[rowIdx][colIdx] = {
        color = ns.Colors[t.classKey or t.className],
        text = t.name,
        justifyH = ui.justify.Center,
        count = 1,
      }
    end
  end

  -- add a thin line between alliance and horde races
  Texture:new{
    parent = self,
    position = {
      TopLeft = {self.rows[#ns.api.ALLIANCE_RACES], ui.edge.BottomLeft, 0, 0},
      BottomRight = {self.rows[#ns.api.ALLIANCE_RACES], ui.edge.BottomRight, 0, -1},
    },
    color = alpha(PLAYER_FACTION_COLOR_ALLIANCE, 0.5),
  }
  -- and nudge the first horde row down accordingly
  self.rows[#ns.api.ALLIANCE_RACES]:TopLeft(self.rows[#ns.api.ALLIANCE_RACES-1], ui.edge.BottomLeft, 0, 1)

  self:update()
  self:Height(h+1)
end, {
  name = "races",
  _title = "Races",
  autosize = true,
  padding = 4,
  colInfo = Map(Classes, function(c, i)
    local classKey = gsub(c, " ","")
    return {
      name = c,
      width = 105,
      backdrop = {color = alpha(Colors[classKey], 0.06)},
    }
  end),
  headerWidth = 135,
  rowInfo = Map(Races, function(r, i)
    return {
      name = r,
      color = i <= #ns.api.ALLIANCE_RACES and PLAYER_FACTION_COLOR_ALLIANCE or PLAYER_FACTION_COLOR_HORDE,
      justifyH = ui.justify.Left,
      backdrop = {color = {0,0,0,i % 2 == 0 and 0.2 or 0}},
    }
  end),
  data = {},
})
RaceView.name = "races"
ns.views.RaceView = RaceView
