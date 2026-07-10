-- Loads Warbandeer_Bars/tracker.lua into a fresh namespace so its WoW-API-free
-- decision logic (ns.shouldStore) can be unit-tested without the WoW client.
-- tracker.lua only touches WoW at *call* time (Snapshot/Capture → GetActionInfo,
-- the triggers → ns:after/ns:delay), and those are never invoked here; the sole
-- load-time WoW touch is the three ns:registerEvent calls, which we stub.
-- Path is relative to the AddOns root, where busted runs.
local bars = {}

---@return table ns  a fresh Warbandeer_Bars namespace with ns.shouldStore defined
function bars.load()
  local ns = { registerEvent = function() end }
  assert(loadfile("Warbandeer_Bars/tracker.lua"))("Warbandeer_Bars", ns)
  return ns
end

-- Loads api.lua into a fresh namespace so the WoW-API-free DB methods (resolveChar,
-- DeleteProfile/DeleteCharacter, the getters) can be unit-tested. api.lua's only
-- load-time WoW touch is resolving GetSpecialization, which is absent here (→ nil) and
-- never called by these tests. Tests set ns.db.profiles after loading.
---@return table ns  a fresh namespace with ns.api populated (WarbandeerBarsApi)
function bars.loadApi()
  local ns = { api = {}, db = { profiles = {} } }
  assert(loadfile("Warbandeer_Bars/api.lua"))("Warbandeer_Bars", ns)
  return ns
end

return bars
