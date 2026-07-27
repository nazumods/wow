---@type Warbandeer_Collected
local ns = select(2, ...)

-- The outfit VERBS as rules rather than as button handlers (#770 step 8): what a verb decides,
-- separated from how a surface asks and reports it. The dressing room's outfit row and the outfit
-- library's verb pane had byte-identical copies of the whole of Push, chat strings included.
--
-- **Why a rule and not a shared method:** these are the write paths for an account-wide,
-- user-authored store with no undo, and the two surfaces reach them through different chrome. The
-- decision — does this replace something, may it proceed, what should be said — is the part worth
-- testing, and it is testable here because nothing in this file touches a frame.
--
-- `ns.CustomSets` / `ns.SaveCustomSet` are resolved at CALL time, never captured at load, exactly as
-- `outfitsave.lua` resolves its savers: that is what lets a spec stub them (see spec/collected.lua).
--
-- **Not merged, deliberately:** the post-commit refresh each surface does. The room re-points a
-- `FilterDropdown` and greys its buttons; the window repaints a `VirtualList` and re-dresses a
-- preview model. That difference is real and stays per-surface.

---@class PushResult
---@field needsConfirm boolean?  a same-named set exists and the caller hasn't confirmed yet
---@field ok boolean?  the push landed
---@field message string  what to print, already formatted

---@class Warbandeer_Collected
---@field PushLookToCharacter fun(name: string, confirmed: boolean?): PushResult

---Copy a library look into **this character's** transmog sets — the one bridge from our
---account-wide store to the game's per-character one, and the only path where Blizzard's name
---filter and 25-set cap apply (both enforced inside `ns.SaveCustomSet`).
---
---Replacing a same-named set asks first: the caller arms, then calls again with `confirmed`.
---
---**The existing-set scan is case-insensitive (#770 step 8, decided rather than inherited).** It
---was an exact match, while the library's own lookup has been case-insensitive since #728 — so
---pushing `boylane 3` beside a set already called `Boylane 3` created a SECOND character set
---differing only in case, in a store capped at 25. The replaced set takes the library's spelling,
---which is the same rule #728 settled for the library: the stored name is the canonical one, and
---the look being pushed is that entry.
---@param name string  a library outfit name, already resolved to its stored spelling
---@param confirmed boolean?  true when the caller has taken the replace confirmation
---@return PushResult
function ns.PushLookToCharacter(name, confirmed)
  local list, err = ns.LibraryOutfitList(name)
  if not list then
    return { message = "Couldn't read that look: " .. err }
  end

  local existing
  local wanted = name:lower()
  for _, s in ipairs(ns.CustomSets()) do
    if s.name:lower() == wanted then existing = s.id end
  end

  if existing and not confirmed then
    -- Says WHAT is at risk, because the armed caption can't: it is a bare `Sure?` with the seconds
    -- counting in it, and a 62px button has no room for a name.
    return {
      needsConfirm = true,
      message = ("\"%s\" is already one of this character's sets — click Push again to replace it.")
        :format(name),
    }
  end

  local id, saveErr = ns.SaveCustomSet(name, list, existing)
  if not id then
    return { message = "Couldn't push: " .. saveErr }
  end
  return { ok = true, message = ("Pushed \"%s\" to this character's transmog sets."):format(name) }
end
