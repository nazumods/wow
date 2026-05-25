local _, ns = ...
local ui = ns.ui
local insert = table.insert
local Class, Frame, TableFrame = ns.lua.Class, ui.Frame, ui.TableFrame
local Left, Center, Right = ui.justify.Left, ui.justify.Center, ui.justify.Right
local RAID_CLASS_COLORS = RAID_CLASS_COLORS -- luacheck: globals RAID_CLASS_COLORS

local transpBk = {color = ns.Colors.TransparentBlack}

local colInfo = {
  {name = "Character", width = 105, justifyH = Left,  backdrop = transpBk},
  {name = "Vault",     width = 45,  justifyH = Right, backdrop = transpBk},
  {name = "M+",        width = 35,  justifyH = Right, backdrop = transpBk, padLeft = 8},
  {name = "Caches",    width = 40,  justifyH = Center, backdrop = transpBk, padLeft = 8},
}

local function getCharacters(isAlliance)
  local result = {}
  for _, t in ipairs(ns.api:GetAllCharacters()) do
    if t.isAlliance == isAlliance then
      insert(result, t)
    end
  end
  table.sort(result, function(a, b)
    if a.basic.level ~= b.basic.level then return a.basic.level > b.basic.level end
    return a.name < b.name
  end)
  return result
end

local function vaultData(toon)
  local v = toon.weeklies and toon.weeklies.vault
  if not v or v.best == 0 then return "" end
  return {text = v.best, justifyH = Right}
end

local function dungeonData(toon)
  local d = toon.weeklies and toon.weeklies.dungeons
  if not d then return "" end
  return {text = d.done .. "/" .. d.max, justifyH = Right}
end

local function cachesData(toon)
  local n = toon.weeklies and toon.weeklies.caches
  if not n or n == 0 then return "" end
  return {text = n, justifyH = Center}
end

local function buildData(isAlliance)
  local data = {}
  for _, toon in ipairs(getCharacters(isAlliance)) do
    local c = toon.classKey and RAID_CLASS_COLORS[toon.classKey:upper()]
    insert(data, {
      c and c:WrapTextInColorCode(toon.name) or toon.name,
      vaultData(toon),
      dungeonData(toon),
      cachesData(toon),
    })
  end
  return data
end

local GAP = 20

local WeeklyView = Class(Frame, function(self)
  self.alliance = TableFrame:new{
    parent     = self,
    colInfo    = colInfo,
    autosize   = true,
    cellHeight = 16,
    position   = { TopLeft = {} },
  }
  self.horde = TableFrame:new{
    parent     = self,
    colInfo    = colInfo,
    autosize   = true,
    cellHeight = 16,
    position   = { TopLeft = {self.alliance, ui.edge.TopRight, GAP, 0} },
  }
  self:refresh()
end, {
  name   = "weekly",
  _title = "Weekly",
})
WeeklyView.name = "weekly"
ns.views.WeeklyView = WeeklyView

function WeeklyView:refresh()
  self.alliance.data = buildData(true)
  self.alliance:update()
  self.alliance:Autosize()
  self.horde.data    = buildData(false)
  self.horde:update()
  self.horde:Autosize()
  self:Width(self.alliance:Width() + GAP + self.horde:Width())
  self:Height(math.max(self.alliance:Height(), self.horde:Height()))
end

function WeeklyView:OnBeforeShow()
  ns.api:RefreshCurrentCharacterField("weeklies", "keystone")
  ns.api:RefreshCurrentCharacterField("weeklies", "dungeons")
  self:refresh()
end
