---@type Warbandeer_HousingDecor
local ns = select(2, ...)

-- Read-only data bridge so sibling addons (e.g. Warbandeer) can render the housing
-- decor collection without depending on this addon's UI. The decor snapshot lives in
-- `ns._entries` (rebuilt live each session) and the wanted flags in the account-wide
-- `WarbandeerHousingDecorDB` (`ns.db`). Mirrors the WarbandeerCollectedApi pattern: a
-- plain global table consumed via OptionalDeps; the embeddable grid class is hung on
-- `.List` later by list.lua (this file loads first, so the table already exists).

---@class WarbandeerHousingDecorApi
---@field WantedIcon string  atlas for the "wanted" marker (matches Collected's)
---@field List HousingDecorList  the shared decor list grid (set in `list.lua`); build with `embedded = true` to reuse it in a host view
local API = {}

-- The wanted-star atlas, shared with consumers so their header tally renders identically.
API.WantedIcon = ns.WantedIcon

---Account-wide collected/total decor counts from the last scan.
---@return number collected, number total
function API:Counts()
  return ns.db.collected or 0, ns.db.total or 0
end

---True once this session's live scan has populated the snapshot at least once.
---@return boolean
function API:IsScanned()
  return #ns._entries > 0
end

---The live decor snapshot (list of HousingDecorEntry). Consumers read-only.
---@return HousingDecorEntry[]
function API:Entries()
  return ns._entries
end

---Number of decor currently flagged wanted (for the header counter).
---@return number
function API:WantedCount() return ns:WantedCount() end

-- Scan-complete subscribers. Consumers (e.g. Warbandeer's decor view) register to be
-- refreshed after a scan rebuilds the snapshot, so their grid stays in sync with the
-- /decor window. `ns:Scan()` fires these once the snapshot is fresh.
ns._scanned = {}

---Register a callback fired after each scan rebuilds the decor snapshot.
---@param fn fun()
function API:OnScanned(fn)
  ns._scanned[#ns._scanned + 1] = fn
end

-- ─── Wanted (read + write) ───────────────────────────────────────────────────-
-- The wanted DB is account-wide, so consumers mutate it through here (both grids edit
-- the same data).

---@param recordID number
---@return boolean
function API:IsWanted(recordID) return ns:IsWanted(recordID) end

---@param recordID number
---@param wanted boolean
function API:SetWanted(recordID, wanted) ns:SetWanted(recordID, wanted) end

---Flip the wanted flag; returns the new state.
---@param recordID number
---@return boolean
function API:ToggleWanted(recordID) return ns:ToggleWanted(recordID) end

---Register a callback fired after any wanted change, so a consumer grid can live-refresh.
---@param fn fun()
function API:OnRatingsChanged(fn) ns:OnRatingsChanged(fn) end

---Show the shared decor InfoTip (source text + owned breakdown), so sibling addons
---render the identical hover panel. Forwards lazily to `ns.ShowInfoTip` (defined later
---in `controls/InfoTip.lua`).
---@param entry HousingDecorEntry  the hovered entry
---@param parent Frame  the hovered row to anchor against / level above
---@param position table  LibNUI position spec
function API:ShowInfoTip(entry, parent, position)
  ns.ShowInfoTip(entry, parent, position)
end

---Hide the shared InfoTip (no-op if never shown).
function API:HideInfoTip()
  ns.HideInfoTip()
end

_G.WarbandeerHousingDecorApi = API
