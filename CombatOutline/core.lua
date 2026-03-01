local ADDON_NAME, ns = ...
-- luacheck: globals LibNAddOn SetCVar

LibNAddOn{
  name = ADDON_NAME,
  addOn = ns,
  db = {
    name = "CombatOutlineDB",
  },
}

function ns:PLAYER_REGEN_DISABLED()
  -- todo: save current cvar values and restore them on leave combat
  SetCVar("OutlineEngineMode", 1)
end
ns:registerEvent("PLAYER_REGEN_DISABLED")

function ns:PLAYER_REGEN_ENABLED()
  SetCVar("OutlineEngineMode", 0)
end
ns:registerEvent("PLAYER_REGEN_ENABLED")
