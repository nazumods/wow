---@type Warbandeer_Bars
local ns = select(2, ...)
local insert, sort = table.insert, table.sort

local GetSpec     = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)     or _G.GetSpecialization
local GetSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo

---@class WarbandeerBarsApi
local API = ns.api

local function currentSpecID()
  local idx = GetSpec and GetSpec()
  if not idx then return 0 end
  return (GetSpecInfo(idx)) or 0
end

-- Resolve a possibly mis-cased character name to its stored profile key. WoW
-- canonicalises names (first letter upper), so a typed "lurias" should still find the
-- stored "Lurias" — exact hit first (O(1) for the current character / correct casing),
-- case-insensitive scan only on a miss. Returns the name unchanged when nothing matches,
-- so callers still resolve to nil and report "no profile".
local function resolveChar(name)
  if not name or ns.db.profiles[name] then return name end
  local lower = name:lower()
  for key in pairs(ns.db.profiles) do
    if key:lower() == lower then return key end
  end
  return name
end

function API:GetCurrentCharacter() return UnitName("player") end
function API:GetCurrentSpecID()    return currentSpecID() end

---All profiles for a character, keyed by specID.
---@param char string? defaults to current character
---@return table<number, table>?
function API:GetProfiles(char)
  return ns.db.profiles[resolveChar(char or UnitName("player"))]
end

---A single stored profile.
---@param char string? defaults to current character
---@param specID number? defaults to current spec
---@return table?
function API:GetProfile(char, specID)
  local byChar = ns.db.profiles[resolveChar(char or UnitName("player"))]
  return byChar and byChar[specID or currentSpecID()]
end

---Names of every character that has at least one stored profile (sorted).
---@return string[]
function API:ListCharacters()
  local list = {}
  for char in pairs(ns.db.profiles) do insert(list, char) end
  sort(list)
  return list
end

---Flat list of every stored profile, for UI enumeration.
---@return table[]
function API:GetAllProfiles()
  local list = {}
  for _, byChar in pairs(ns.db.profiles) do
    for _, p in pairs(byChar) do insert(list, p) end
  end
  return list
end

---Capture the current character now and store it. Returns the stored profile
---(nil if skipped, e.g. in combat or no active spec).
---@return table?
function API:Snapshot() return ns.Snapshot() end

---Forget a stored profile.
---@param char string
---@param specID number
---@return boolean deleted  false if the character had no such stored profile
function API:DeleteProfile(char, specID)
  char = resolveChar(char)
  local byChar = ns.db.profiles[char]
  if not byChar or byChar[specID] == nil then return false end
  byChar[specID] = nil
  if not next(byChar) then ns.db.profiles[char] = nil end
  return true
end

---Forget every stored profile for a character (resolves casing, like DeleteProfile).
---@param char string
---@return boolean deleted  false if the character had no stored profiles
function API:DeleteCharacter(char)
  char = resolveChar(char)
  if not ns.db.profiles[char] then return false end
  ns.db.profiles[char] = nil
  return true
end

---Apply a profile table to the current character.
---@param profile table
---@param include table? restore filter; defaults to the per-character settings
---@param silent boolean?
---@param barFilter table? map of internal bar numbers (1-15) to bool; false = leave that bar untouched
function API:Restore(profile, include, silent, barFilter)
  ns.Restore(profile, include or ns.settings.include, silent, barFilter)
end

---Apply a stored profile (by key) to the current character.
---@return boolean ok  false if no such profile exists
function API:RestoreProfile(char, specID, include, silent, barFilter)
  local p = self:GetProfile(char, specID)
  if not p then return false end
  ns.Restore(p, include or ns.settings.include, silent, barFilter)
  return true
end

---Capture without storing.
---@return table profile
function API:Capture(include, accountMacros, charMacros)
  local s = ns.settings
  return ns.Capture(
    include       or s.include,
    accountMacros == nil and s.accountMacros or accountMacros,
    charMacros    == nil and s.charMacros    or charMacros
  )
end

---The per-character restore include filter (live table; mutate to change).
---@return table
function API:GetIncludeSettings() return ns.settings.include end

---All stored Edit Mode layout snapshots, keyed by layout name.
---@return table<string, table>
function API:GetLayouts()
  return ns.db.layouts or {}
end

---Bar settings for a single named Edit Mode layout, or nil if unknown.
---@param name string?
---@return table?   { [barIndex] = {numIcons, numRows, orientation} }
function API:GetLayout(name)
  return name and (ns.db.layouts or {})[name]
end
