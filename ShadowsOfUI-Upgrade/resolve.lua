---@type ShadowsOfUI_Upgrade
local ns = select(2, ...)
-- luacheck: globals GetNumClasses GetClassInfo GetNumSpecializationsForClassID GetSpecializationInfoForClassID

-- Resolves a stored character's spec to its stat priority.  Locale-independent: a
-- character stores its numeric spec ID (basic.specialization.id), which we map to
-- (classToken, spec index) and index straight into ns.StatPriority (whose per-class
-- arrays are in GetSpecialization() index order).

-- specID → { token, index } built once from the live spec tables.  Works for any
-- class/spec without a hardcoded ID list and picks up new specs automatically.
-- Built lazily so it never races class data being warm at file-load.
local specIdMap
local function buildSpecMap()
  local map = {}
  for classID = 1, (GetNumClasses() or 0) do
    local _, token = GetClassInfo(classID)
    if token then
      for i = 1, (GetNumSpecializationsForClassID(classID) or 0) do
        local specID = GetSpecializationInfoForClassID(classID, i)
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
