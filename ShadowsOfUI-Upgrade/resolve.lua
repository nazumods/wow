---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)

-- Resolves a stored character's spec to its stat priority.  Locale-independent: a
-- character stores its numeric spec ID (basic.specialization.id), which we map to
-- (classToken, spec index) and index straight into ns.StatPriority (whose per-class
-- arrays are in GetSpecialization() index order).

-- The class/spec-info family moved under C_SpecializationInfo / C_CreatureInfo in 12.x
-- (12.1.0 already removed other long-deprecated globals outright — see the API watchlist).
-- Prefer the namespaced forms and fall back to the legacy globals, mirroring the guard in
-- classcodex.lua / Warbandeer_Bars. GetNumClasses has no namespaced form yet, so it stays
-- global but is guarded in buildSpecMap so a future removal degrades to "no stat tag /
-- primary gate" rather than erroring every StatRanks/PrimaryStat call.
local C_Spec, C_Creature = C_SpecializationInfo, C_CreatureInfo
local GetNumClasses = _G.GetNumClasses
local GetNumSpecs = (C_Spec and C_Spec.GetNumSpecializationsForClassID) or _G.GetNumSpecializationsForClassID
local GetSpecForClass = (C_Spec and C_Spec.GetSpecializationInfoForClassID) or _G.GetSpecializationInfoForClassID

-- Class file token ("MAGE") for a classID. C_CreatureInfo.GetClassInfo returns a table
-- ({ className, classFile, classID }); the legacy global returns them as multiple values —
-- normalise both to the classFile token.
local function classToken(classID)
  if C_Creature and C_Creature.GetClassInfo then
    local info = C_Creature.GetClassInfo(classID)
    return info and info.classFile
  end
  return _G.GetClassInfo and select(2, _G.GetClassInfo(classID))
end

-- specID → { token, index } built once from the live spec tables.  Works for any
-- class/spec without a hardcoded ID list and picks up new specs automatically.
-- Built lazily so it never races class data being warm at file-load.
local specIdMap
local function buildSpecMap()
  local map = {}
  if not (GetNumClasses and GetNumSpecs and GetSpecForClass) then return map end
  for classID = 1, (GetNumClasses() or 0) do
    local token = classToken(classID)
    if token then
      for i = 1, (GetNumSpecs(classID) or 0) do
        local specID = GetSpecForClass(classID, i)
        if specID then map[specID] = { token = token, index = i } end
      end
    end
  end
  return map
end

---Secondary-stat tier map { crit, haste, mastery, versatility } = tier (1 = top)
---for a character's spec, or nil if its spec/priority isn't known (no stored spec
---ID, or a spec absent from ns.StatPriority).
---@param charData Character
---@return table<string, integer>?
function ns.StatRanks(charData)
  local specID = charData and charData.basic and charData.basic.specialization
                 and charData.basic.specialization.id
  if not specID then return nil end
  specIdMap = specIdMap or buildSpecMap()
  local hit = specIdMap[specID]
  if not hit then return nil end
  local byClass = ns.StatPriority[hit.token]
  return byClass and byClass[hit.index]
end

---Primary stat token ("str" | "agi" | "int") for a character's spec, or nil if its
---spec/primary isn't known (no stored spec ID, or a spec absent from
---ns.ClassPrimary).  Used to gate out wrong-primary-stat gear (an Intellect dagger
---for a Rogue, etc.).
---@param charData Character
---@return string?
function ns.PrimaryStat(charData)
  local specID = charData and charData.basic and charData.basic.specialization
                 and charData.basic.specialization.id
  if not specID then return nil end
  specIdMap = specIdMap or buildSpecMap()
  local hit = specIdMap[specID]
  if not hit then return nil end
  local byClass = ns.ClassPrimary[hit.token]
  return byClass and byClass[hit.index]
end
