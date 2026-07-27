---@class LibNAddOn
local ns = select(2, ...)

---@class Lua
---@field signal fun(): Signal  create an empty signal

-- A minimal publish/subscribe channel: listeners register, something fires, everyone runs.
--
-- Eight of these had been hand-rolled across the suite, every one of them the same two lines —
-- `list[#list + 1] = fn` to subscribe and `for _, fn in ipairs(list) do fn(...) end` to fire. The
-- pattern shows up wherever one producer can't know its consumers: a shared dressing room whose
-- edits must reach several grids, each living in a different addon's frame, is the case that keeps
-- recurring.
--
-- Deliberately NOT an event bus. There are no named channels, no priorities and no return values —
-- a signal IS the channel, so the owning addon names it by naming the variable, and nothing here
-- has to parse a string at fire time.

---@class Signal
---@field _fns function[]  subscribers, in registration order
local Signal = {}
Signal.__index = Signal

---Register a listener. Fires in registration order; the same function may subscribe twice, which
---is the caller's business rather than something to silently deduplicate.
---@param fn function
---@return function fn  the same function, so a caller can keep it for Unsubscribe
function Signal:Subscribe(fn)
  self._fns[#self._fns + 1] = fn
  return fn
end

---Remove a previously registered listener. Removes ONE registration — a function subscribed twice
---needs unsubscribing twice, which keeps this the exact inverse of Subscribe.
---@param fn function
---@return boolean removed  false when it wasn't registered
function Signal:Unsubscribe(fn)
  for i, f in ipairs(self._fns) do
    if f == fn then
      table.remove(self._fns, i)
      return true
    end
  end
  return false
end

---Run every listener with the given arguments.
---
---Iterates a **snapshot**, so a listener that subscribes or unsubscribes while the signal is firing
---can't shift the list underneath the loop — one that unsubscribes itself would otherwise make the
---next listener skip its turn. The change still takes effect, just from the next fire onwards.
---@param ... any  passed through to every listener
function Signal:Fire(...)
  local fns = self._fns
  local n = #fns
  if n == 0 then return end
  local snapshot = {}
  for i = 1, n do snapshot[i] = fns[i] end
  for i = 1, n do snapshot[i](...) end
end

---How many listeners are registered. For tests and for a producer that wants to skip expensive
---work when nobody is listening.
---@return number
function Signal:Count()
  return #self._fns
end

---Create an empty signal.
---@return Signal
function ns.lua.signal()
  return setmetatable({ _fns = {} }, Signal)
end
