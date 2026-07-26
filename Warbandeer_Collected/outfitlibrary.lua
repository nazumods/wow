---@type Warbandeer_Collected
local ns = select(2, ...)

-- The **outfit library** (#655): looks saved into our own account-wide SavedVariables, so a
-- transmog composed on one character is available on every character.
--
-- Why this exists at all: the game's custom sets are **per-character**. Measured 2026-07-22 — the
-- five sets created on one alt were absent on another, and `id 0` resolved to a different set on
-- each. So `C_TransmogCollection`'s store, which controls/DressingRoomOutfitActions.lua writes,
-- can't move a look between characters; only the `/customset` string could, by hand. This is that
-- workaround made automatic.
--
-- Pure Lua over `ns.db` and the codec — no `C_*` calls, no frames — so it is **unit-tested**
-- (spec/outfitlibrary_spec.lua), unlike the rest of the outfit chain.
--
-- Entries store the **encoded `/customset v1 …` string**, not the list:
--
--   db.outfits = { { name = "Rootwarden", look = "v1 298102,…" }, … }
--
-- One line per outfit; no schema of our own to migrate as the wire format is already versioned;
-- the codec is reused unchanged; and every stored outfit *is* its own export. An array rather than
-- a name-keyed map so insertion order is stable (the order the dropdown shows) and rename is a
-- field write rather than a re-key.
--
-- Names are validated only for non-empty + unique — **uniqueness ignoring case** (#728), matched
-- loosely and stored exactly; see `ns.LibraryOutfit`. Deliberately NOT `IsValidCustomSetName`:
-- that's a C call, it would cost this file its testability, and Blizzard's name rules govern
-- *their* store — they apply when pushing a look across, not to ours.
--
-- The filter the library window runs over these entries is outfitfilter.lua, split off for file
-- size; it stays pure for the same reason this does.

---@class LibraryOutfit
---@field name string  the user's name for it, unique within the library
---@field look string  the `/customset v1 …` encoding of the outfit
---@field char string?  "Name-Realm" of whoever saved it
---@field class string?  that character's class file ("DRUID") — provenance, NOT what the look is for
---@field forClass string?  class file of the SET the look was composed from ("WARRIOR")
---@field armor string?  armour type the look's pieces are ("Leather"), or "Any"

---@class OutfitMeta
---@field char string?
---@field class string?
---@field forClass string?
---@field armor string?

---@class Warbandeer_Collected
---@field LibraryOutfits fun(): LibraryOutfit[]
---@field LibraryOutfit fun(name: string): LibraryOutfit?, number?
---@field OnLibraryChanged fun(fn: fun())
---@field LibraryChanged fun()
---@field LibraryBatch fun(fn: fun())
---@field ImportLibraryOutfit fun(name: string, list: table[], meta: OutfitMeta?): string, string
---@field LibraryOutfitList fun(name: string): table[]?, string?
---@field SaveLibraryOutfit fun(name: string, list: table[], meta: OutfitMeta?): boolean, string?
---@field RenameLibraryOutfit fun(oldName: string, newName: string): boolean, string?
---@field DeleteLibraryOutfit fun(name: string): boolean

-- The provenance fields a save records. Captured at save time because none of it can be recovered
-- later: the encoded look carries appearance ids and nothing about where it came from.
local META = { "char", "class", "forClass", "armor" }

-- Trim, so a name that's only whitespace reads as empty and " x " and "x" can't both exist.
---@param name string?
---@return string
local function clean(name)
  return (name or ""):match("^%s*(.-)%s*$")
end

-- Non-empty and not already taken by a DIFFERENT entry (`except` lets a rename keep its own name).
-- Returns nil when the name is fine, else the message to show. Mirrors `nameError` in outfit.lua,
-- but over our store and without the C-side filter.
--
-- The exemption is by ENTRY IDENTITY, not by name, because the lookup below is case-insensitive
-- (#728): renaming "Boylane 3" to "boylane 3" finds itself, and correcting your own capitalisation
-- has to stay a legal rename rather than read as a collision with a look that isn't there. The
-- message names the STORED entry, so a rejected rename says which look is in the way even when
-- what was typed doesn't look like it.
---@param name string
---@param except LibraryOutfit?  the entry being renamed
---@return string?
local function nameError(name, except)
  if name == "" then return "a name is required" end
  local taken = ns.LibraryOutfit(name)
  if taken and taken ~= except then
    return ("\"%s\" is already in the library"):format(taken.name)
  end
end

---Every saved look, in the order they were added.
---
---**Creates and attaches the store when it's missing (#766)** rather than handing back a throwaway
---table. `MigrateDB` seeds `db.outfits` only on a version mismatch, so a SavedVariables truncation
---landing after `version` but before `outfits` — a known retail crash mode — left a version that
---matched and no store. Every save then appended to a temporary that was dropped on return, printed
---success, and showed an empty library: to the user that reads as "the addon lost everything", not
---"the addon can't write", so they keep saving into the void.
---
---The `ns.db` guard remains for the pre-init call, which has nothing to attach to. That is the one
---case still returning a throwaway, and `SaveLibraryOutfit` refuses outright rather than write into
---it.
---@return LibraryOutfit[]
function ns.LibraryOutfits()
  local db = ns.db
  if not db then return {} end
  db.outfits = db.outfits or {}
  return db.outfits
end

---Find a saved look by name, with its index. nil when there's no such entry.
---
---**Case-insensitive, with exact matches winning (#728).** A name is a display string the user
---types into a field beside a dropdown that shows it, so `boylane 3` means the `Boylane 3` on
---screen. Matching exactly let a case variant slip past every guard built on this function — the
---row's overwrite confirm, rename's collision check, the transmogrifier's replace popup — each of
---which exists specifically to stop an accidental duplicate, and the result was a second entry
---indistinguishable from the first at a glance.
---
---Matching loosely while STORING what was typed is the split that matters: names are class-coloured
---in the dropdown and printed by `/collected outfit list`, so folding their case would be lossy.
---Callers that mean "the look the user named" therefore take `entry.name` back from here rather
---than reusing the string they passed in.
---
---The exact pass runs first, and wins over an earlier case variant, so a library that already holds
---both — legal until now — still resolves each name to its own entry.
---@param name string
---@return LibraryOutfit? entry, number? index
function ns.LibraryOutfit(name)
  name = clean(name)
  if name == "" then return nil end
  local lowered = name:lower()
  local loose, looseIndex
  for i, o in ipairs(ns.LibraryOutfits()) do
    if o.name == name then return o, i end
    if not loose and o.name:lower() == lowered then loose, looseIndex = o, i end
  end
  return loose, looseIndex
end

---A saved look decoded back into an outfit list, ready for `DressingRoom:ApplyOutfit`.
---
---Returns the decoder's own error rather than a partial list when the stored string is unreadable
---— a hand-edited SavedVariables file shouldn't dress the model with half an outfit.
---@param name string
---@return table[]? list, string? err  exactly one is non-nil
function ns.LibraryOutfitList(name)
  local entry = ns.LibraryOutfit(name)
  if not entry then return nil, ("no saved look named \"%s\""):format(clean(name)) end
  return ns.DecodeOutfit(entry.look)
end

---Save `list` under `name`, replacing an entry of the same name in place.
---
---Replacing in place rather than removing and appending keeps the library's order stable: re-saving
---the third look leaves it third instead of jumping to the end. `meta` (who saved it, which class,
---which set's class, the armour type) overwrites the stored provenance on a replace — the entry now
---holds a different look, so the old attribution would be a lie. Passing **no** meta is the one
---exception: it says the caller has nothing to record, and leaves what's stored (#758).
---
---**A replaced entry keeps its own name**, which is what makes the case-insensitive match (#728)
---non-lossy: saving `boylane 3` over `Boylane 3` replaces that look and leaves it called
---`Boylane 3`. The name is a display string the store has no business re-capitalising on a save
---the user asked to be a replacement; `ns.RenameLibraryOutfit` is how a name changes.
---@param name string
---@param list table[]
---@param meta OutfitMeta?  provenance; the caller collects it, this file just stores it
---@return boolean ok, string? err
function ns.SaveLibraryOutfit(name, list, meta)
  name = clean(name)
  if name == "" then return false, "a name is required" end
  -- Refuse rather than write into a throwaway (#766). `LibraryOutfits` attaches the store whenever
  -- there is a db to attach it to, so this is only the pre-init call — but reporting a save that
  -- went nowhere is the whole defect, and `false` is the one answer a caller can act on.
  if not ns.db then return false, "the outfit library isn't loaded yet" end
  local entry = ns.LibraryOutfit(name)
  if not entry then
    entry = { name = name }
    local outfits = ns.LibraryOutfits()
    outfits[#outfits + 1] = entry
  end
  entry.look = ns.EncodeOutfit(list)
  -- A supplied `meta` is the whole truth and replaces all four, INCLUDING nil-ing the ones it
  -- leaves out — an absent `forClass` means "this look isn't for a class", not "keep the old one".
  -- No meta at all means the caller has nothing to record, which leaves the stored provenance
  -- alone rather than erasing it (#758): nil-ing it was silent and unrecoverable, and a look with
  -- no `armor`/`forClass` reads to `ns.FilterOutfits` as "unknown, matches everything", so a wiped
  -- entry turned up under every armour and class filter.
  if meta then
    for _, field in ipairs(META) do entry[field] = meta[field] end
  end
  ns.LibraryChanged()
  return true
end

---Add `list` to the library under `name` **without ever replacing an existing entry** — the write
---path for importing the game's own per-character transmog sets (#663), where the incoming names
---are not the user's to choose and will collide across characters.
---
---Three outcomes, and the middle one is what makes re-importing a character safe:
---
---| the name is | and | result |
---|---|---|---|
---| free | — | saved under it (`"saved"`) |
---| taken | by the **same look** | left alone (`"skipped"`) — it is already in the library |
---| taken | by a **different** look | saved as `name (2)`, `(3)`… (`"renamed"`) |
---
---Comparing the ENCODED look rather than the name is what earns this its complexity. The realistic
---use is running an import on each of a dozen alts, and re-running it on one already done: a
---name-only rule would either spawn `TWW 1 (2)`, `(3)`, `(4)` on every pass, or silently drop a
---genuinely different `TWW 1` that another character happened to name the same. The suffix scan
---applies the same test, so an import stays idempotent even after one collision has renamed it.
---
---Never replaces, never deletes — the library is account-wide and its entries may predate any
---character being imported from.
---@param name string  the set's own name; assumed non-empty (`ns.CustomSets` substitutes one)
---@param list table[]
---@param meta OutfitMeta?
---`"failed"` is the fourth outcome, and exists because the write can be refused: the name is
---**assumed** non-empty, but `ns.CustomSets` only substitutes for a nil name, so a set the game
---reports as whitespace-only survives to `clean()` and comes back empty. Discarding
---`SaveLibraryOutfit`'s return counted that as `"saved"`, which is how the importer reported
---"Imported 5 of 5 sets" with four in the library (#767 L-6).
---@return string status  "saved" | "skipped" | "renamed" | "failed"
---@return string name  the name the look actually landed under
function ns.ImportLibraryOutfit(name, list, meta)
  name = clean(name)
  local encoded = ns.EncodeOutfit(list)
  local entry = ns.LibraryOutfit(name)
  if not entry then
    return (ns.SaveLibraryOutfit(name, list, meta) and "saved" or "failed"), name
  end
  if entry.look == encoded then return "skipped", name end
  local n = 2
  while true do
    local candidate = ("%s (%d)"):format(name, n)
    local taken = ns.LibraryOutfit(candidate)
    if not taken then
      return (ns.SaveLibraryOutfit(candidate, list, meta) and "renamed" or "failed"), candidate
    end
    if taken.look == encoded then return "skipped", candidate end
    n = n + 1
  end
end


---Rename a saved look. Keeping its own name is allowed, so re-committing an untouched field isn't
---an error.
---@param oldName string
---@param newName string
---@return boolean ok, string? err
function ns.RenameLibraryOutfit(oldName, newName)
  local entry = ns.LibraryOutfit(oldName)
  if not entry then return false, ("no saved look named \"%s\""):format(clean(oldName)) end
  newName = clean(newName)
  local err = nameError(newName, entry)
  if err then return false, err end
  entry.name = newName
  ns.LibraryChanged()
  return true
end

---Remove a saved look. False when there was nothing by that name.
---@param name string
---@return boolean removed
function ns.DeleteLibraryOutfit(name)
  local _, index = ns.LibraryOutfit(name)
  if not index then return false end
  table.remove(ns.LibraryOutfits(), index)
  ns.LibraryChanged()
  return true
end

-- ── Change notification ────────────────────────────────────────────────────────--
--
-- One place that says "the library changed" (#727). The mutators above used to just mutate and
-- return, so every caller was responsible for refreshing whichever surface it happened to know
-- about — outfitcommands.lua refreshed the outfit row, controls/OutfitLibraryPreview.lua refreshed
-- the library window, and **neither ever refreshed the other**. Since #713 docks both onto the same
-- workspace they are routinely on screen together, so one sat there listing a look the other had
-- just deleted.
--
-- Surfaces subscribe and refresh themselves instead, so a future fourth one is covered by
-- construction and no caller has to know which windows happen to be open. It is the shape the
-- room's own custom-set refresh already has, for the same reason: the store can be edited from
-- somewhere this code isn't watching.
--
-- Both surfaces already handle a selection that vanished — `RefreshOutfits` clears `_outfitSel` and
-- `OutfitLibraryWindow:Refresh` clears `_selected` — they simply never got the chance to run.

local listeners = {}
local depth, pending = 0, false

---Run `fn` after any change to the library. Never unregistered: the subscribers are the dressing
---room and the library window, each created once and kept for the session.
---@param fn fun()
function ns.OnLibraryChanged(fn)
  listeners[#listeners + 1] = fn
end

---Announce that the library changed. The three mutators above call it themselves — **only on a
---write that actually happened**, so a refused save or a delete that found nothing tells nobody.
---Public rather than a file-local because they are defined above it, and because anything that
---ever writes `db.outfits` from outside this file has to be able to say so.
function ns.LibraryChanged()
  if depth > 0 then
    pending = true
    return
  end
  for _, fn in ipairs(listeners) do fn() end
end

---Coalesce every change `fn` makes into a single notification, fired once the outermost batch
---closes. `ImportCharacterSets` writes up to 25 entries in one loop, and a refresh per entry would
---rebuild both surfaces — and re-dress the library window's preview model — 25 times over for one
---click.
---
---Counted rather than a flag so a batch inside a batch still fires once, at the outer close, and
---can't announce a half-finished library.
---
---**The counter is restored even if `fn` throws (#767 L-1).** It previously wasn't: an error
---unwound straight past the decrement and left `depth` at 1 for the rest of the session, after
---which every `LibraryChanged()` only set `pending` and notified nobody — silently reinstating the
---exact bug #727 closed, with no visible cause and nothing to point at. `ImportCharacterSets` runs
---a long chain of `C_*` calls over up to 25 sets inside here, so "`fn` won't throw" was never a
---safe assumption.
---
---The `pcall` restores the counter; it does **not** swallow anything — the error is re-raised at
---level 0 once `depth` is sound, so it still surfaces in-game exactly as before, per the addon's
---no-error-handling rule.
---@param fn fun()
function ns.LibraryBatch(fn)
  depth = depth + 1
  local ok, err = pcall(fn)
  depth = depth - 1
  if depth == 0 and pending then
    pending = false
    ns.LibraryChanged()
  end
  if not ok then error(err, 0) end
end
