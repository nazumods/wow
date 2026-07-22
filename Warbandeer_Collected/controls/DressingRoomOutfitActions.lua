---@type Warbandeer_Collected
local ns = select(2, ...)
local C_Timer = C_Timer
local DressingRoom = ns.DressingRoom
local SAVE_RETRIES = 10  -- capped re-checks while item data streams (0.3s apart, ~3s total)

-- What the outfit row's buttons actually do: load a saved custom set into the room, and write the
-- composed look back out. Split from controls/DressingRoomOutfits.lua (which builds the row and
-- owns its widgets) purely for file size; the store wrappers and validation are outfit.lua, and
-- the same paths are driven from chat by outfitcommands.lua. Reopens the DressingRoom class.

---Load a saved custom set into the room, switching it into outfit mode.
---@param customSetID number
function DressingRoom:LoadOutfit(customSetID)
  local list = ns.CustomSetOutfit(customSetID)
  if not list then
    ns.Print("That saved set couldn't be read.")
    return
  end
  local name
  for _, s in ipairs(ns.CustomSets()) do if s.id == customSetID then name = s.name end end
  self._outfitID = customSetID
  self._outfitName:Text(name or "")
  if ns.db then ns.db.lastOutfit = customSetID end
  self:EnterOutfitMode(name or "Outfit", list)
end
---Save the composed look: overwrite the selected set, or create one when "+ New Custom Set" is
---picked. Two conditions ask before writing — slots this character can't collect (the game drops
---them silently) and a name that's already taken — each acknowledged independently, so a look
---that trips both is asked both questions rather than having the second answered by accident.
---@param retry boolean?  internal: true on the self-scheduled re-run while item data streams
function DressingRoom:SaveOutfit(retry)
  if not retry then
    -- A click on an UNARMED Save is a fresh attempt, so forget what was previously acknowledged;
    -- clicking the armed button keeps them, which is what turns the arm into an answer. Also
    -- resets the streaming budget and drops any retry still pending from an earlier click.
    if self._armed ~= self._outfitSave then wipe(self._saveAck) end
    self._saveRetries = 0
    self:_disarmOutfit()
    if self._saveTimer then self._saveTimer:Cancel(); self._saveTimer = nil end
  end

  local list = self:ComposeOutfit()
  local issues = ns.OutfitIssues(list)
  if issues.filled == 0 then
    ns.Print("Nothing to save — the preview is empty.")
    return
  end
  -- `PlayerCanCollectSource` can't answer while item data is still streaming, and writing from a
  -- half-known answer risks silently dropping slots. Wait it out on the same capped-retry timer
  -- the slot icons use, rather than making the user click Save a second time. (The command form
  -- deliberately doesn't retry — a scripted call is one-shot and can simply be re-run.)
  if issues.pending then
    if self._saveRetries >= SAVE_RETRIES then
      ns.Print("Item data is still loading — try again in a moment.")
      return
    end
    if self._saveRetries == 0 then
      ns.Print("Item data is still loading — saving as soon as it arrives.")
    end
    self._saveRetries = self._saveRetries + 1
    self._saveTimer = C_Timer.NewTimer(0.3, function()
      self._saveTimer = nil
      self:SaveOutfit(true)
    end)
    return
  end
  -- `unusable` is armour-type/class/faction validity, NOT ownership: an appearance you simply
  -- haven't collected saves fine. This fires when the look was composed from another class's set.
  if #issues.unusable > 0 and not self._saveAck.unusable then
    self._saveAck.unusable = true   -- the arm IS the question; the next click is the answer
    local names = {}
    for i, slotID in ipairs(issues.unusable) do names[i] = ns.SlotLabel(slotID) end
    ns.Print(("%d of %d slots can't be collected by this character and will be dropped: %s")
      :format(#issues.unusable, issues.filled, table.concat(names, ", ")))
    self:_armOutfit(self._outfitSave, "Save anyway?")
    return
  end

  -- **The dropdown decides**, mirroring Blizzard's own row: a saved set selected means overwrite
  -- it, "+ New Custom Set" means create with the typed name. Deliberately NOT "a changed name
  -- means save-as" — that rule was invisible, and it left the name field doing two jobs. While a
  -- set is selected the field belongs to Rename, and `SaveCustomSet` ignores it when given an id.
  local name = self:_typedOutfitName()
  local overwrite, overwriteName = self._outfitID, nil
  if overwrite then
    for _, s in ipairs(ns.CustomSets()) do if s.id == overwrite then overwriteName = s.name end end
  else
    -- Creating with a name that's already taken: OFFER to overwrite that set rather than refusing.
    -- Typing an existing name almost always means "replace that one", and a flat rejection just
    -- makes the user retype it. Blizzard's own prompt asks the same question; this asks it through
    -- the row's existing arm-then-confirm instead of a modal.
    for _, s in ipairs(ns.CustomSets()) do
      if s.name == name then
        if not self._saveAck.duplicate then
          self._saveAck.duplicate = true
          self:_armOutfit(self._outfitSave, "Overwrite?")
          return
        end
        overwrite, overwriteName = s.id, s.name
      end
    end
  end

  local id, err = ns.SaveCustomSet(name, list, overwrite)
  if not id then
    ns.Print("Couldn't save: " .. err)
    return
  end
  self._outfitID = id
  -- The field is deliberately left as the user typed it: an overwrite doesn't touch names, so
  -- resetting it here would destroy a name they were part-way through entering for Rename.
  self:RefreshOutfits()
  ns.Print(overwrite and ("Overwrote \"%s\"."):format(overwriteName or "set")
    or ("Saved \"%s\"."):format(name))
end

---Rename the selected set to whatever is in the name field.
function DressingRoom:RenameOutfit()
  self:_disarmOutfit()
  if not self._outfitID then
    ns.Print("Pick a saved set to rename.")
    return
  end
  local ok, err = ns.RenameCustomSet(self._outfitID, self:_typedOutfitName())
  if not ok then
    ns.Print("Couldn't rename: " .. err)
    return
  end
  self:RefreshOutfits()
  ns.Print(("Renamed to \"%s\"."):format(self:_typedOutfitName()))
end

---Delete the selected set. Arms first — the second click inside CONFIRM_S commits.
function DressingRoom:DeleteOutfit()
  local armed = self._armed == self._outfitDelete
  self:_disarmOutfit()
  if not self._outfitID then
    ns.Print("Pick a saved set to delete.")
    return
  end
  if not armed then
    self:_armOutfit(self._outfitDelete, "Confirm?")
    return
  end
  ns.DeleteCustomSet(self._outfitID)
  self._outfitID = nil
  self._outfitName:Text("")
  self:RefreshOutfits()
  ns.Print("Deleted.")
end
