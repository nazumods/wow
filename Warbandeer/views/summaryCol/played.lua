---@class Warbandeer
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui

-- played
local function formatPlaytime(seconds)
  if not seconds then return "" end
  local d = math.floor(seconds / 86400)
  local h = math.floor((seconds % 86400) / 3600)
  local m = math.floor((seconds % 3600) / 60)
  if d > 0 then return d.."d "..h.."h "..m.."m" end
  if h > 0 then return h.."h "..m.."m" end
  return m.."m"
end

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "Played",
    width = 100,
    justifyH = ui.justify.Right,
    getData = function(t)
      if not t.playtime then return "" end
      return {text = formatPlaytime(t.playtime.total), justifyH = ui.justify.Right}
    end,
  }
)
