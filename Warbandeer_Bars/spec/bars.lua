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

return bars
