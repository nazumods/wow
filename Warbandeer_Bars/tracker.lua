---@type Warbandeer_Bars
local ns = select(2, ...)

-- The tracker always captures FULL fidelity so stored profiles can satisfy any
-- restore filter later. What a restore actually applies is controlled separately
-- by ns.settings.include (see init.lua / api.lua).
local CAPTURE_ALL = { bars = true, bindings = true, macros = true, petbar = true, outfits = true }

local SPEC_SETTLE_MS  = 500   -- let the new spec's bars settle after a spec change
local LOGIN_SETTLE_MS = 2000  -- let bars load after entering the world

-- Decide whether a freshly captured profile should replace the stored one.
-- `guardSparse` (set by the login / spec-change timers) refuses a capture with
-- fewer action-bar slots than the stored profile: those timers fire on a delay
-- after entering the world / swapping spec and can run before the bars finish
-- populating, so an unguarded store would clobber a good profile with a sparse
-- race artifact. The logout snapshot is never guarded, so a legitimate reduction
-- (the user genuinely cleared buttons) is still recorded.
---@param existing table|nil  the currently stored profile for this [char][specID]
---@param fresh table  the freshly captured profile
---@param guardSparse boolean|nil
---@return boolean
function ns.shouldStore(existing, fresh, guardSparse)
  if not guardSparse or not existing then return true end
  return #fresh.slots >= #existing.slots
end

local function store(profile, guardSparse)
  if not profile or not profile.specID or profile.specID == 0 then return end
  local db = ns.db
  local byChar = db.profiles[profile.char]
  if not byChar then byChar = {}; db.profiles[profile.char] = byChar end
  if not ns.shouldStore(byChar[profile.specID], profile, guardSparse) then return end
  byChar[profile.specID] = profile
  return profile
end

---Capture the current character's full setup and store it under [char][specID].
---No-op during combat (the macro temp-index resolution in capture touches
---protected APIs — though none of our triggers fire in combat) and while a
---cursor drag is in progress (would clobber it).
---@param guardSparse boolean? skip the store when the capture is sparser than the
---  stored profile (used by the login/spec timers, which can race bar population)
---@return table|nil profile  the stored profile, or nil if the snapshot was skipped
function ns.Snapshot(guardSparse)
  if InCombatLockdown() or GetCursorInfo() then return end
  return store(ns.Capture(CAPTURE_ALL, true, true), guardSparse)
end

-- Capture at session boundaries: entering world, spec change, and logout/reload.
function ns:onLogin()
  -- Use `after` (concurrent C_Timer), not `delay`: `delay` shares a single
  -- per-addon timer, so a spec change inside the login-settle window would
  -- overwrite this pending login capture and drop CaptureLayouts. The
  -- spec-change handler keeps `delay` for its debounce.
  self:after(LOGIN_SETTLE_MS, function()
    ns.CaptureLayouts()
    ns.Snapshot(true)
  end)
end

function ns.ACTIVE_TALENT_GROUP_CHANGED()
  ns:delay(SPEC_SETTLE_MS, function() ns.Snapshot(true) end)
end

function ns.PLAYER_LOGOUT() ns.Snapshot() end  -- also fires on /reload

function ns.EDIT_MODE_LAYOUTS_UPDATED() ns.CaptureLayouts() end

ns:registerEvent("ACTIVE_TALENT_GROUP_CHANGED")
ns:registerEvent("PLAYER_LOGOUT")
ns:registerEvent("EDIT_MODE_LAYOUTS_UPDATED")
