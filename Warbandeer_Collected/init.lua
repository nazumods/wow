---@class Warbandeer_Collected: AddOn
local ns = LibNAddOn(...)

---Migrate the saved DB to the current version (non-destructive; seeds missing keys).
function ns:MigrateDB()
  local db = self.db
  if not db.sets then db.sets = {} end
  if not db.collected then db.collected = 0 end
  if not db.total then db.total = 0 end
  -- v3: user-authored set ratings. Kept in their own top-level keys (not under
  -- db.sets, which /collected scan wipes) and keyed by the globally-unique base
  -- setId, so they survive scans and don't depend on the set's group.
  if not db.wanted then db.wanted = {} end       -- [setId] = true   target list
  if not db.rank then db.rank = {} end           -- [setId] = "S".."F"  baseline tier
  if not db.raceRank then db.raceRank = {} end   -- [setId] = { [raceId] = tier }  per-race overrides
  -- v4: remembered window positions, written on drag-stop and restored on open
  -- (shape { point, relPoint, x, y }), so a window doesn't re-center after a
  -- /reload. Seeded empty; populated by TitleFrame:RememberPosition.
  if not db.dressPos then db.dressPos = {} end   -- set-preview (dressing room) window
  if not db.windowPos then db.windowPos = {} end -- main collection window
  -- v5: per-appearance weapon Wanted flags for the Weapons view, keyed by the globally-unique
  -- ItemAppearanceID (visualID). Independent of the set `wanted` table (which is keyed by setId).
  if not db.weaponWanted then db.weaponWanted = {} end   -- [visualID] = true
  -- v6: per-appearance shirt/tabard Wanted flags for the dressing room's cosmetic picker, keyed
  -- by the same globally-unique ItemAppearanceID. Its own table rather than db.weaponWanted so a
  -- wanted shirt never counts as a wanted weapon (#641).
  if not db.cosmeticWanted then db.cosmeticWanted = {} end   -- [visualID] = true
  -- …and the illusion list's, keyed by illusion sourceID instead: illusions have no visualID, and
  -- the two id spaces overlap numerically, so they can't share a table.
  if not db.illusionWanted then db.illusionWanted = {} end   -- [sourceID] = true
  -- v7: the custom set the outfit row last loaded, so the dropdown reopens where it left off.
  -- A plain id (not a table) — the set itself lives in the game's own store, not ours.
  if db.lastOutfit == nil then db.lastOutfit = false end   -- customSetID | false
  -- v8: the account-wide outfit library (#655). The game's own custom sets are PER-CHARACTER
  -- (measured — a set saved on one alt is invisible on another), so a look can only follow you
  -- across characters if we keep it ourselves. Entries hold the `/customset v1 …` encoding.
  if not db.outfits then db.outfits = {} end   -- { { name, look }, ... }
  -- The library entry the row last loaded, by NAME. A separate key from `db.lastOutfit` rather
  -- than a repurposing of it: that one holds a per-character custom set id, and the DB rule is
  -- that old keys are never redefined — a rollback to r22 has to keep finding what it wrote.
  if db.lastLibraryOutfit == nil then db.lastLibraryOutfit = false end   -- outfit name | false
  db.version = 8
end
