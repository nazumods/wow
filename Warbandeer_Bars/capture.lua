---@type Warbandeer_Bars
local ns = select(2, ...)
-- luacheck: globals C_EditMode

local MAX_BARS   = 180
local MAX_MACROS = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS

local GetSpec     = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)     or _G.GetSpecialization
local GetSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo

-- Spell overrides: override spellId -> base spellId
local function BuildSpellOverrides()
  local map = {}
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return map end

  for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)  -- MayReturnNothing
    if info then
      for i = 1, info.numSpellBookItems do
        local spellIndex = info.itemIndexOffset + i
        local spellType, id, spellId = C_SpellBook.GetSpellBookItemType(spellIndex, Enum.SpellBookSpellBank.Player)
        if spellId then
          local ovr = C_Spell.GetOverrideSpell(spellId)
          if ovr ~= spellId then map[ovr] = spellId end
        elseif spellType == Enum.SpellBookItemType.Flyout then
          local _, _, numSlots, isKnown = GetFlyoutInfo(id)
          if isKnown and numSlots > 0 then
            for k = 1, numSlots do
              local sid, ovr = GetFlyoutSlotInfo(id, k)
              if ovr ~= sid then map[ovr] = sid end
            end
          end
        end
      end
    end
  end
  return map
end

-- Capture all non-empty action bar slots
local function CaptureSlots(overrides)
  local slots = {}
  for i = 1, MAX_BARS do
    local slotType, index, subType = GetActionInfo(i)
    if slotType and slotType ~= "" then
      local entry = { id = i, type = slotType }
      if slotType == "spell" then
        if subType == "assistedcombat" then
          entry.index = C_AssistedCombat.GetActionSpell()
        else
          entry.index = overrides[index] or index
        end
      elseif slotType == "macro" then
        -- subType means it's a temp macro; resolve real index via cursor
        if subType then
          PickupAction(i)
          index = select(2, GetCursorInfo())
          PlaceAction(i)
        end
        entry.index = index
      elseif slotType == "item" or slotType == "toy" or slotType == "flyout"
          or slotType == "companion" or slotType == "summonmount" then
        entry.index = index
      elseif slotType == "summonpet" then
        entry.strindex = index  -- GUID string
      elseif slotType == "equipmentset" then
        entry.strindex = index  -- set name
      end
      slots[#slots+1] = entry
    end
  end
  return slots
end

-- Capture key bindings (skip unbound)
local function CaptureBindings()
  local binds = {}
  for i = 1, GetNumBindings() do
    local command, _, key1, key2 = GetBinding(i)
    if command and (key1 or key2) then
      binds[#binds+1] = { command = command, key1 = key1, key2 = key2 }
    end
  end
  return binds
end

-- Capture macros
local function CaptureMacros(accountMacros, charMacros)
  local macros = {}

  -- capture account macros
  if accountMacros then
    for i = 1, MAX_ACCOUNT_MACROS do
      local name, icon, body = GetMacroInfo(i)
      if name then
        icon = gsub(strupper(icon or "INV_Misc_QuestionMark"), "INTERFACE\\ICONS\\", "")
        macros[#macros+1] = { id = i, name = name, icon = icon, body = body }
      end
    end
  end

  -- capture character macros
  if charMacros then
    for i = MAX_ACCOUNT_MACROS + 1, MAX_MACROS do
      local name, icon, body = GetMacroInfo(i)
      if name then
        icon = gsub(strupper(icon or "INV_Misc_QuestionMark"), "INTERFACE\\ICONS\\", "")
        macros[#macros+1] = { id = i, name = name, icon = icon, body = body }
      end
    end
  end
  return macros
end

-- Capture pet action bar
local function CapturePetBar()
  local slots = {}
  if not IsPetActive() then return slots end
  for i = 1, NUM_PET_ACTION_SLOTS do
    local name, _, isToken, _, _, _, spellID = GetPetActionInfo(i)
    if isToken then
      slots[#slots+1] = { id = i, type = "token", strindex = name }
    elseif spellID then
      slots[#slots+1] = { id = i, type = "spell", index = spellID }
    end
  end
  return slots
end

-- Capture equipment sets (outfits) — just names; C_EquipmentSet holds the gear
local function CaptureOutfits()
  local outfits = {}
  if not C_EquipmentSet then return outfits end
  for i = 0, C_EquipmentSet.GetNumEquipmentSets() - 1 do
    local name = C_EquipmentSet.GetEquipmentSetInfo(i)
    if name then outfits[#outfits+1] = name end
  end
  return outfits
end

-- Build profile metadata from current character
local function ProfileMeta()
  local specIndex = GetSpec and GetSpec()
  local specID, specName, specIcon
  if specIndex then
    local id, name, _, icon = GetSpecInfo(specIndex)
    specID, specName, specIcon = id, name, icon
  end
  local _, class, classID = UnitClass("player")
  return {
    char       = UnitName("player"),
    realm      = GetRealmName(),
    class      = class,                 -- class file token, e.g. "MAGE"
    classID    = classID,
    specID     = specID or 0,
    spec       = specName or "Unknown",
    specIcon   = specIcon,
    level      = UnitLevel("player"),
    bindingSet = GetCurrentBindingSet(),  -- 1=account, 2=per-character
    layoutName = ns._activeLayoutName,    -- set by ns.CaptureLayouts()
  }
end

---Snapshot the active Edit Mode layouts into db.layouts and record the active layout name.
---Safe to call outside combat at any time.
function ns.CaptureLayouts()
  if not C_EditMode then return end
  local info = C_EditMode.GetLayouts()
  if not info or not info.layouts then return end

  -- info.layouts holds only saved layouts, but activeLayout indexes as if the
  -- preset layouts (Modern, Classic) came first — subtract them. A preset being
  -- active leaves _activeLayoutName nil (presets are default 1-row bars anyway).
  local numPresets = 0
  for _ in pairs(Enum.EditModePresetLayouts) do numPresets = numPresets + 1 end
  local al = info.activeLayout and info.layouts[info.activeLayout - numPresets]
  ns._activeLayoutName = al and al.layoutName

  local layouts = {}
  for _, layout in ipairs(info.layouts) do
    if layout.layoutName and layout.systems then
      local bars = {}
      for _, sys in ipairs(layout.systems) do
        if sys.system == Enum.EditModeSystem.ActionBar and sys.systemIndex and sys.settings then
          local entry = {}
          for _, s in ipairs(sys.settings) do
            local sv = s.setting
            if sv == Enum.EditModeActionBarSetting.NumIcons then
              entry.numIcons = s.value
            elseif sv == Enum.EditModeActionBarSetting.NumRows then
              entry.numRows = s.value
            elseif sv == Enum.EditModeActionBarSetting.Orientation then
              entry.orientation = s.value
            end
          end
          if entry.numIcons then bars[sys.systemIndex] = entry end
        end
      end
      layouts[layout.layoutName] = bars
    end
  end
  ns.db.layouts = layouts
end

---Capture the current character's setup into a profile table.
---@param include table  keys: bars, bindings, macros, petbar, outfits
---@param accountMacros boolean
---@param charMacros boolean
---@return table profile
function ns.Capture(include, accountMacros, charMacros)
  local overrides = BuildSpellOverrides()
  local profile = ProfileMeta()
  profile.version  = 1
  profile.captured = time()
  profile.slots    = include.bars     and CaptureSlots(overrides)                  or {}
  profile.binds    = include.bindings and CaptureBindings()                        or {}
  profile.macros   = include.macros   and CaptureMacros(accountMacros, charMacros) or {}
  profile.petslots = include.petbar   and CapturePetBar()                          or {}
  profile.outfits  = include.outfits  and CaptureOutfits()                         or {}
  return profile
end
