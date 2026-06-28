-- luacheck: globals BINDING_HEADER_WARBANDEER BINDING_NAME_WARBANDEER_TOGGLE Warbandeer_ToggleBinding
---@type Warbandeer
local ns = select(2, ...)

-- Keybinding entry point. `Bindings.xml` declares WARBANDEER_TOGGLE under this
-- header, so it appears in Esc → Key Bindings → Warbandeer for the user to assign
-- (recommended: Alt-W). No forced default key: auto-grabbing one without a persisted
-- "already applied" flag would re-bind it on every login after the user clears it,
-- and this binding intentionally carries no saved-variable state.
BINDING_HEADER_WARBANDEER = "Warbandeer"
BINDING_NAME_WARBANDEER_TOGGLE = "Toggle Warbandeer window"

-- Binding bodies run in the global environment, so the handler must be a global.
-- The binding is runOnUp (Bindings.xml), so it fires on both edges with `keystate`
-- = "down"/"up": a tap toggles the window, a hold pops the radial ring (ring.lua).
-- Pure insecure UI — no SetAttribute, taint-free in combat.
function Warbandeer_ToggleBinding(keystate)
  if keystate == "up" then
    ns:RingKeyUp()
  else
    ns:RingKeyDown()
  end
end
