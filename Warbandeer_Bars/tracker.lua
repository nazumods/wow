---@type Warbandeer_Bars
local ns = select(2, ...)

-- The tracker always captures FULL fidelity so stored profiles can satisfy any
-- restore filter later. What a restore actually applies is controlled separately
-- by ns.settings.include (see init.lua / api.lua).
local CAPTURE_ALL = { bars = true, bindings = true, macros = true, petbar = true, outfits = true }

local SPEC_SETTLE_MS  = 500   -- let the new spec's bars settle after a spec change
local LOGIN_SETTLE_MS = 2000  -- let bars load after entering the world
local CHANGE_SETTLE_MS = 10000 -- quiet time after the LAST bar / macro / binding change before it is saved (a run of
                                -- moves, e.g. one bar to another, is then ONE snapshot)

local ready = false          -- armed once the login snapshot has run (change events before it are ignored)
local capturing = false      -- a cursor-path capture is running: the events it fires are ours, ignore them
local pendingChange = false  -- a change snapshot came due in combat; run it on PLAYER_REGEN_ENABLED

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
  -- A cursor-path capture picks actions up and puts them back, which fires bar events at us: ignore them (D10).
  capturing = not cursorFree
  local ok, profile = pcall(function() return store(ns.Capture(CAPTURE_ALL, true, true, cursorFree), guardSparse) end)
  capturing = false
  if not ok then error(profile, 0) end
  return profile
end

-- Change-driven snapshot (#984). By PLAYER_LOGOUT the client has already emptied the action bars (observed on Retail
-- 2026-10-15: a logout snapshot stored 0 slots; the spec presumably reads empty too, inferred), so nothing is captured at
-- logout; bar changes are saved as they happen instead. Armed only after the login snapshot (before it the bars are still
-- populating, which is why that snapshot is sparse-guarded); cursor-free, so it fires no bar events itself and cannot
-- loop; unguarded, so it records a legitimate reduction; a snapshot that comes due in combat runs when combat ends, and
-- one that comes due while the cursor holds something is tried again after another quiet period (Snapshot skips then).
local function runChangeSnapshot()
  if not ready then return end    -- disarmed by logout: a late timer must not capture the emptied bars
  if InCombatLockdown() then pendingChange = true; return end
  if GetCursorInfo() then ns:debounce("change", CHANGE_SETTLE_MS, runChangeSnapshot); return end
  ns.Snapshot(false, true)
end

local function onBarChange()
  if not ready or capturing then return end
  -- `debounce` keeps its own keyed timer: `delay` is one shared timer that the spec-change handler also uses.
  ns:debounce("change", CHANGE_SETTLE_MS, runChangeSnapshot)
end

function ns.ACTIONBAR_SLOT_CHANGED() onBarChange() end
function ns.UPDATE_MACROS() onBarChange() end
function ns.UPDATE_BINDINGS() onBarChange() end

function ns.PLAYER_REGEN_ENABLED()
  if not pendingChange then return end
  pendingChange = false
  runChangeSnapshot()
end

-- Takes no snapshot (see above). It only disarms the change tracking, so a timer still pending when the client starts
-- tearing down the UI cannot capture bars that are being emptied.
function ns.PLAYER_LOGOUT() ready = false end

-- Capture at session boundaries: entering world and spec change (never at logout, see above).
function ns:onLogin()
  -- Use `after` (concurrent C_Timer), not `delay`: `delay` shares a single
  -- per-addon timer, so a spec change inside the login-settle window would
  -- overwrite this pending login capture and drop CaptureLayouts. The
  -- spec-change handler keeps `delay` for its debounce.
  self:after(LOGIN_SETTLE_MS, function()
    -- Armed AFTER the login snapshot (its own cursor-path events are also ignored by `capturing`), and armed even if the
    -- login work throws, so one login-time error cannot switch change tracking off for the session.
    local ok, err = pcall(function()
      ns.CaptureLayouts()
      ns.Snapshot(true)
    end)
    ready = true
    if not ok then error(err, 0) end
  end)
end

function ns.ACTIVE_TALENT_GROUP_CHANGED()
  ns:delay(SPEC_SETTLE_MS, function() ns.Snapshot(true) end)
end

function ns.EDIT_MODE_LAYOUTS_UPDATED() ns.CaptureLayouts() end

ns:registerEvent("ACTIVE_TALENT_GROUP_CHANGED")
ns:registerEvent("EDIT_MODE_LAYOUTS_UPDATED")
ns:registerEvent("ACTIONBAR_SLOT_CHANGED")
ns:registerEvent("UPDATE_MACROS")
ns:registerEvent("UPDATE_BINDINGS")
ns:registerEvent("PLAYER_REGEN_ENABLED")
ns:registerEvent("PLAYER_LOGOUT")
