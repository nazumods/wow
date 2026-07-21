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
  db.version = 5
end
