---@type Warbandeer_Bars
local ns = select(2, ...)

local PickupSpell   = C_Spell and C_Spell.PickupSpell   or _G.PickupSpell
local PickupItem    = C_Item  and C_Item.PickupItem      or _G.PickupItem
local GetSpellLink  = C_Spell and C_Spell.GetSpellLink  or _G.GetSpellLink
local PickupSpellBookItem = C_SpellBook and C_SpellBook.PickupSpellBookItem or _G.PickupSpellBookItem

local MAX_BARS = 180

-- 12.1.0 moved these out of the global namespace into Constants.MacroConsts; keep
-- the runtime macro-restore math working on both old and new clients (see capture.lua).
local MacroConsts = Constants and Constants.MacroConsts
local MAX_ACCOUNT_MACROS   = (MacroConsts and MacroConsts.MAX_ACCOUNT_MACROS)   or MAX_ACCOUNT_MACROS   or 120
local MAX_CHARACTER_MACROS = (MacroConsts and MacroConsts.MAX_CHARACTER_MACROS) or MAX_CHARACTER_MACROS or 30

local function Warn(msg)
  ns.Print("|cffff9900[Bars]|r " .. msg)
end

-- Build override map (bidirectional base <-> override) and flyout map
-- (flyoutId -> {spellIndex, bank}) in a single spellbook pass.
-- The override map lets PickupSpell find a working ID for profiles that
-- stored override IDs (e.g. Bear Swipe captured in shapeshift form).
local function BuildSpellbookMaps()
  local overrides, flyouts = {}, {}
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return overrides, flyouts end
  for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)
    if info then
      for i = 1, info.numSpellBookItems do
        local si = info.itemIndexOffset + i
        local spellType, id, spellId = C_SpellBook.GetSpellBookItemType(si, Enum.SpellBookSpellBank.Player)
        if spellId then
          local ovr = C_Spell.GetOverrideSpell(spellId)
          if ovr and ovr ~= spellId then overrides[spellId] = ovr; overrides[ovr] = spellId end
        elseif spellType == Enum.SpellBookItemType.Flyout then
          local _, _, numSlots, isKnown = GetFlyoutInfo(id)
          if isKnown and numSlots > 0 then
            for k = 1, numSlots do
              local sid, ovr = GetFlyoutSlotInfo(id, k)
              if sid and ovr and ovr ~= sid then overrides[sid] = ovr; overrides[ovr] = sid end
            end
          end
          if not flyouts[id] then flyouts[id] = { si, Enum.SpellBookSpellBank.Player } end
        end
      end
    end
  end
  return overrides, flyouts
end

-- PickupSpell fails for some valid spells (e.g. form-specific druid abilities).
-- Fall back to picking up by spellbook index, which works regardless of current form.
local function PickupSpellFromBook(targetSid)
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return end
  for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)
    if info then
      for i = 1, info.numSpellBookItems do
        local si = info.itemIndexOffset + i
        local _, _, sid = C_SpellBook.GetSpellBookItemType(si, Enum.SpellBookSpellBank.Player)
        if sid == targetSid then
          PickupSpellBookItem(si, Enum.SpellBookSpellBank.Player)
          return true
        end
      end
    end
  end
  return false
end

-- Flyout slots must be restored first, before any other PickupSpell/PlaceAction
-- call consumes the hardware event context: PickupSpellBookItem for flyout-type
-- spellbook items (e.g. the warlock Summon Demon drawer) silently fails if it
-- runs after other protected pickup operations in the same event.
local function RestoreFlyouts(slots, flyouts)
  for _, s in ipairs(slots) do
    if s.type == "flyout" then
      local curType, curIndex = GetActionInfo(s.id)
      if not (curType == "flyout" and curIndex == s.index) then
        local f = flyouts[s.index]
        if f then
          ClearCursor()
          PickupSpellBookItem(f[1], f[2])
        end
        if GetCursorInfo() then
          PlaceAction(s.id)
          ClearCursor()
        elseif f then
          local name = GetFlyoutInfo and GetFlyoutInfo(s.index)
          Warn("Slot " .. s.id .. ": drag " .. (name and "[" .. name .. "]" or "flyout " .. s.index)
            .. " from your spellbook to restore it")
        end
      end
    end
  end
end

local function RestoreSlots(slots, overrides)
  for _, s in ipairs(slots) do
    local ok, err = pcall(function()
      local curType, curIndex = GetActionInfo(s.id)
      if curType == s.type and curIndex == (s.index or s.strindex) then return end

      if s.type == "spell" then
        PickupSpell(s.index)
        if not GetCursorInfo() and overrides[s.index] then
          PickupSpell(overrides[s.index])
        end
        local foundInBook = false
        if not GetCursorInfo() then
          foundInBook = PickupSpellFromBook(s.index)
        end
        -- only warn if the spell exists in this character's spellbook but still
        -- failed; if it's not in the book it's unavailable content (profession,
        -- expansion, other class, ...)
        if not GetCursorInfo() and foundInBook then
          Warn("Unknown spell [" .. s.index .. "] " .. (GetSpellLink(s.index) or ""))
        end
      elseif s.type == "flyout" or s.type == "macro" then
        -- flyouts placed in the RestoreFlyouts pre-pass, macros in RestoreMacrosAndSlots
        return
      elseif s.type == "item" then
        PickupItem(s.index)
        -- try by link string (some items only respond to this form)
        if not GetCursorInfo() then
          local link = select(2, GetItemInfo(s.index))
          if link then PickupItem(link) end
        end
        if not GetCursorInfo() then Warn("Missing item [" .. s.index .. "]") end
      elseif s.type == "toy" then
        C_ToyBox.PickupToyBoxItem(s.index)
        if not GetCursorInfo() then Warn("Missing toy [" .. tostring(s.index) .. "]") end
      elseif s.type == "summonpet" then
        C_PetJournal.PickupPet(s.strindex, false)
        if not GetCursorInfo() then C_PetJournal.PickupPet(s.strindex, true) end
        if not GetCursorInfo() then Warn("Missing pet [" .. tostring(s.strindex) .. "]") end
      elseif s.type == "summonmount" then
        -- GetDisplayedMountInfo indexes the DISPLAYED (filtered) list, bounded by
        -- GetNumDisplayedMounts() — not GetNumMounts() (the full catalog); Pickup's
        -- arg is a 1-based index into that same displayed list. The old code looped
        -- GetNumMounts() and fell back to Pickup(0) (Blizzard's "pick up nothing"
        -- index), silently placing a wrong/no mount when a journal filter hid the
        -- target. Loop the displayed bound and warn+blank on a miss like other slots.
        local mi
        if C_MountJournal then
          for i = 1, C_MountJournal.GetNumDisplayedMounts() do
            local _, _, _, _, _, _, _, _, _, _, isCollected, mid = C_MountJournal.GetDisplayedMountInfo(i)
            if isCollected and mid == s.index then mi = i; break end
          end
        end
        if mi then
          C_MountJournal.Pickup(mi)
        else
          Warn("Slot " .. s.id .. ": mount #" .. tostring(s.index)
            .. " is uncollected or hidden by an active mount-journal filter")
        end
      elseif s.type == "companion" then
        -- legacy pre-journal mount/mini-pet action; index is the summon spell ID
        PickupSpell(s.index)
        if not GetCursorInfo() then
          Warn("Missing companion " .. (GetSpellLink(s.index) or ("spell " .. s.index)))
        end
      elseif s.type == "equipmentset" then
        local idx = C_EquipmentSet.GetEquipmentSetID(s.strindex)
        if idx then C_EquipmentSet.PickupEquipmentSet(idx) end
        if not GetCursorInfo() then Warn("Missing equipment set [" .. tostring(s.strindex) .. "]") end
      elseif s.type == "outfit" then
        -- Transmog outfit: resolve the stored name to a current outfitID (identity),
        -- falling back to the captured list position, then pick it up (mirrors the
        -- equipmentset path — a different API, C_TransmogOutfitInfo, not C_EquipmentSet).
        if C_TransmogOutfitInfo then
          local outfits = C_TransmogOutfitInfo.GetOutfitsInfo() or {}
          local outfitID
          if s.strindex then
            for _, info in ipairs(outfits) do
              if info.name == s.strindex then outfitID = info.outfitID; break end
            end
          end
          if not outfitID and s.index then
            local info = outfits[s.index]
            outfitID = info and info.outfitID
          end
          if outfitID then C_TransmogOutfitInfo.PickupOutfit(outfitID) end
          if not GetCursorInfo() then Warn("Missing outfit [" .. tostring(s.strindex or s.index) .. "]") end
        end
      elseif s.type == "petaction" or s.type == "futurespell" then
        PickupAction(s.id) -- clear
      end

      if GetCursorInfo() then
        PlaceAction(s.id)
      else
        PickupAction(s.id)  -- nothing to place; blank the slot
      end
      ClearCursor()
    end)
    if not ok then Warn("Slot error [" .. s.id .. "]: " .. tostring(err)) end
  end
end

-- Find or create a macro by name+body; returns macro index or nil
local function FindOrCreateMacro(m)
  local target = strtrim(m.body):gsub("\r", "")
  for i = 1, MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS do
    local name, _, body = GetMacroInfo(i)
    if name and name == m.name and strtrim(body):gsub("\r","") == target then
      return i
    end
  end
  -- create it
  local numG, numC = GetNumMacros()
  local isChar = m.id > MAX_ACCOUNT_MACROS
  local canG, canC = numG < MAX_ACCOUNT_MACROS, numC < MAX_CHARACTER_MACROS
  -- Prefer the macro's original bank; only fall back to the other when the
  -- preferred one is full. (The old `canG and false or canC` form wrongly put
  -- account macros into the character bank whenever both had free slots.)
  local perchar = isChar and canC or (not canG and canC)
  if not canG and not canC then
    Warn("No macro space for: " .. m.name)
    return nil
  end
  local icon = m.icon
  if strsub(m.body, 1, 12) == "#showtooltip" then icon = "INV_Misc_QuestionMark" end
  return CreateMacro(m.name, icon, m.body, perchar)
end

local function RestoreMacrosAndSlots(macros, slots)
  -- build id->newId map
  local idMap = {}
  for _, m in ipairs(macros) do
    local newId = FindOrCreateMacro(m)
    if newId then idMap[m.id] = newId end
  end
  -- place macro slots
  for _, s in ipairs(slots) do
    if s.type == "macro" and s.index then
      local newId = idMap[s.index]
      if newId then
        PickupMacro(newId)
        if GetCursorInfo() then PlaceAction(s.id) end
        ClearCursor()
      end
    end
  end
end

local function RestoreBindings(binds)
  -- A profile captured with bindings excluded has an empty binds list; treat that as "no
  -- binding data" and leave the live set alone. Without this the clear pass below (empty
  -- `wanted`) would wipe every live keybind — a profile restored with bindings=true but no
  -- captured bindings must not nuke the user's keys.
  if #binds == 0 then return end

  -- Bindings are a full snapshot (CaptureBindings records every bound command), so the
  -- restored set must MATCH the profile, not union with what's already live. Clear any key
  -- bound live but absent from the profile first — the binding analog of ClearUnusedSlots —
  -- else e.g. a live F5->ACTIONBUTTON5 survives a profile captured before that binding, and
  -- the result is the union of both sets rather than the profile the user asked to import.
  local wanted = {}
  for _, b in ipairs(binds) do
    if b.key1 then wanted[b.key1] = true end
    if b.key2 then wanted[b.key2] = true end
  end
  for i = 1, GetNumBindings() do
    local _, _, key1, key2 = GetBinding(i)
    for _, key in ipairs({ key1, key2 }) do
      if key and not wanted[key] then SetBinding(key) end  -- SetBinding(key) with no command unbinds it
    end
  end

  for _, b in ipairs(binds) do
    for _, key in ipairs({ b.key1, b.key2 }) do
      if key then
        local ctx = 1
        if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
          ctx = C_KeyBindings.GetBindingContextForAction(b.command)
        end
        SetBinding(key, b.command, ctx)
      end
    end
  end
  SaveBindings(GetCurrentBindingSet())
end

local function RestorePetBar(petslots)
  if not IsPetActive() then return end
  -- Re-scan the token slots for each placement: placing a token swaps the two
  -- slots' contents, so a name->slot map built once goes stale across placements
  -- and would move the wrong token.
  local function tokenSlot(name)
    for i = 1, NUM_PET_ACTION_SLOTS do
      local n, _, isToken = GetPetActionInfo(i)
      if isToken and n == name then return i end
    end
  end
  for _, p in ipairs(petslots) do
    if p.type == "token" then
      local from = tokenSlot(p.strindex)
      if from then
        PickupPetAction(from)
        PickupPetAction(p.id)
      end
    elseif p.type == "spell" and PickupPetSpell then
      -- Guard PickupPetSpell (absent on some clients) so both calls are gated
      -- together — otherwise PickupPetAction places an empty cursor over the slot.
      PickupPetSpell(p.index)
      PickupPetAction(p.id)
    end
    ClearCursor()
  end
end

-- Clear slots not in the restored profile; skips bars excluded by barFilter.
local function ClearUnusedSlots(slots, barFilter)
  local used = {}
  for _, s in ipairs(slots) do used[s.id] = true end
  for i = 1, MAX_BARS do
    if not used[i] and GetActionInfo(i) then
      local bar = math.floor((i - 1) / 12) + 1
      if not barFilter or barFilter[bar] ~= false then
        PickupAction(i)
        ClearCursor()
      end
    end
  end
end

---Apply a profile to the current character.
---@param profile table
---@param include table  keys: bars, bindings, macros, petbar, outfits
---@param silent boolean?  suppress the "Bars restored." confirmation
---@param barFilter table?  map of internal bar numbers (1-15, slot id = (bar-1)*12+n) to bool;
---  nil/true = restore, false = skip (the bar is left untouched, including the clear pass)
function ns.Restore(profile, include, silent, barFilter)
  if InCombatLockdown() then
    ns.Print("Cannot restore during combat.")
    return
  end
  local overrides, flyouts = BuildSpellbookMaps()

  local slots = profile.slots or {}
  if barFilter then
    local filtered = {}
    for _, s in ipairs(slots) do
      if barFilter[math.floor((s.id - 1) / 12) + 1] ~= false then
        filtered[#filtered + 1] = s
      end
    end
    slots = filtered
  end

  -- Flyouts FIRST (see RestoreFlyouts), then macros so macro slots resolve,
  -- then the remaining slots; never reorder these passes.
  if include.bars    then RestoreFlyouts(slots, flyouts) end
  if include.macros  then RestoreMacrosAndSlots(profile.macros or {}, slots) end
  if include.bars    then
    RestoreSlots(slots, overrides)
    ClearUnusedSlots(slots, barFilter)
  end
  if include.bindings then RestoreBindings(profile.binds or {}) end
  if include.petbar   then RestorePetBar(profile.petslots or {}) end
  -- outfits: equipment sets are account-wide; names in profile just confirm they exist
  if not silent then ns.Print("Bars restored.") end
end
