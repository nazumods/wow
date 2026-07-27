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

-- Everything a save should remember about where a look came from. Captured now because none of it
-- survives otherwise: the stored string is appearance ids and nothing else.
--
-- `class` and `forClass` are genuinely different and both matter. `class` is whoever pressed Save
-- — provenance. `forClass` is the class of the SET being previewed, which is often someone else
-- entirely (the room previews every class's sets), and is what you'd hunt by when dressing an alt.
---@param list table[]
---@return OutfitMeta
function DressingRoom:_outfitMeta(list)
  -- `char`/`class`/`armor` come from the shared stamper (#770 step 4). They were derived here too,
  -- identically, which is how a save surface ends up with provenance that quietly disagrees with
  -- every other one — the failure mode behind #758. This adds only the field it uniquely can.
  local meta = ns.LocalOutfitMeta(list)
  -- `_classIndex` is the class column of the last set clicked in the GRID, which in outfit mode is
  -- not what's on the model — so re-saving a loaded look there would relabel it with an unrelated
  -- class. Carry the entry's own `forClass` instead; only a real set preview derives a fresh one.
  if self._outfit then
    local entry = self._outfitSel and ns.LibraryOutfit(self._outfitSel)
    meta.forClass = entry and entry.forClass
  elseif self._classIndex then
    meta.forClass = select(2, GetClassInfo(self._classIndex))
  end
  return meta
end

---Load a saved look from the library, switching the room into outfit mode.
---@param name string  a library outfit name
function DressingRoom:LoadOutfit(name)
  local list, err = ns.LibraryOutfitList(name)
  if not list then
    ns.Print("Couldn't read that look: " .. err)
    return
  end
  -- Disarm on the way past, because the line below moves what every armed verb acts on (#715). Here
  -- rather than in the dropdown handler so `/collected outfit load` is covered too — a failed
  -- decode returns above without touching `_outfitSel`, so it correctly leaves an armed verb alone.
  self:_disarmOutfit()
  self._outfitSel = name
  self._outfitName:Text(name)
  self:EnterOutfitMode(name, list)
  local origin = ns.OutfitOrigin(ns.LibraryOutfit(name))
  ns.Print(origin ~= "" and ("Loaded \"%s\" — saved by %s."):format(name, origin)
    or ("Loaded \"%s\"."):format(name))
end

---Drop a save that is waiting on streaming item data, and reset its retry budget.
---
---**Called wherever the thing being saved moves out from under it (#759).** The chain re-reads the
---name field and the selection on every one of its ~10 re-runs rather than holding what it was
---asked to save, so one that outlives its subject rewrites whatever is selected ~3s later — and
---restamps that entry's provenance to the current character. Reached through `ImportOutfit` it
---fires with no selection at all, printing a bare "a name is required" long after the click.
---
---Cancelling belongs at every point the subject moves: `EnterOutfitMode` (both `LoadOutfit` and
---`ImportOutfit` arrive there), the dropdown's "+ New Look" branch, `DeleteOutfit`, the room
---leaving outfit mode, and a fresh `SaveOutfit` superseding the last one. A *failed* load
---deliberately isn't one — it returns without moving the selection, exactly as it leaves an armed
---verb alone (#715).
function DressingRoom:_cancelSaveRetry()
  if self._saveTimer then self._saveTimer:Cancel(); self._saveTimer = nil end
  self._saveRetries = 0
end

---Save the composed look into the library.
---
---The dropdown decides, as it did for custom sets: a selected look is overwritten in place, and
---"+ New Look" saves under the typed name. Saving a *new* look over a name that already exists
---asks first, through the row's arm-then-confirm.
---@param retry boolean?  internal: true on the self-scheduled re-run while item data streams
function DressingRoom:SaveOutfit(retry)
  if not retry then
    -- **WHICH look the overwrite question was answered about (#759)**, or nil for an unarmed click.
    -- A bare "was it armed" boolean answered the wrong question: `target` below is re-read from the
    -- live name field on every entry and on every retry, so retyping the field between the two
    -- clicks turned an arm taken for `Alpha` into silent permission to replace `Beta`. Captured
    -- before the disarm below drops it, and held in a field so the retry chain carries it.
    self._saveArmedFor = ns.ArmedSubject(self, self._outfitSave)
    self:_disarmOutfit()
    self:_cancelSaveRetry()
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

  -- **The typed name decides what gets written**, not the dropdown selection. The field sits right
  -- beside Save and reads as "the name I'm saving under", so selecting one look, typing a different
  -- name and clicking Save must save THAT name — not silently replace the selected entry, which is
  -- destructive and unrecoverable. (An earlier revision followed Blizzard's "selection decides"
  -- rule; that works for them because their name prompt is a separate modal, not a live field.)
  --
  -- An empty field falls back to the selection, so Save still means "update this one" when the
  -- name hasn't been touched.
  local target = self:_typedOutfitName()
  if target == "" then target = self._outfitSel end
  -- **The library's own casing wins over what was typed (#728).** A name differing only in case is
  -- the same look, so taking the stored spelling back makes the rest of this read correctly: the
  -- comparison below recognises the selected entry, the confirm names the look actually at risk,
  -- and `_outfitSel` lands on the string the dropdown lists. Typing `boylane 3` over a saved
  -- `Boylane 3` used to sail past all of it and save a second, near-identical entry.
  local existing = ns.LibraryOutfit(target)
  if existing then target = existing.name end
  local overwrote = existing ~= nil
  -- Replacing the entry you have selected needs no confirmation — that's plainly "update this".
  -- Landing on a DIFFERENT existing entry is the surprising case, so ask first.
  -- The arm has to have been taken for THIS name, not merely taken (#759).
  if overwrote and target ~= self._outfitSel and self._saveArmedFor ~= target then
    -- The caption stays SHORT — a row button is 62px and wraps, so naming the target there spilled
    -- over three lines and out of the box. Chat has the width to say which look is at risk.
    ns.Print(("\"%s\" already exists — click Save again to replace it."):format(target))
    self:_armOutfit(self._outfitSave, "Sure?", "replaced", target)
    return
  end

  local ok, err = ns.SaveLibraryOutfit(target, list, self:_outfitMeta(list))
  if not ok then
    ns.Print("Couldn't save: " .. err)
    return
  end
  -- The write itself already refreshed both surfaces (#727). This second refresh is for the
  -- SELECTION move, which no store change can tell the dropdown about — the same reason Rename's
  -- is there, and why Delete's is gone (the store's own notification drops a vanished selection).
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
  self:RefreshOutfits()
  ns.Print(("Renamed to \"%s\"."):format(newName))
end

---Delete the selected look. Arms first — the second click inside CONFIRM_S commits.
function DressingRoom:DeleteOutfit()
  -- Bound to the look it was armed ABOUT, not merely "was something armed" (#770 step 7 generalises
  -- #759's rule). Moving the dropdown between the two clicks now re-arms for the new look instead of
  -- deleting it on an answer given about a different one.
  local armed = ns.ArmedFor(self, self._outfitDelete, self._outfitSel)
  self:_disarmOutfit()
  -- Deleting the entry a pending save is about to write is the one ordering that loses the delete:
  -- the retry would recreate it seconds later (#759).
  self:_cancelSaveRetry()
  if not self._outfitSel then
    ns.Print("Pick a saved look to delete.")
    return
  end
  if not armed then
    self:_armOutfit(self._outfitDelete, "Sure?", "deleted", self._outfitSel)
    return
  end
  -- No refresh of our own: the store's change notification runs `RefreshOutfits`, which drops the
  -- selection it can no longer find and greys the verbs that needed one (#727).
  ns.DeleteLibraryOutfit(self._outfitSel)
  self._outfitName:Text("")
  ns.Print("Deleted.")
end

---Copy the selected look into **this character's** transmog sets, so it can be worn at a
---transmogrifier. The bridge between our account-wide library and the game's per-character store;
---an existing set of the same name is replaced after asking.
function DressingRoom:PushOutfit()
  local armed = ns.ArmedFor(self, self._outfitPush, self._outfitSel)   -- bound to its subject (#770 step 7)
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
    -- Say WHAT is at risk, as Save does: the armed caption is a bare "Sure?" (the seconds count in
    -- it, leaving no room for a name at 62px), so without this line the question names nothing.
    ns.Print(("\"%s\" is already one of this character's sets — click Push again to replace it.")
      :format(self._outfitSel))
    self:_armOutfit(self._outfitPush, "Sure?", "replaced", self._outfitSel)
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
