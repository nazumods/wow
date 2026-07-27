---@type Warbandeer_Collected
local ns = select(2, ...)
local C_Timer = C_Timer

-- The capped "try again while item data streams" tail, which six places wrote out by hand (#770
-- step 14). Item icons and names arrive asynchronously, so a first pass renders blanks; each of
-- these re-runs its own updater a few times until they resolve, then gives up rather than spinning.
--
-- **Not `ns.delay`.** LibNAddOn's `delay` keeps ONE active timer per addon (see the root CLAUDE.md
-- gotcha), so a second caller silently cancels the first — and the slot, weapon-slot, cosmetic-slot
-- and outfit retries all run concurrently while a room opens. `C_Timer.NewTimer` gives each its own.
--
-- **Resetting is deliberately separate.** Every caller already zeroes its counter somewhere the
-- scheduling code can't see: at the top of its own updater on a non-retry pass, or — for the slot
-- icons — in `DressingRoom:_load`, a different function entirely, because the budget belongs to the
-- room's whole open rather than to one updater call. Folding the reset in here would have moved
-- those decisions and quietly changed how many attempts each path gets.

---@class RetryState
---@field timer table?  the pending C_Timer, or nil
---@field tries number  attempts spent so far

---@class Warbandeer_Collected
---@field Retry fun(owner: table, key: string, opts: table): boolean
---@field ResetRetry fun(owner: table, key: string)
---@field CancelRetry fun(owner: table, key: string)

---@param owner table
---@param key string
---@return RetryState
local function state(owner, key)
  local field = "_rt_" .. key
  local s = owner[field]
  if not s then s = { tries = 0 }; owner[field] = s end
  return s
end

---Cancel any pending attempt for `key`, leaving the counter alone.
---@param owner table
---@param key string
function ns.CancelRetry(owner, key)
  local s = state(owner, key)
  if s.timer then s.timer:Cancel(); s.timer = nil end
end

---Cancel any pending attempt AND put the budget back to full.
---
---Called by whoever decides a run is "fresh" — which is not this file's business: see the note at
---the top about why the reset sites stay where they are.
---@param owner table
---@param key string
function ns.ResetRetry(owner, key)
  local s = state(owner, key)
  if s.timer then s.timer:Cancel(); s.timer = nil end
  s.tries = 0
end

---Schedule another attempt at `key` if the budget allows, cancelling any pending one first.
---
---Always cancels, so calling this on a settled pass is how a caller drops an attempt that is no
---longer wanted. Returns whether one was scheduled, for a caller that wants to say so.
---@param owner table
---@param key string
---@param opts table  `{ again = fun(), tries? = number (10), delay? = number (0.2) }`
---@return boolean scheduled
function ns.Retry(owner, key, opts)
  local s = state(owner, key)
  if s.timer then s.timer:Cancel(); s.timer = nil end
  if s.tries >= (opts.tries or 10) then return false end
  s.tries = s.tries + 1
  s.timer = C_Timer.NewTimer(opts.delay or 0.2, function()
    s.timer = nil
    opts.again()
  end)
  return true
end
