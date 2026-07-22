---@type Warbandeer_Collected
local ns = select(2, ...)
local C_Timer = C_Timer
local DressingRoom = ns.DressingRoom
local SAVE_RETRIES = 10  -- capped re-checks while item data streams (0.3s apart, ~3s total)

-- What the outfit row's buttons do. Split from controls/DressingRoomOutfits.lua (which builds the
-- row and owns its widgets) purely for file size. Reopens the DressingRoom class.
--
-- **The row drives the account-wide LIBRARY (#655), not the game's custom sets.** The game's store
-- is per-character — measured 2026-07-22, a set saved on one alt is invisible on another — so it
-- can't hold a look you want everywhere. `outfitlibrary.lua` keeps those in our own SavedVariables
-- instead, and `PushOutfit` is the one bridge across: it copies the selected look into *this*
-- character's custom sets, which is the only place that needs Blizzard's name filter and 25-set
-- cap (both enforced by `ns.SaveCustomSet` in outfit.lua).

---Load a saved look from the library, switching the room into outfit mode.
---@param name string  a library outfit name
function DressingRoom:LoadOutfit(name)
  local list, err = ns.LibraryOutfitList(name)
  if not list then
    ns.Print("Couldn't read that look: " .. err)
    return
  end
  self._outfitSel = name
  self._outfitName:Text(name)
  -- Stored by NAME, not by id: the library is account-wide, so the key has to be too. (`db.
  -- lastOutfit` from #642 holds a per-character custom set id and is left alone — old keys are
  -- never repurposed, and a rollback still has to find what it wrote.)
  if ns.db then ns.db.lastLibraryOutfit = name end
  self:EnterOutfitMode(name, list)
end

---Save the composed look into the library.
---
---The dropdown decides, as it did for custom sets: a selected look is overwritten in place, and
---"+ New Look" saves under the typed name. Saving a *new* look over a name that already exists
---asks first, through the row's arm-then-confirm.
---@param retry boolean?  internal: true on the self-scheduled re-run while item data streams
function DressingRoom:SaveOutfit(retry)
  if not retry then
    -- Whether the overwrite question has already been answered: clicking the ARMED button keeps
    -- the answer, clicking an unarmed one starts fresh. Held in a field so the retry chain below
    -- carries it. Also resets the retry budget and drops a pending retry.
    self._saveArmed = self._armed == self._outfitSave
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
  -- Item data still streaming means `ComposeOutfit` can't resolve every slot yet — `ns.SourceSlot`
  -- needs `GetItemInfoInstant`, and a slot it can't place is simply absent from the list. Saving
  -- then would store a quietly incomplete look, so wait it out on the same capped-retry timer the
  -- slot icons use rather than making the user click Save again. (The command form deliberately
  -- doesn't retry — a scripted call is one-shot and can just be re-run.)
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

  local target, overwrote = self._outfitSel, self._outfitSel ~= nil
  if not target then
    local name = self:_typedOutfitName()
    -- Creating over a name already in the library: OFFER to replace it rather than refusing, the
    -- same question Blizzard's own save prompt asks — typing an existing name almost always means
    -- "replace that one".
    if ns.LibraryOutfit(name) then
      if not self._saveArmed then
        self:_armOutfit(self._outfitSave, "Overwrite?")
        return
      end
      overwrote = true
    end
    target = name
  end

  local ok, err = ns.SaveLibraryOutfit(target, list)
  if not ok then
    ns.Print("Couldn't save: " .. err)
    return
  end
  self._outfitSel = target
  self:RefreshOutfits()
  ns.Print((overwrote and "Replaced \"%s\"." or "Saved \"%s\" to your library."):format(target))
end

---Rename the selected look to whatever is in the name field.
function DressingRoom:RenameOutfit()
  self:_disarmOutfit()
  if not self._outfitSel then
    ns.Print("Pick a saved look to rename.")
    return
  end
  local newName = self:_typedOutfitName()
  local ok, err = ns.RenameLibraryOutfit(self._outfitSel, newName)
  if not ok then
    ns.Print("Couldn't rename: " .. err)
    return
  end
  self._outfitSel = newName
  if ns.db and ns.db.lastLibraryOutfit then ns.db.lastLibraryOutfit = newName end
  self:RefreshOutfits()
  ns.Print(("Renamed to \"%s\"."):format(newName))
end

---Delete the selected look. Arms first — the second click inside CONFIRM_S commits.
function DressingRoom:DeleteOutfit()
  local armed = self._armed == self._outfitDelete
  self:_disarmOutfit()
  if not self._outfitSel then
    ns.Print("Pick a saved look to delete.")
    return
  end
  if not armed then
    self:_armOutfit(self._outfitDelete, "Confirm?")
    return
  end
  ns.DeleteLibraryOutfit(self._outfitSel)
  self._outfitSel = nil
  self._outfitName:Text("")
  self:RefreshOutfits()
  ns.Print("Deleted.")
end

---Copy the selected look into **this character's** transmog sets, so it can be worn at a
---transmogrifier. The bridge between our account-wide library and the game's per-character store;
---an existing set of the same name is replaced after asking.
function DressingRoom:PushOutfit()
  local armed = self._armed == self._outfitPush
  self:_disarmOutfit()
  if not self._outfitSel then
    ns.Print("Pick a saved look to push.")
    return
  end
  local list, err = ns.LibraryOutfitList(self._outfitSel)
  if not list then
    ns.Print("Couldn't read that look: " .. err)
    return
  end
  local existing
  for _, s in ipairs(ns.CustomSets()) do if s.name == self._outfitSel then existing = s.id end end
  if existing and not armed then
    self:_armOutfit(self._outfitPush, "Replace?")
    return
  end
  -- `ns.SaveCustomSet` is where Blizzard's rules bite: the name filter and the 25-set cap apply to
  -- their store, never to ours.
  local id, saveErr = ns.SaveCustomSet(self._outfitSel, list, existing)
  if not id then
    ns.Print("Couldn't push: " .. saveErr)
    return
  end
  ns.Print(("Pushed \"%s\" to this character's transmog sets."):format(self._outfitSel))
end
