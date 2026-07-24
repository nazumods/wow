---@class Warbandeer_Collected
---@field Ranks string[]  ordered tier letters, best → worst
---@field RankIndex table<string, number>  tier letter → its position in ns.Ranks (1 = best)
---@field RankColors table<string, number[]>  tier letter → 0–1 rgb
---@field WantedIcon string  atlas for the "wanted" marker
local ns = select(2, ...)

-- Ordered aesthetic tiers, best → worst. The index doubles as the cycle order for
-- any UI that steps through them.
---@type string[]
ns.Ranks = { "S", "A", "B", "C", "F" }

-- Reverse lookup so a comparison between two tiers is one table read rather than a scan of
-- ns.Ranks (the weapon-cell aggregate below picks the best tier in a bucket on every cell refresh).
---@type table<string, number>
ns.RankIndex = {}
for i, letter in ipairs(ns.Ranks) do ns.RankIndex[letter] = i end

-- Saturated, mutually-distinct tier colors (0–1 rgb). Deliberately NOT the
-- red→green completion gradient (see DataView's `shades`) so a rank pip can never
-- be mistaken for a collection-progress shade.
---@type table<string, number[]>
ns.RankColors = {
  S = { 0.90, 0.30, 0.30 },   -- red
  A = { 0.95, 0.62, 0.27 },   -- orange
  B = { 0.95, 0.85, 0.32 },   -- yellow
  C = { 0.46, 0.80, 0.42 },   -- green
  F = { 0.55, 0.56, 0.95 },   -- indigo
}

-- Gold favorite star, reused for the "wanted" marker everywhere it's drawn.
ns.WantedIcon = "PetJournal-FavoritesIcon"

-- A tier letter's color as a WoW "RRGGBB" hex string (for inline |c…|r coloring in
-- Labels/tooltips), or nil for an unknown/absent tier.
---@param rank string?
---@return string?
function ns.RankHex(rank)
  local c = rank and ns.RankColors[rank]
  if not c then return nil end
  return ("%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

-- ─── Wanted ──────────────────────────────────────────────────────────────────

---@param setId number
---@return boolean
function ns:IsWanted(setId)
  return self.db.wanted[setId] == true
end

---@param setId number
---@param wanted boolean
function ns:SetWanted(setId, wanted)
  self.db.wanted[setId] = wanted or nil
end

---Flip the wanted flag; returns the new state.
---@param setId number
---@return boolean
function ns:ToggleWanted(setId)
  local now = not self:IsWanted(setId)
  self:SetWanted(setId, now)
  return now
end

---Number of sets currently flagged wanted.
---@return number
function ns:WantedCount()
  local n = 0
  for _ in pairs(self.db.wanted) do n = n + 1 end
  return n
end

-- ─── Weapon Wanted (per appearance) ──────────────────────────────────────────
-- The Weapons view flags individual weapon LOOKS (a cell holds several), so its wanted
-- state is keyed by the appearance's visualID (ItemAppearanceID), separate from the
-- set `wanted` table. Notifies the same OnRatingsChanged listeners so grids live-refresh.

---@param visualID number
---@return boolean
function ns:IsWeaponWanted(visualID)
  return self.db.weaponWanted[visualID] == true
end

---Flip a weapon look's wanted flag; returns the new state.
---@param visualID number
---@return boolean
function ns:ToggleWeaponWanted(visualID)
  local now = not self:IsWeaponWanted(visualID) or nil
  self.db.weaponWanted[visualID] = now
  return now == true
end

---Number of weapon looks currently flagged wanted.
---@return number
function ns:WeaponWantedCount()
  local n = 0
  for _ in pairs(self.db.weaponWanted) do n = n + 1 end
  return n
end

-- ─── Cosmetic Wanted (per appearance) ────────────────────────────────────────
-- Shirts and tabards are the one browse surface that lists appearances you DON'T own (a set
-- never supplies either, so the picker is the only place they surface at all), which is what
-- makes a wishlist flag meaningful there. Keyed by visualID like the weapon flags, but its own
-- table: a wanted shirt must not inflate WeaponWantedCount or show up in a Weapons-view filter.

---@param visualID number
---@return boolean
function ns:IsCosmeticWanted(visualID)
  return self.db.cosmeticWanted[visualID] == true
end

---Flip a shirt/tabard appearance's wanted flag; returns the new state.
---@param visualID number
---@return boolean
function ns:ToggleCosmeticWanted(visualID)
  local now = not self:IsCosmeticWanted(visualID) or nil
  self.db.cosmeticWanted[visualID] = now
  return now == true
end

---Number of shirt/tabard appearances currently flagged wanted.
---@return number
function ns:CosmeticWantedCount()
  local n = 0
  for _ in pairs(self.db.cosmeticWanted) do n = n + 1 end
  return n
end

-- ─── Illusion Wanted (per illusion) ──────────────────────────────────────────
-- The illusion list, like the cosmetic ones, shows illusions you don't own, so it earns the same
-- wishlist flag. Keyed by the illusion's **sourceID**, not a visualID — illusions have no visual
-- id, and the two id spaces overlap numerically, so sharing `cosmeticWanted` would eventually
-- star the wrong row.

---@param sourceID number  an illusion sourceID
---@return boolean
function ns:IsIllusionWanted(sourceID)
  return self.db.illusionWanted[sourceID] == true
end

---Flip an illusion's wanted flag; returns the new state.
---@param sourceID number
---@return boolean
function ns:ToggleIllusionWanted(sourceID)
  local now = not self:IsIllusionWanted(sourceID) or nil
  self.db.illusionWanted[sourceID] = now
  return now == true
end

---Number of illusions currently flagged wanted.
---@return number
function ns:IllusionWantedCount()
  local n = 0
  for _ in pairs(self.db.illusionWanted) do n = n + 1 end
  return n
end

-- ─── Rank ──────────────────────────────────────────────────────────────────--

---Baseline (race-independent) tier for a set, or nil if unranked.
---@param setId number
---@return string?
function ns:BaselineRank(setId)
  return self.db.rank[setId]
end

---Per-race tier override for a set, or nil.
---@param setId number
---@param raceId number
---@return string?
function ns:RaceRank(setId, raceId)
  local r = self.db.raceRank[setId]
  return r and r[raceId]
end

---Tier as seen by a race: the race override if set, else the baseline, else nil.
---Pass no raceId to resolve the baseline only.
---@param setId number
---@param raceId number?
---@return string?
function ns:EffectiveRank(setId, raceId)
  if raceId then
    local o = self:RaceRank(setId, raceId)
    if o then return o end
  end
  return self:BaselineRank(setId)
end

---Set or clear the baseline tier (rank nil clears).
---@param setId number
---@param rank string?
function ns:SetBaselineRank(setId, rank)
  self.db.rank[setId] = rank
end

---Set or clear a per-race tier override (rank nil clears; drops the per-set table
---once its last override is gone, so it never accumulates empty tables).
---@param setId number
---@param raceId number
---@param rank string?
function ns:SetRaceRank(setId, raceId, rank)
  local t = self.db.raceRank[setId]
  if not t then
    if not rank then return end
    t = {}
    self.db.raceRank[setId] = t
  end
  t[raceId] = rank
  if not next(t) then self.db.raceRank[setId] = nil end
end

-- ─── Weapon Rank (per appearance) ────────────────────────────────────────────
-- The Weapons view's tier, keyed by visualID like its Wanted flag rather than by setId — a weapon
-- cell has no set id to hang a tier on. Deliberately WITHOUT the per-race override the armour tiers
-- carry: a weapon renders identically on every race, so "rank this for Dwarves" has nothing to say
-- about it (#688).

---Tier for a weapon appearance, or nil if unranked.
---@param visualID number
---@return string?
function ns:WeaponRank(visualID)
  return self.db.weaponRank[visualID]
end

---Set or clear a weapon appearance's tier (rank nil clears).
---@param visualID number
---@param rank string?
function ns:SetWeaponRank(visualID, rank)
  self.db.weaponRank[visualID] = rank
end

-- ─── Weapon cell aggregates ──────────────────────────────────────────────────
-- A Weapons-grid cell is a (source × weapon type) bucket holding several appearances — one raid can
-- drop four daggers — so its marks aggregate over the looks inside it, the way the armour grid's
-- row-level `groupWanted` aggregates over a group's class sets. Plain db reads, so the grid can call
-- them per cell on every refresh.

---True when ANY look in the cell is flagged wanted.
---@param visuals number[]
---@return boolean
function ns:WeaponCellWanted(visuals)
  for _, v in ipairs(visuals) do
    if self.db.weaponWanted[v] then return true end
  end
  return false
end

---The BEST tier among the cell's looks (ns.Ranks is ordered best → worst), or nil if none is ranked.
---A cell draws one pip, so it advertises the best thing in the bucket rather than an average nothing
---in it actually has.
---@param visuals number[]
---@return string?
function ns:WeaponCellRank(visuals)
  local best
  for _, v in ipairs(visuals) do
    local r = self.db.weaponRank[v]
    if r and (not best or ns.RankIndex[r] < ns.RankIndex[best]) then best = r end
  end
  return best
end

-- ─── Shared race resolution ──────────────────────────────────────────────────

---The logged-in character's canonical race id (the id the dressing-room selector
---and the per-race overrides are keyed by). Grids resolve ranks against this.
---@return number
function ns:PlayerRace()
  return ns.CanonRace(select(3, UnitRace("player")))
end

-- ─── Change notification ─────────────────────────────────────────────────────
-- The dressing room is shared by multiple grids (Collected's own window and
-- Warbandeer's `collected` view, each its own frame), so a rating edit there can't
-- know which grid to poke. Grids register a refresher here instead; the dressing
-- room just fires NotifyRatingsChanged after any change.
---@type fun()[]
ns._ratingListeners = {}

---Register a callback run after any wanted/rank change.
---@param fn fun()
function ns:OnRatingsChanged(fn)
  self._ratingListeners[#self._ratingListeners + 1] = fn
end

---Fire every registered ratings-changed callback.
function ns:NotifyRatingsChanged()
  for _, fn in ipairs(self._ratingListeners) do fn() end
end

-- ─── Dressed-set highlight ───────────────────────────────────────────────────
-- Same shared-dressing-room / multiple-grids problem as ratings: the room previews
-- one set at a time and can't know which grid launched it, so it broadcasts the
-- currently-shown set and every registered grid draws its cell cursor (or clears).
-- The set is identified by (setId, classIndex): PvP armour-type sets share one base
-- setId across several class columns, so the class column is needed to pin the exact
-- cell. classIndex is the set's slot in the positional group.sets. Fired from _load
-- (open + arrow nav) and the room's OnHide (nil = closed / nothing shown).
---@type fun(setId: number?, classIndex: number?)[]
ns._dressedListeners = {}

---Register a callback run whenever the dressing room's previewed set changes (it
---receives the setId + class column, or nil when the room closes).
---@param fn fun(setId: number?, classIndex: number?)
function ns:OnDressedSetChanged(fn)
  self._dressedListeners[#self._dressedListeners + 1] = fn
end

---Broadcast the dressing room's current set (nil to clear) to every registered grid.
---@param setId number?
---@param classIndex number?
function ns:NotifyDressedSetChanged(setId, classIndex)
  for _, fn in ipairs(self._dressedListeners) do fn(setId, classIndex) end
end

-- The weapon grid's parallel to the dressed-set bus: previewing (or ←/→ cycling) a
-- weapon cell broadcasts the shown source group + weapon type so the Weapons grid can
-- box the matching cell, exactly as HighlightSet boxes an armour cell. A weapon cell is
-- keyed by (source, type) rather than (setId, classIndex). Same shared-room reasoning:
-- the room can't know which grid launched it, so it broadcasts and grids self-resolve.
---@type fun(source: table?, weaponType: number?)[]
ns._dressedWeaponListeners = {}

---Register a callback run whenever the dressing room's previewed weapon cell changes
---(it receives the source group + weapon type, or nil when the room closes or an armour
---set is shown instead).
---@param fn fun(source: table?, weaponType: number?)
function ns:OnDressedWeaponCellChanged(fn)
  self._dressedWeaponListeners[#self._dressedWeaponListeners + 1] = fn
end

---Broadcast the dressing room's current weapon cell (nil to clear) to every registered grid.
---@param source table?
---@param weaponType number?
function ns:NotifyDressedWeaponCellChanged(source, weaponType)
  for _, fn in ipairs(self._dressedWeaponListeners) do fn(source, weaponType) end
end
