---@class Warbandeer_Collected: AddOn
---@field OnPtr fun(ptrBuild: string?): boolean  is the running client the PTR build a preview targets?
local ns = LibNAddOn(...)

-- Is the running client at or past the PTR build a preview was generated for? IsTestBuild() is
-- unreliable (a PTR reports false on 12.1.0), so compare the client's version + build to the data's
-- `ptr` stamp component-wise (major.minor.patch.build) with `>=`: on that PTR — or a newer build of
-- it — the "upcoming" content is live, so the grids show real counts; a live client is a lower version,
-- so it shows a muted dot. `ptrBuild` is ns.WeaponPtrBuild.ptr / ns.PtrBuild.ptr ("12.1.0.68914").
---@param ptrBuild string?
---@return boolean
function ns.OnPtr(ptrBuild)
  if not ptrBuild then return false end
  local ver, build = GetBuildInfo()   -- "12.1.0", "68914"
  local function nums(s) local t = {} for n in tostring(s):gmatch("%d+") do t[#t + 1] = tonumber(n) end return t end
  local client, data = nums(ver .. "." .. build), nums(ptrBuild)
  for i = 1, math.max(#client, #data) do
    local c, d = client[i] or 0, data[i] or 0
    if c ~= d then return c > d end
  end
  return true   -- identical build → at the PTR
end

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
  if not db.outfits then db.outfits = {} end   -- { { name, look, char, class, forClass, armor }, ... }
  -- v9: the outfit library window's remembered position (#662), same shape as the two above. Its
  -- FILTERS are deliberately not persisted — a filter still applied after a /reload would look
  -- like a library that had lost looks, which is the one impression this window must never give.
  if not db.libraryPos then db.libraryPos = {} end   -- outfit library window
  db.version = 9
end
