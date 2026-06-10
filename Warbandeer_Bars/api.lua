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

function API:GetCurrentCharacter() return UnitName("player") end
function API:GetCurrentSpecID()    return currentSpecID() end

---All profiles for a character, keyed by specID.
---@param char string? defaults to current character
---@return table<number, table>?
function API:GetProfiles(char)
  return ns.db.profiles[char or UnitName("player")]
end

---A single stored profile.
---@param char string? defaults to current character
---@param specID number? defaults to current spec
---@return table?
function API:GetProfile(char, specID)
  local byChar = ns.db.profiles[char or UnitName("player")]
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
function API:DeleteProfile(char, specID)
  local byChar = ns.db.profiles[char]
  if not byChar then return end
  byChar[specID] = nil
  if not next(byChar) then ns.db.profiles[char] = nil end
end

---Apply a profile table to the current character.
---@param profile table
---@param include table? restore filter; defaults to the per-character settings
---@param silent boolean?
function API:Restore(profile, include, silent)
  ns.Restore(profile, include or ns.settings.include, silent)
end

---Apply a stored profile (by key) to the current character.
---@return boolean ok  false if no such profile exists
function API:RestoreProfile(char, specID, include, silent)
  local p = self:GetProfile(char, specID)
  if not p then return false end
  ns.Restore(p, include or ns.settings.include, silent)
  return true
end

-- ── Engine passthrough (for export/import string transport) ─────────────────────

---Capture without storing. Useful for building an export string.
---@return table profile
function API:Capture(include, accountMacros, charMacros)
  local s = ns.settings
  return ns.Capture(
    include       or s.include,
    accountMacros == nil and s.accountMacros or accountMacros,
    charMacros    == nil and s.charMacros    or charMacros
  )
end

---@param profile table
---@return string
function API:Encode(profile) return ns.Encode(profile) end

---@param text string
---@return table|nil profile, string|nil err
function API:Decode(text) return ns.Decode(text) end

---The per-character restore include filter (live table; mutate to change).
---@return table
function API:GetIncludeSettings() return ns.settings.include end
