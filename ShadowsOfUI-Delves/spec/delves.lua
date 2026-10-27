-- Loads the REAL ShadowsOfUI-Delves core.lua + tooltip.lua against a scriptable fake client so the delve
-- entrance-pin tooltip (average completion time, average XP and XP/hr) can be driven out of game.
-- `state` is the fake client: `maxLevel`, `maxXP`, `stats` (what ns.api:GetDelveStats returns), `me`, `shift`.
-- `state.hover(poiName)` fires the hooked DelveEntrancePinMixin.OnMouseEnter on a delve pin and returns the
-- lines GameTooltip received. Path is relative to the AddOns root, where busted runs.
local M = {}

---@param init { maxLevel: boolean?, maxXP: number?, stats: table[]?, me: string? }?
---@return table ns, table state
function M.load(init)
  local state = { maxLevel = false, maxXP = 100000, stats = nil, me = "Me", shift = false, lines = {}, shows = 0 }
  for k, v in pairs(init or {}) do state[k] = v end

  local wrap = { WrapTextInColorCode = function(_, t) return t end }
  _G.NORMAL_FONT_COLOR, _G.GRAY_FONT_COLOR, _G.WHITE_FONT_COLOR = wrap, wrap, wrap
  _G.CreateColor = function() return wrap end
  _G.AbbreviateNumbers = function(n) return tostring(n) end
  _G.BreakUpLargeNumbers = function(n) return tostring(n) end
  _G.IsShiftKeyDown = function() return state.shift end
  _G.SlashCmdList = {}
  _G.GameTooltip = {
    AddLine = function(_, text) state.lines[#state.lines + 1] = text end,
    Show = function() state.shows = state.shows + 1 end,
  }
  _G.C_AreaPoiInfo = {
    GetDelvesForMap = function() return { 5001 } end,
    GetAreaPOIInfo = function() return { name = "Fallback Delve" } end,
  }
  _G.EventUtil = { ContinueOnAddOnLoaded = function(_, fn) fn() end }
  _G.hooksecurefunc = function(tbl, name, fn)
    local orig = tbl[name]
    tbl[name] = function(...) orig(...); fn(...) end
  end
  _G.DelveEntrancePinMixin = { OnMouseEnter = function() end }

  local ns = {
    RegisterChangelog = function() end,
    Print = function() end,
    ui = {},
    lua = { strings = { duration = function(s) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end } },
    wow = { Player = {
      isMaxLevel = function() return state.maxLevel end,
      GetMaxXP = function() return state.maxXP end,
    } },
    api = {
      GetDelveStats = function() return state.stats end,
      GetCurrentCharacter = function() return state.me end,
    },
  }
  _G.LibNAddOn = function() return ns end
  assert(loadfile("ShadowsOfUI-Delves/core.lua"))("ShadowsOfUI-Delves", ns)
  assert(loadfile("ShadowsOfUI-Delves/tooltip.lua"))("ShadowsOfUI-Delves", ns)

  function state.hover(poiName, areaPoiID)
    state.lines, state.shows = {}, 0
    local pin = {
      poiInfo = { areaPoiID = areaPoiID or 5001, name = poiName },
      GetMap = function() return { GetMapID = function() return 2248 end } end,
    }
    _G.DelveEntrancePinMixin.OnMouseEnter(pin)
    return state.lines
  end
  return ns, state
end

return M
