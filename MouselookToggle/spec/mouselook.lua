-- Loads MouselookToggle/addon.lua against a scriptable fake client so the toggle keybind and the
-- reticle OnUpdate (held-freelook debounce, right-click cancel) can be unit-tested. `state`
-- is the fake client: tests set `looking` / `buttons` / `time` and read back `calls`.
-- `ns:after(0, fn)` queues `fn` on `state.pending`; `state.flush()` runs the queue (a frame later).
-- Path is relative to the AddOns root, where busted runs.
local M = {}

---@return table w  { ns, state, tick(), crosshair, reticle }
function M.load()
  local state = {
    looking = false,
    buttons = {},       -- ["LeftButton"] = true while held
    time = 0,
    calls = {},         -- ordered: "MouselookStart", "MouselookStop", "RestoreCVars", {"SetTemporaryCVar", name, value}
    pending = {},
  }
  function state.flush()
    local q = state.pending
    state.pending = {}
    for _, fn in ipairs(q) do fn() end
  end

  _G.MouselookStart = function() state.looking = true; state.calls[#state.calls + 1] = "MouselookStart" end
  _G.MouselookStop = function() state.looking = false; state.calls[#state.calls + 1] = "MouselookStop" end
  _G.IsMouselooking = function() return state.looking end
  _G.IsMouseButtonDown = function(b) return state.buttons[b] == true end
  _G.GetTime = function() return state.time end
  _G.GetCursorPosition = function() return 400, 300 end
  _G.UIParent = { GetEffectiveScale = function() return 1 end }

  local reticle
  local crosshair = { shown = false, alpha = nil }
  function crosshair:SetAllPoints() end
  function crosshair:SetAtlas() end
  function crosshair:Hide() self.shown = false end
  function crosshair:Show() self.shown = true end
  function crosshair:SetAlpha(a) self.alpha = a end
  reticle = {
    SetSize = function() end,
    CreateTexture = function() return crosshair end,
    SetScript = function(self, name, fn) if name == "OnUpdate" then self.onUpdate = fn end end,
    ClearAllPoints = function() end,
    SetPoint = function(self, ...) self.point = { ... } end,
  }
  _G.CreateFrame = function() return reticle end

  local ns = {
    _TITLE = "Mouselook Toggle",
    db = { reticleHeight = 50, showHeld = true },
    RegisterSettings = function(self, def) self.settings = def end,
    after = function(_, _, fn) state.pending[#state.pending + 1] = fn end,
    SetTemporaryCVar = function(_, name, value) state.calls[#state.calls + 1] = { "SetTemporaryCVar", name, value } end,
    RestoreCVars = function() state.calls[#state.calls + 1] = "RestoreCVars" end,
  }
  _G.LibNAddOn = function() return ns end
  assert(loadfile("MouselookToggle/addon.lua"))("MouselookToggle", ns)

  local w = { ns = ns, state = state, crosshair = crosshair, reticle = reticle }
  ---Press the keybind (the MOUSELOOKTOGGLE_TOGGLE binding calls this global).
  function w.toggle() _G.MouselookToggle_Toggle() end
  ---Run one reticle frame, optionally advancing the clock first.
  function w.tick(dt) state.time = state.time + (dt or 0); reticle.onUpdate() end
  ---How many times `name` appears in the ordered call log.
  function w.count(name)
    local n = 0
    for _, c in ipairs(state.calls) do if c == name then n = n + 1 end end
    return n
  end
  return w
end

return M
