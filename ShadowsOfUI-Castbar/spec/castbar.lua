-- Loads ShadowsOfUI-Castbar/CastBar.lua against a fake environment so CastBar:Refresh / onUpdate /
-- applyColor can be driven on a bare fake bar. `ns.lua.Class` returns the plain class table (the
-- constructor never runs), the widget classes are inert, and the unit-cast APIs are scripted
-- through `state`. Path is relative to the AddOns root, where busted runs.
local M = {}

-- A stand-in for a "secret" value (WoW's anti-automation guard): any arithmetic or comparison on
-- it errors, as it does for tainted code in game. Refresh must only pass it through to C.
M.secret = setmetatable({}, {
  __add = function() error("attempt to perform arithmetic on a secret value") end,
  __sub = function() error("attempt to perform arithmetic on a secret value") end,
  __lt = function() error("attempt to compare a secret value") end,
  __le = function() error("attempt to compare a secret value") end,
})

---@param opts { canaccess: boolean? }?  `canaccess = false` loads without `canaccessvalue` (Forever)
---@return table CastBar, table state
function M.load(opts)
  opts = opts or {}
  local state = { time = 100, casting = nil, channel = nil, secretValues = {} }

  _G.GameFontHighlightSmall = { GetFont = function() return "font.ttf" end }
  _G.UIParent = {}
  _G.GetTime = function() return state.time end
  _G.UnitCastingInfo = function() if state.casting then return unpack(state.casting) end end
  _G.UnitChannelInfo = function() if state.channel then return unpack(state.channel) end end
  if opts.canaccess == false then
    _G.canaccessvalue = nil
  else
    _G.canaccessvalue = function(v) return not state.secretValues[v] end
  end

  local widgetClass = { new = function() return {} end }
  local ns = {
    ui = { StatusBar = widgetClass, Texture = widgetClass, Label = widgetClass, layer = {}, edge = {}, justify = {} },
    lua = { Class = function() return {} end },
    Colors = { rgba = function(r) return { r = r, GetRGBA = function(self) return self.r, 0, 0, 1 end } end },
  }
  assert(loadfile("ShadowsOfUI-Castbar/CastBar.lua"))("ShadowsOfUI-Castbar", ns)
  return ns.CastBar, state
end

---A bare bar carrying the fields/methods Refresh touches. Everything it does is recorded in `bar.log`.
---@param CastBar table
---@param fields table?
function M.newBar(CastBar, fields)
  local bar = { unit = "target", _enabled = true, log = {} }
  local function rec(name) return function(_, ...) bar.log[#bar.log + 1] = { name, ... } end end
  bar.Hide, bar.Show = rec("Hide"), rec("Show")
  bar.stopUpdates, bar.startUpdates = rec("stopUpdates"), rec("startUpdates")
  bar.icon = { Texture = function(_, t) bar.iconTex = t end }
  bar.nameText = { Text = function(_, t) bar.name = t end }
  bar.timeText = { Text = function(_, t) bar.time = t end }
  bar._widget = {
    SetMinMaxValues = function(_, lo, hi) bar.range = { lo, hi } end,
    SetValue = function(_, v) bar.value = v end,
    SetStatusBarColor = function(_, r) bar.color = r end,
  }
  -- the real methods under test; the onUpdate stub keeps Refresh's own contract (it calls it once)
  bar.applyColor = CastBar.applyColor
  bar.onUpdate = function(self, ...) self.log[#self.log + 1] = { "onUpdate", ... } end
  for k, v in pairs(fields or {}) do bar[k] = v end
  return bar
end

function M.logged(bar, name)
  for _, e in ipairs(bar.log) do if e[1] == name then return true end end
  return false
end

return M
