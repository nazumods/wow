---@type Warbandeer_Bars
local ns = select(2, ...)

-- The tracker always captures FULL fidelity so stored profiles can satisfy any
-- restore filter later. What a restore actually applies is controlled separately
-- by ns.settings.include (see init.lua / api.lua).
local CAPTURE_ALL = { bars = true, bindings = true, macros = true, petbar = true, outfits = true }

local SPEC_SETTLE_MS  = 500   -- let the new spec's bars settle after a spec change
local LOGIN_SETTLE_MS = 2000  -- let bars load after entering the world
local CHANGE_CHECK_SECONDS = 10 -- how often the bars' fingerprint is compared (#984)

local ready = false          -- armed once the login snapshot has run (no change checking before it)
local ticker = nil           -- the ONE change-checking ticker (cancelled and replaced if login runs again)
local lastStoredPrint = nil  -- fingerprint when the stored profile was last written (login snapshot / change snapshot)
local lastTickPrint = nil    -- fingerprint at the previous (non-skipped) tick

-- Decide whether a freshly captured profile should replace the stored one.
-- `guardSparse` (set by the login / spec-change timers) refuses a capture with
-- fewer action-bar slots than the stored profile: those timers fire on a delay
-- after entering the world / swapping spec and can run before the bars finish
-- populating, so an unguarded store would clobber a good profile with a sparse
-- race artifact. The change-driven snapshot is never guarded, so a legitimate reduction
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
---protected APIs) and while a cursor drag is in progress (would clobber it).
---@param guardSparse boolean? skip the store when the capture is sparser than the
---  stored profile (used by the login/spec timers, which can race bar population)
---@param cursorFree boolean? resolve temp macros without the cursor (the change-driven snapshot; see capture.lua)
---@return table|nil profile  the stored profile, or nil if the snapshot was skipped
function ns.Snapshot(guardSparse, cursorFree)
  if InCombatLockdown() or GetCursorInfo() then return end
  return store(ns.Capture(CAPTURE_ALL, true, true, cursorFree), guardSparse)
end

-- Change-driven snapshot (#984). By PLAYER_LOGOUT the client has already emptied the action bars (observed on Retail
-- 2026-10-15: a logout snapshot stored 0 slots; the spec presumably reads empty too, inferred), so nothing is captured at
-- logout. Bar EVENTS cannot say "the player changed something" on a live Retail client (observed in about two minutes:
-- UPDATE_MACROS 798 times, ACTIONBAR_SLOT_CHANGED 535, UPDATE_BINDINGS 4; the 10 s quiet-time debounce never fired), so
-- instead every CHANGE_CHECK_SECONDS the tracker compares a fingerprint of the bars (ns.Fingerprint: slots, macro names
-- and icons, bindings; NOT macro bodies) and snapshots when it differs from the last stored one AND held steady for one
-- full check. A run of changes is then ONE snapshot, 10-20 s after the last of them. The snapshot is cursor-free (it
-- fires no bar events and runs no other addon's action-bar hook) and unguarded (it records a legitimate reduction).
local function fingerprint()
  local ok, fp = pcall(ns.Fingerprint)
  if ok then return fp end
end

local function tick()
  if not ready then return end                          -- disarmed by logout (or not armed yet)
  if InCombatLockdown() or GetCursorInfo() then return end  -- skipped entirely: lastTickPrint does not advance
  local fp = fingerprint()
  if not fp then return end                             -- unreadable this tick: say nothing, try again next time
  if fp ~= lastStoredPrint and fp == lastTickPrint then
    -- Changed since the last stored profile and unchanged for a full check. The attempt counts as "stored" even if
    -- it stored nothing (no spec yet), so a profile that cannot be written is not re-captured every 10 s.
    lastStoredPrint = fp
    ns.Snapshot(false, true)
  end
  lastTickPrint = fp
end

-- Takes no snapshot (see above). It only disarms the change checking, so a tick that is already due when the client
-- starts tearing down the UI cannot capture bars that are being emptied.
function ns.PLAYER_LOGOUT() ready = false end

-- Capture at session boundaries: entering world and spec change (never at logout, see above).
function ns:onLogin()
  -- Use `after` (concurrent C_Timer), not `delay`: `delay` shares a single
  -- per-addon timer, so a spec change inside the login-settle window would
  -- overwrite this pending login capture and drop CaptureLayouts. The
  -- spec-change handler keeps `delay` for its debounce.
  self:after(LOGIN_SETTLE_MS, function()
    -- Armed AFTER the login snapshot, and armed even if the login work throws, so one login-time error cannot switch
    -- change checking off for the session.
    local ok, err = pcall(function()
      ns.CaptureLayouts()
      ns.Snapshot(true)
    end)
    lastStoredPrint = fingerprint()
    lastTickPrint = lastStoredPrint
    ready = true
    -- exactly one ticker, even if login runs again
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(CHANGE_CHECK_SECONDS, tick)
    if not ok then error(err, 0) end
  end)
end

function ns.ACTIVE_TALENT_GROUP_CHANGED()
  ns:delay(SPEC_SETTLE_MS, function() ns.Snapshot(true) end)
end

function ns.EDIT_MODE_LAYOUTS_UPDATED() ns.CaptureLayouts() end

ns:registerEvent("ACTIVE_TALENT_GROUP_CHANGED")
ns:registerEvent("EDIT_MODE_LAYOUTS_UPDATED")
ns:registerEvent("PLAYER_LOGOUT")
