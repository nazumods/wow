---@type Warbandeer_Collected
local ns = select(2, ...)

-- Saving one composed look into BOTH stores (#699) — the account-wide library and this character's
-- game custom sets — which is what the transmogrifier's "Save Look" button does in a single click.
--
-- **The library is the primary half, and the game set is best-effort.** Blizzard's store is
-- per-character, name-filtered and capped at 25; ours is account-wide and has none of those limits.
-- So a look that can't become a custom set (cap reached, name rejected, name already taken by a
-- different set) must still reach the library — the durable half cannot be held hostage to the
-- per-character one. Only a failed LIBRARY write makes the whole save a failure.
--
-- An existing custom set of the same name is deliberately **not** overwritten: `ns.SaveCustomSet`
-- refuses a name already taken by a different set, and that refusal is reported rather than worked
-- around. Replacing a set the user built in Blizzard's own UI is not something a one-click save
-- should do silently.
--
-- Pure Lua over other `ns` functions — `ns.LibraryOutfit`, `ns.SaveLibraryOutfit` and
-- `ns.SaveCustomSet`, with no C_ call or frame of its own — which is what lets the whole rule be
-- unit-tested (spec/outfitsave_spec.lua), not just the wording it ends up printing.

---@class SaveLookResult
---@field saved boolean         the library entry was written — the save as a whole succeeded
---@field replaced boolean      it replaced a library entry that was already there
---@field customSetID number?   the game custom set written, when one was
---@field customSetErr string?  why no game custom set was written
---@field message string        the single line to report

---@class Warbandeer_Collected
---@field SaveLookToBoth fun(name: string, list: table[], meta: table?): SaveLookResult

---Save `list` under `name` into the account-wide library, then — best-effort — into this
---character's game custom sets.
---
---The caller is responsible for having asked about replacing an existing library entry: this
---replaces in place without prompting, and only reports which of the two it did.
---@param name string
---@param list table[]
---@param meta table?  provenance, as ns.SaveLibraryOutfit takes it
---@return SaveLookResult
function ns.SaveLookToBoth(name, list, meta)
  -- Read before writing — afterwards there is always an entry, so "was one already there" is only
  -- answerable now. It decides Saved vs Replaced in the report, nothing more.
  local replaced = ns.LibraryOutfit(name) ~= nil

  local ok, err = ns.SaveLibraryOutfit(name, list, meta)
  if not ok then
    -- The game set is not attempted: whatever made the library refuse (an empty name, most likely)
    -- would refuse there too, and reporting one failure beats reporting two of the same thing.
    return { saved = false, replaced = false, message = "Couldn't save: " .. tostring(err) }
  end

  local customSetID, customSetErr = ns.SaveCustomSet(name, list)
  local lead = (replaced and "Replaced \"%s\" in your library" or "Saved \"%s\" to your library")
    :format(name)

  if customSetID then
    return {
      saved = true, replaced = replaced, customSetID = customSetID,
      message = lead .. " and this character's transmog sets.",
    }
  end

  local why = customSetErr or "the game refused it"
  return {
    saved = true, replaced = replaced, customSetErr = why,
    message = ("%s. It isn't in this character's transmog sets: %s"):format(lead, why),
  }
end
