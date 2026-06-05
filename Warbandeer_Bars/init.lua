-- luacheck: globals LibNAddOn WarbandeerBarsApi WarbandeerBarsSettings
---@class Warbandeer_Bars: AddOn
local ns = LibNAddOn(...)

-- Default RESTORE include filter (per-character, SavedVariablesPerCharacter).
-- Capture always stores full fidelity (see tracker.lua); this only controls
-- which parts a restore applies by default. A consuming UI can override per call.
ns.DefaultSettings = {
  include = {
    bars     = true,
    macros   = true,
    petbar   = true,
    bindings = false,
    outfits  = false,
  },
  accountMacros = true,
  charMacros    = true,
}

function ns:MigrateDB()
  local db = self.db
  if not db.version then
    db.profiles = {}   -- [charName] = { [specID] = profile }
    db.version  = 1
  end
end

function ns:onLoad()
  -- Initialise per-character settings, filling in defaults for missing keys.
  WarbandeerBarsSettings = WarbandeerBarsSettings or {}
  local s = WarbandeerBarsSettings
  s.include = s.include or {}
  for k, v in pairs(ns.DefaultSettings.include) do
    if s.include[k] == nil then s.include[k] = v end
  end
  if s.accountMacros == nil then s.accountMacros = ns.DefaultSettings.accountMacros end
  if s.charMacros    == nil then s.charMacros    = ns.DefaultSettings.charMacros    end
  ns.settings = s
end
