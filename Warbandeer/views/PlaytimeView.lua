local _, ns = ...
local ui = ns.ui
local insert = table.insert
local Class, Frame, TableFrame = ns.lua.Class, ui.Frame, ui.TableFrame
local Left = ui.justify.Left
local RAID_CLASS_COLORS = RAID_CLASS_COLORS -- luacheck: globals RAID_CLASS_COLORS

local transpBk = {color = {0, 0, 0, 0}}

local colInfo = {
  {name = "Character", width = 105, justifyH = Left, backdrop = transpBk},
  {name = "Lvl",       width = 30,  justifyH = Left, backdrop = transpBk},
  {name = "Class",     width = 90,  justifyH = Left, backdrop = transpBk},
  {name = "Played",    width = 95,  justifyH = Left, backdrop = transpBk, padLeft = 10},
}

local function formatTime(seconds)
  if not seconds then return "" end
  local d = math.floor(seconds / 86400)
  local h = math.floor((seconds % 86400) / 3600)
  local m = math.floor((seconds % 3600) / 60)
  if d > 0 then return d.."d "..h.."h "..m.."m" end
  if h > 0 then return h.."h "..m.."m" end
  return m.."m"
end

local function getCharacters(isAlliance)
  local result = {}
  for _, t in ipairs(ns.api:GetAllCharacters()) do
    if t.isAlliance == isAlliance then
      insert(result, t)
    end
  end
  table.sort(result, function(a, b)
    local ta = a.playtime and a.playtime.total or 0
    local tb = b.playtime and b.playtime.total or 0
    return ta > tb
  end)
  return result
end

local function buildData(isAlliance)
  local data = {}
  for _, toon in ipairs(getCharacters(isAlliance)) do
    local c = toon.classKey and RAID_CLASS_COLORS[toon.classKey:upper()]
    insert(data, {
      c and c:WrapTextInColorCode(toon.name) or toon.name,
      toon.basic.level,
      toon.className or "?",
      formatTime(toon.playtime and toon.playtime.total),
    })
  end
  return data
end

local GAP = 20

local PlaytimeView = Class(Frame, function(self)
  self.alliance = TableFrame:new{
    parent     = self,
    colInfo    = colInfo,
    cellHeight = 16,
    position   = { TopLeft = {} },
  }
  self.horde = TableFrame:new{
    parent     = self,
    colInfo    = colInfo,
    cellHeight = 16,
    position   = { TopLeft = {self.alliance, ui.edge.TopRight, GAP, 0} },
  }
  self:refresh()
end, {
  name   = "playtime",
  _title = "Playtime",
})
PlaytimeView.name = "playtime"
ns.views.PlaytimeView = PlaytimeView

function PlaytimeView:refresh()
  self.alliance.data = buildData(true)
  self.alliance:update()
  self.horde.data    = buildData(false)
  self.horde:update()
  self:Width(self.alliance:Width() + GAP + self.horde:Width())
  self:Height(math.max(self.alliance:Height(), self.horde:Height()))
end

function PlaytimeView:OnBeforeShow()
  self:refresh()
end
