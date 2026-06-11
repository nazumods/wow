local ADDON_NAME = ...
---@class CombatOutline: AddOn
local ns = select(2, ...)
-- luacheck: globals LibNAddOn GetCVar SetCVar

LibNAddOn{
  name = ADDON_NAME,
  addOn = ns,
  db = {
    name = "CombatOutlineDB",
  },
}

local savedMode

function ns:PLAYER_REGEN_DISABLED()
  savedMode = GetCVar("OutlineEngineMode")
  SetCVar("OutlineEngineMode", 1)
end
ns:registerEvent("PLAYER_REGEN_DISABLED")

function ns:PLAYER_REGEN_ENABLED()
  SetCVar("OutlineEngineMode", savedMode or "0")
end
ns:registerEvent("PLAYER_REGEN_ENABLED")
