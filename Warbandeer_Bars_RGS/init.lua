local _, ns = ...

LibNAddOn{
  name    = "Warbandeer_Bars_RGS",
  addOn   = ns,
}

-- Default per-character settings (SavedVariablesPerCharacter, managed manually)
ns.DefaultSettings = {
  include = {
    bars     = true,
    bindings = true,
    macros   = true,
    petbar   = false,
    outfits  = true,
  },
  accountMacros = true,
  charMacros    = true,
}

function ns:MigrateDB()
  local db = self.db
  if not db.version then
    db.profiles = {}
    db.version  = 1
  end
end

function ns:onLoad()
  -- Initialise per-character settings with defaults for any missing keys
  if not WarbandeerBarsRGSSettings then
    WarbandeerBarsRGSSettings = {}
  end
  local s = WarbandeerBarsRGSSettings
  if not s.include then
    s.include = {}
  end
  local inc = ns.DefaultSettings.include
  for k, v in pairs(inc) do
    if s.include[k] == nil then s.include[k] = v end
  end
  if s.accountMacros == nil then s.accountMacros = ns.DefaultSettings.accountMacros end
  if s.charMacros    == nil then s.charMacros    = ns.DefaultSettings.charMacros    end
  ns.settings = s
end
