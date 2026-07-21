---@type Warbandeer_Collected
local ns = select(2, ...)

-- Read-only data bridge so sibling addons (e.g. Warbandeer) can render the
-- transmog-set collection without depending on this addon's UI. The scan data
-- itself lives in the account-wide `WarbandeerCollectedDB` (`ns.db`); the static
-- group/set definitions live in `ns.Sets`/`ns.Releases`. Mirrors the
-- WarbandeerBarsApi pattern: a plain global table consumed via OptionalDeps.

---@class WarbandeerCollectedApi
---@field Sets table[] transmog set groups (see `ns.Sets`)
---@field PtrSets table[] PTR-only "upcoming" set groups (see `ns.PtrSets`)
---@field PtrBuild { live: string, ptr: string } the builds the PTR delta was generated from
---@field Releases string[] expansion names indexed by `release`
---@field ReleaseIcons string[] expansion badge textures (64x64 TGA), parallel to `Releases`
---@field Ranks string[] ordered tier letters, best → worst (see `ns.Ranks`)
---@field RankColors table<string, number[]> tier letter → 0–1 rgb
---@field WantedIcon string atlas for the "wanted" marker
---@field OnScanned fun(self, fn: fun()) register a callback fired after each scan refreshes the data
---@field DataView DataView the shared set-by-class grid class (set in `DataView.lua`); build with `embedded = true` to reuse it in a host view
local API = {}

-- Static set-group definitions (rows), release names, and the parallel expansion
-- badge texture paths. Same tables the in-addon DataView / DressingRoom read; safe
-- to share since consumers only read them. (Warbandeer's Reputations view labels its
-- expansion pages with the badges via `ReleaseIcons`.)
API.Sets = ns.Sets
API.PtrSets = ns.PtrSets
API.PtrBuild = ns.PtrBuild
API.Releases = ns.Releases
API.ReleaseIcons = ns.ReleaseIcons

-- Rating presentation shared with consumers so their grids render identical
-- markers (same tier order, colors, and wanted-star atlas).
API.Ranks = ns.Ranks
API.RankColors = ns.RankColors
API.WantedIcon = ns.WantedIcon

---Account-wide collected/total counts from the last scan.
---@return number collected, number total
function API:Counts()
  return ns.db.collected or 0, ns.db.total or 0
end

---True once `/collected scan` has populated data at least once.
---@return boolean
function API:IsScanned()
  return (ns.db.total or 0) > 0
end

---Number of sets currently flagged wanted (for the header counter).
---@return number
function API:WantedCount() return ns:WantedCount() end

-- Scan-complete subscribers. Consumers (e.g. Warbandeer's collected view) register
-- to be refreshed after a scan rewrites the counts, so their grid stays in sync with
-- the /collected window. `ns:Scan()` fires these once the DB is fresh, so callbacks
-- read up-to-date data with no debounce race.
ns._scanned = {}

---Register a callback fired after each scan refreshes the collection data.
---@param fn fun()
function API:OnScanned(fn)
  ns._scanned[#ns._scanned + 1] = fn
end

---Scan table for one group, or nil if the group was never scanned.
---@param groupId number
---@return table? map of setId -> (true | { collected, parts, total })
function API:GroupStatus(groupId)
  return ns.db.sets and ns.db.sets[groupId]
end

---Status of a single base set within a group.
---@param groupId number
---@param setId number
---@return boolean|table|nil  true = fully collected; { collected, total } = partial; nil = unknown
function API:SetStatus(groupId, setId)
  local g = ns.db.sets and ns.db.sets[groupId]
  return g and g[setId]
end

---Show the shared per-slot source InfoTip for a set, so sibling addons render the
---identical hover tooltip. Forwards lazily to `ns.ShowInfoTip` (defined later in
---`controls/InfoTip.lua`, after this file loads).
---@param group table  a group entry from `ns.Sets`
---@param set table    a set entry within that group
---@param parent Frame  the hovered cell to anchor against / level above
---@param position table  LibNUI position spec
function API:ShowInfoTip(group, set, parent, position)
  ns.ShowInfoTip(group, set, parent, position)
end

---Hide the shared InfoTip (no-op if never shown).
function API:HideInfoTip()
  ns.HideInfoTip()
end

---Open the shared dressing room previewing a set on a selectable race/gender, so
---sibling addons reuse the identical window. Forwards lazily to `ns.ShowDressingRoom`
---(defined in `controls/DressingRoom.lua`, after this file loads).
---@param group table  a group entry from `ns.Sets`
---@param set table    a set entry within that group
function API:ShowDressingRoom(group, set)
  ns.ShowDressingRoom(group, set)
end

---Hide the shared dressing room (no-op if never opened).
function API:HideDressingRoom()
  ns.HideDressingRoom()
end

-- ─── Ratings (read + write) ─────────────────────────────────────────────────-
-- The wanted/rank DB is account-wide, so consumers mutate it through here (the
-- shared dressing room and Warbandeer's own grid both edit the same data).

---@param setId number
---@return boolean
function API:IsWanted(setId) return ns:IsWanted(setId) end

---@param setId number
---@param wanted boolean
function API:SetWanted(setId, wanted) ns:SetWanted(setId, wanted) end

---Flip the wanted flag; returns the new state.
---@param setId number
---@return boolean
function API:ToggleWanted(setId) return ns:ToggleWanted(setId) end

---Tier as seen by a race (race override → baseline → nil). Omit raceId for the baseline.
---@param setId number
---@param raceId number?
---@return string?
function API:EffectiveRank(setId, raceId) return ns:EffectiveRank(setId, raceId) end

---@param setId number
---@return string?
function API:BaselineRank(setId) return ns:BaselineRank(setId) end

---@param setId number
---@param raceId number
---@return string?
function API:RaceRank(setId, raceId) return ns:RaceRank(setId, raceId) end

---@param setId number
---@param rank string?
function API:SetBaselineRank(setId, rank) ns:SetBaselineRank(setId, rank) end

---@param setId number
---@param raceId number
---@param rank string?
function API:SetRaceRank(setId, raceId, rank) ns:SetRaceRank(setId, raceId, rank) end

---The logged-in character's canonical race id (the key per-race overrides use).
---@return number
function API:PlayerRace() return ns:PlayerRace() end

---Register a callback fired after any wanted/rank change, so a consumer grid can
---live-refresh when the shared dressing room edits a rating.
---@param fn fun()
function API:OnRatingsChanged(fn) ns:OnRatingsChanged(fn) end

---Register a callback fired when the shared dressing room's previewed set changes, so a
---consumer grid can highlight its row. The callback receives the setId (nil on close) and
---the class-column index — needed to disambiguate a PvP setId shared across class columns.
---@param fn fun(setId: number?, classIndex: number?)
function API:OnDressedSetChanged(fn) ns:OnDressedSetChanged(fn) end

---Register a callback fired when the shared dressing room's previewed **weapon cell** changes,
---so a consumer's Weapons grid can box the matching cell. The callback receives the source
---group + weapon type (nil on close, or when an armour set is shown instead).
---@param fn fun(source: table?, weaponType: number?)
function API:OnDressedWeaponCellChanged(fn) ns:OnDressedWeaponCellChanged(fn) end

_G.WarbandeerCollectedApi = API
