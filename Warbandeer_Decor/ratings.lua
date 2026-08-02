---@class Warbandeer_Decor
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

---Build a copyable text block of the decor currently flagged wanted, for the `wanted`
---command's portable output. Pure over its inputs (the live snapshot + a wanted predicate
---+ the authoritative total), so it's unit-tested without the catalog. Each named row is
---the decor's name, an unowned marker, and -- indented beneath -- its `sourceText` "where
---to get it" blurb: that free-text blurb is *displayed* per row, never *grouped on* (it
---carries no structured vendor/zone/price, which is exactly why the wanted list is taken to
---the vendor rather than the reverse). `total` is `ns:WantedCount()`; when it exceeds the
---rows the snapshot can name (catalog still loading) a footer says how many are missing.
---@param entries HousingDecorEntry[]  live snapshot
---@param isWanted fun(recordID: number): boolean
---@param total number  authoritative wanted count (may exceed the nameable rows mid-load)
---@return string body, number named
function ns.WantedListText(entries, isWanted, total)
  local rows, named = {}, 0
  for _, e in ipairs(entries) do
    if isWanted(e.recordID) then
      named = named + 1
      local row = e.name .. (e.owned and "" or "  (not owned)")
      if e.sourceText and e.sourceText ~= "" then
        row = row .. "\n    " .. e.sourceText
      end
      rows[#rows + 1] = row
    end
  end
  local header
  if named < total then
    header = ("%d wanted decor (%d not in the current scan -- open /wbdecor to refresh):")
      :format(total, total - named)
  else
    header = ("%d wanted decor:"):format(total)
  end
  return header .. "\n\n" .. table.concat(rows, "\n"), named
end

-- ─── Change notification ─────────────────────────────────────────────────────
-- The wanted flags are shared by two grids (the standalone /wbdecor window and
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
