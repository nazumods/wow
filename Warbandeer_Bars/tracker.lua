local _, ns = ...

-- The tracker always captures FULL fidelity so stored profiles can satisfy any
-- restore filter later. What a restore actually applies is controlled separately
-- by ns.settings.include (see init.lua / api.lua).
local CAPTURE_ALL = { bars = true, bindings = true, macros = true, petbar = true, outfits = true }

local SPEC_SETTLE_MS  = 500   -- let the new spec's bars settle after a spec change
local LOGIN_SETTLE_MS = 2000  -- let bars load after entering the world

local function store(profile)
  if not profile or not profile.specID or profile.specID == 0 then return end
  local db = ns.db
  local byChar = db.profiles[profile.char]
  if not byChar then byChar = {}; db.profiles[profile.char] = byChar end
  byChar[profile.specID] = profile
  return profile
end

---Capture the current character's full setup and store it under [char][specID].
---No-op during combat (the macro temp-index resolution in capture touches
---protected APIs — though none of our triggers fire in combat) and while a
---cursor drag is in progress (would clobber it).
---@return table|nil profile  the stored profile, or nil if the snapshot was skipped
function ns.Snapshot()
  if InCombatLockdown() or GetCursorInfo() then return end
  return store(ns.Capture(CAPTURE_ALL, true, true))
end

-- Capture at session boundaries: entering world, spec change, and logout/reload.
function ns:onLogin()
  self:delay(LOGIN_SETTLE_MS, ns.Snapshot)
end

function ns.ACTIVE_TALENT_GROUP_CHANGED()
  ns:delay(SPEC_SETTLE_MS, ns.Snapshot)
end

function ns.PLAYER_LOGOUT() ns.Snapshot() end  -- also fires on /reload

ns:registerEvent("ACTIVE_TALENT_GROUP_CHANGED")
ns:registerEvent("PLAYER_LOGOUT")
