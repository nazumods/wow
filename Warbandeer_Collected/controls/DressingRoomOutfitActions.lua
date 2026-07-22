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
  local name, realm = UnitFullName("player")
  local _, class = UnitClass("player")
  -- `_classIndex` is the class column of the last set clicked in the GRID, which in outfit mode is
  -- not what's on the model — so re-saving a loaded look there would relabel it with an unrelated
  -- class. Carry the entry's own `forClass` instead; only a real set preview derives a fresh one.
  local forClass
  if self._outfit then
    local entry = self._outfitSel and ns.LibraryOutfit(self._outfitSel)
    forClass = entry and entry.forClass
  elseif self._classIndex then
    forClass = select(2, GetClassInfo(self._classIndex))
  end
  return {
    char = realm and realm ~= "" and (name .. "-" .. realm) or name,
    class = class,
    forClass = forClass,
    armor = ns.OutfitArmorType(list),
  }
end

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
  local origin = ns.OutfitOrigin(ns.LibraryOutfit(name))
  ns.Print(origin ~= "" and ("Loaded \"%s\" — saved by %s."):format(name, origin)
    or ("Loaded \"%s\"."):format(name))
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
  local overwrote = ns.LibraryOutfit(target) ~= nil
  -- Replacing the entry you have selected needs no confirmation — that's plainly "update this".
  -- Landing on a DIFFERENT existing entry is the surprising case, so ask first.
  if overwrote and target ~= self._outfitSel and not self._saveArmed then
    -- The caption stays SHORT — a row button is 62px and wraps, so naming the target there spilled
    -- over three lines and out of the box. Chat has the width to say which look is at risk.
    ns.Print(("\"%s\" already exists — click Save again to replace it."):format(target))
    self:_armOutfit(self._outfitSave, "Replace?")
    return
  end

  local ok, err = ns.SaveLibraryOutfit(target, list, self:_outfitMeta(list))
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
