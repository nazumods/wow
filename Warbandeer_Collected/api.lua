---@type Warbandeer_Collected
local ns = select(2, ...)

-- Read-only data bridge so sibling addons (e.g. Warbandeer) can render the
-- transmog-set collection without depending on this addon's UI. The scan data
-- itself lives in the account-wide `WarbandeerCollectedDB` (`ns.db`); the static
-- group/set definitions live in `ns.Sets`/`ns.Releases`. Mirrors the
-- WarbandeerBarsApi pattern: a plain global table consumed via OptionalDeps.

---@class WarbandeerCollectedApi
local API = {}

-- Static set-group definitions (rows) and release names. Same tables the
-- in-addon DataView reads; safe to share since consumers only read them.
API.Sets = ns.Sets
API.Releases = ns.Releases

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

_G.WarbandeerCollectedApi = API
