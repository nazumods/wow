---@class Warbandeer_HousingDecor
---@field WantedIcon string  atlas for the "wanted" marker
local ns = select(2, ...)

-- Gold favorite star, reused wherever the "wanted" flag is drawn (list row, header
-- tally, InfoTip). Same atlas Collected uses, so the two views read identically.
ns.WantedIcon = "PetJournal-FavoritesIcon"

-- ─── Wanted ──────────────────────────────────────────────────────────────────
-- The only user-authored state. Account-wide and keyed by the catalog `recordID`
-- (decor collection is itself account-wide — houses belong to the warband — so
-- there is no per-character axis, and no S–F/per-race rank dimension: decor has no
-- race to taste-rank against). Lives in its own DB key, untouched by scans.

---@param recordID number
---@return boolean
function ns:IsWanted(recordID)
  return self.db.wanted[recordID] == true
end

---@param recordID number
---@param wanted boolean
function ns:SetWanted(recordID, wanted)
  self.db.wanted[recordID] = wanted or nil
end

---Flip the wanted flag; returns the new state.
---@param recordID number
---@return boolean
function ns:ToggleWanted(recordID)
  local now = not self:IsWanted(recordID)
  self:SetWanted(recordID, now)
  self:NotifyRatingsChanged()
  return now
end

---Number of decor entries currently flagged wanted.
---@return number
function ns:WantedCount()
  local n = 0
  for _ in pairs(self.db.wanted) do n = n + 1 end
  return n
end

-- ─── Change notification ─────────────────────────────────────────────────────
-- The wanted flags are shared by two grids (the standalone /decor window and
-- Warbandeer's embedded decor view, each its own frame), so a toggle in one can't
-- know which others to refresh. Grids register a refresher here; ToggleWanted fires
-- them all after any change.
---@type fun()[]
ns._ratingListeners = {}

---Register a callback run after any wanted change.
---@param fn fun()
function ns:OnRatingsChanged(fn)
  self._ratingListeners[#self._ratingListeners + 1] = fn
end

---Fire every registered ratings-changed callback.
function ns:NotifyRatingsChanged()
  for _, fn in ipairs(self._ratingListeners) do fn() end
end
