local _, ns = ...
local ui = ns.ui
local insert = table.insert
local TitleFrame, TableFrame = ui.TitleFrame, ui.TableFrame
local Left = ui.justify.Left
local RAID_CLASS_COLORS = RAID_CLASS_COLORS -- luacheck: globals RAID_CLASS_COLORS

local window    = nil
local transpBk  = {color = {0, 0, 0, 0}}

local colInfo = {
  {name = "Character", width = 105, justifyH = Left,   backdrop = transpBk},
  {name = "Lvl",       width = 30,  justifyH = Left,  backdrop = transpBk},
  {name = "Class",     width = 90,  justifyH = Left,  backdrop = transpBk},
  {name = "Played",    width = 95,  justifyH = Left,  backdrop = transpBk, padLeft = 10},
}

local function formatTime(seconds)
  if not seconds then return "?" end
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
    if not t.IsLegionTimerunner and t.isAlliance == isAlliance then
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
local PAD = 10

local function newTable(parent, anchor)
  return TableFrame:new{
    parent     = parent,
    colInfo    = colInfo,
    cellHeight = 16,
    position   = { TopLeft = anchor },
  }
end

local function createWindow()
  local f = TitleFrame:new{
    name     = "WarbandeerPlaytimeWindow",
    title    = "Played Time",
    special  = true,
    level    = 600,
    position = { Center = {} },
  }
  local alliance = newTable(f, {f.titlebar, ui.edge.BottomLeft, PAD, -PAD})
  local horde    = newTable(f, {alliance, ui.edge.TopRight, GAP, 0})
  f._alliance = alliance
  f._horde    = horde
  return f
end

ns:registerCommand("playtime", "", function(self)
  if not window then
    window = createWindow()
  end

  window._alliance.data = buildData(true)
  window._alliance:update()
  window._horde.data    = buildData(false)
  window._horde:update()

  local w = window._alliance:Width() + GAP + window._horde:Width() + PAD * 2
  local h = math.max(window._alliance:Height(), window._horde:Height())
  window:Width(w)
  window:Height(h + window.titlebar:Height() + PAD * 2)
  window:Show()
end, "Show character played time")
