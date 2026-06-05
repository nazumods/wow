local _, ns = ...

-- Auto-saves always capture everything regardless of the user's include settings.
local FULL_INCLUDE = { bars = true, bindings = true, macros = true, petbar = true, outfits = true }

local function AutoSaveName()
  local spec    = GetSpecialization and GetSpecialization()
  local specName = spec and select(2, GetSpecializationInfo(spec)) or "Unknown"
  return UnitName("player") .. " - " .. specName
end

local function DoAutoSave()
  local profile = ns.Capture(FULL_INCLUDE, true, true)
  local encoded = ns.Encode(profile)
  local name    = AutoSaveName()

  local profiles = ns.db.profiles
  for i, p in ipairs(profiles) do
    if p.autosave and p.name == name then
      profiles[i] = {
        name = name, char = profile.char, class = profile.class,
        spec = profile.spec, encoded = encoded, autosave = true,
      }
      return
    end
  end

  -- No existing auto-save for this char+spec; insert at top
  table.insert(profiles, 1, {
    name = name, char = profile.char, class = profile.class,
    spec = profile.spec, encoded = encoded, autosave = true,
  })
end

ns:registerEvent("PLAYER_LOGIN", function(self, ...)
  DoAutoSave()
end)

ns:registerEvent("PLAYER_LOGOUT", function(self, ...)
  DoAutoSave()
end)

-- Delay slightly on spec change to let the new spec fully settle
ns:registerEvent("ACTIVE_TALENT_GROUP_CHANGED", function(self, ...)
  ns:delay(500, DoAutoSave)
end)
