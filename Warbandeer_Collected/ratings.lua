---@class Warbandeer_Collected
---@field Ranks string[]  ordered tier letters, best → worst
---@field RankColors table<string, number[]>  tier letter → 0–1 rgb
---@field WantedIcon string  atlas for the "wanted" marker
local ns = select(2, ...)

-- Ordered aesthetic tiers, best → worst. The index doubles as the cycle order for
-- any UI that steps through them.
---@type string[]
ns.Ranks = { "S", "A", "B", "C", "F" }

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

-- ─── Shared race resolution ──────────────────────────────────────────────────

---The logged-in character's canonical race id (the id the dressing-room selector
---and the per-race overrides are keyed by). Grids resolve ranks against this.
---@return number
function ns:PlayerRace()
  return ns.CanonRace(select(3, UnitRace("player")))
end
