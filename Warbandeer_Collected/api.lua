---@type Warbandeer_Collected
local ns = select(2, ...)

-- Read-only data bridge so sibling addons (e.g. Warbandeer) can render the
-- transmog-set collection without depending on this addon's UI. The scan data
-- itself lives in the account-wide `WarbandeerCollectedDB` (`ns.db`); the static
-- group/set definitions live in `ns.Sets`/`ns.Releases`. Mirrors the
-- WarbandeerBarsApi pattern: a plain global table consumed via OptionalDeps.

---@class WarbandeerCollectedApi
---@field Sets table[] transmog set groups (see `ns.Sets`)
---@field Releases string[] expansion names indexed by `release`
---@field ReleaseIcons string[] expansion badge textures (64x64 TGA), parallel to `Releases`
---@field Ranks string[] ordered tier letters, best → worst (see `ns.Ranks`)
---@field RankColors table<string, number[]> tier letter → 0–1 rgb
---@field WantedIcon string atlas for the "wanted" marker
local API = {}

-- Static set-group definitions (rows), release names, and the parallel expansion
-- badge texture paths. Same tables the in-addon DataView / DressingRoom read; safe
-- to share since consumers only read them. (Warbandeer's Reputations view labels its
-- expansion pages with the badges via `ReleaseIcons`.)
API.Sets = ns.Sets
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
---@param reverse boolean?  the caller's grid sort (newest-first when true) so the tier Up/Down nav matches the on-screen order
function API:ShowDressingRoom(group, set, reverse)
  ns.ShowDressingRoom(group, set, reverse)
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

_G.WarbandeerCollectedApi = API
