local _, ns = ...
local ui = ns.ui
local insert = table.insert
local Class, Frame, TableFrame = ns.lua.Class, ui.Frame, ui.TableFrame
local Left, Center, Right = ui.justify.Left, ui.justify.Center, ui.justify.Right
local RAID_CLASS_COLORS = RAID_CLASS_COLORS -- luacheck: globals RAID_CLASS_COLORS

local transpBk   = {color = {0, 0, 0, 0}}
local GreenCheck = {
  atlas     = ns.icons.CheckGreen,
  atlasSize = false,
  position  = { TopLeft = {3, -2}, BottomRight = {-3, 2} },
}

local colInfo = {
  {name = "Character", width = 105, justifyH = Left,   backdrop = transpBk},
  {name = "Vault",     width = 45,  justifyH = Right,  backdrop = transpBk},
  {name = "Pre-Mid",   width = 45,  justifyH = Center, backdrop = transpBk},
  {name = "WWI Rep",   width = 45,  justifyH = Center, backdrop = transpBk},
  {name = "Caches",    width = 40,  justifyH = Center, backdrop = transpBk},
  {name = "Delves",    width = 40,  justifyH = Center, backdrop = transpBk},
}

local function getCharacters(isAlliance)
  local result = {}
  for _, t in ipairs(ns.api:GetAllCharacters()) do
    if not t.IsLegionTimerunner and t.isAlliance == isAlliance then
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

local function preMidData(toon)
  local pm = toon.weeklies and toon.weeklies.preMidnight
  if not pm then return "" end
  local n = (pm.three and 1 or 0) + (pm.eight and 1 or 0)
  if n == 2 then return GreenCheck end
  return {text = n .. "/2", justifyH = Center}
end

local function wwiRepData(toon)
  local wwi = toon.quests and toon.quests.WWIRep
  if not wwi then return "" end
  if wwi.complete then return GreenCheck end
  return {text = (7 - wwi.missing) .. "/7", justifyH = Center}
end

local function cachesData(toon)
  local n = toon.weeklies and toon.weeklies.caches
  if not n or n == 0 then return "" end
  return {text = n, justifyH = Center}
end

local function delvesData(toon)
  local d = toon.quests and toon.quests.delves
  if not d then return "" end
  if d.complete then return GreenCheck end
  if d.missing and d.missing > 0 then
    return {text = d.missing, justifyH = Center}
  end
  return ""
end

local function buildData(isAlliance)
  local data = {}
  for _, toon in ipairs(getCharacters(isAlliance)) do
    local c = toon.classKey and RAID_CLASS_COLORS[toon.classKey:upper()]
    insert(data, {
      c and c:WrapTextInColorCode(toon.name) or toon.name,
      vaultData(toon),
      preMidData(toon),
      wwiRepData(toon),
      cachesData(toon),
      delvesData(toon),
    })
  end
  return data
end

local GAP = 20

local WeeklyView = Class(Frame, function(self)
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
  name   = "weekly",
  _title = "Weekly",
})
WeeklyView.name = "weekly"
ns.views.WeeklyView = WeeklyView

function WeeklyView:refresh()
  self.alliance.data = buildData(true)
  self.alliance:update()
  self.horde.data    = buildData(false)
  self.horde:update()
  self:Width(self.alliance:Width() + GAP + self.horde:Width())
  self:Height(math.max(self.alliance:Height(), self.horde:Height()))
end

function WeeklyView:OnBeforeShow()
  self:refresh()
end
