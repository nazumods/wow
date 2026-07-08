---@class LibNAddOn
local ns = select(2, ...)
local insert, remove = table.insert, table.remove

---@alias Event string

---Handle an event
---@param self AddOn addon
---@param e string event name
---@param ... any event arguments
local function OnEvent(self, e, ...)
  if self[e] and type(self[e]) == "function" then
    self[e](self, ...)
  end
  if self._eventHandlers[e] then
    for _,h in ipairs(self._eventHandlers[e]) do
      h(self, ...)
    end
  end
end

---Register an AddOn for an event
---@param self AddOn addon
---@param name string event name
---@param handler function? event handler function, or nil to just register the event without a handler
---@param idx integer? insert handler at index in handler list, or append if nil
local function RegisterEvent(self, name, handler, idx)
  if not self._eventHandlers[name] then
    self._eventListener:RegisterEvent(name)
    self._eventHandlers[name] = {}
  end
  if handler then
    if idx then
      insert(self._eventHandlers[name], idx, handler)
    else
      insert(self._eventHandlers[name], handler)
    end
  end
end

---Unregister an AddOn for an event
---@param self AddOn addon
---@param name string event name
---@param handler function? event handler function to unregister, or nil to unregister all handlers for the event
local function UnregisterEvent(self, name, handler)
  if not self._eventHandlers[name] then return end  -- never registered (or already fully unregistered)
  if handler then
    local idx
    for i,h in ipairs(self._eventHandlers[name]) do
      if h == handler then idx = i; break end
    end
    if idx then remove(self._eventHandlers[name], idx) end
    if #self._eventHandlers[name] == 0 then
      self._eventListener:UnregisterEvent(name)
      self._eventHandlers[name] = nil
    end
  else
    self._eventListener:UnregisterEvent(name)
    self._eventHandlers[name] = nil
  end
end

---@class AddOn
---@field _eventListener WoWFrame event listener frame
---@field _eventHandlers table<string, function[]> event handlers for registered events
---@field registerEvent fun(self: AddOn, name: string, handler: function?, idx: number?) register an event handler for an event
---@field unregisterEvent fun(self: AddOn, name: string, handler: function?) unregister an event handler for an event, or all handlers if handler is nil
---@field delay fun(self: AddOn, ms: number, fn: function|string) one-shot debounce timer; a second call replaces the pending callback
---@field after fun(self: AddOn, ms: number, fn: function) fire fn once after ms milliseconds; supports concurrent timers
---@field _coalescing table<any, boolean> keys with a coalesced fire currently scheduled
---@field coalesce fun(self: AddOn, key: any, ms: number, fn: function) collapse a storm of same-key calls into one trailing-edge fire ms later
---@field onLoad fun(self: AddOn) called when the add-on is loaded
---@field onLogin fun(self: AddOn, isLogin: boolean, isReload: boolean) called when the player logs in or the UI is reloaded
---@field ADDON_LOADED Event
---@field PLAYER_ENTERING_WORLD Event
---@field ON_UPDATE Event

---@class LibNAddOn
---@field createEventListener fun(addOn: AddOn) create event listener for an add-on
function ns.createEventListener(addOn)
  local a = addOn
  a._eventListener = CreateFrame("Frame")
  a._eventHandlers = {}
  a._coalescing = {}
  a._eventListener.OnEvent = OnEvent
  a.registerEvent = RegisterEvent
  a.unregisterEvent = UnregisterEvent
  a._eventListener:SetScript("OnEvent", function(_, e, ...) a._eventListener.OnEvent(a, e, ...) end)

  -- convenience event listeners
  a:registerEvent("ADDON_LOADED", function(self, name)
    if name ~= self._NAME then return end -- we're only interested in the target add-on
    if self.onLoad then self:onLoad() end -- if an onLoad func is defined, call it
    -- if any other supported convenience event handlers are defined, set those up
    if self.onLogin then
      self:registerEvent("PLAYER_ENTERING_WORLD", function(_, login, reload)
        if login or reload then addOn:onLogin(login, reload) end
      end)
    end
  end)

  a.delay = function(self, ms, fn)
    local s = self
    local timer = 0
    a._eventListener:SetScript("OnUpdate", function(_, elapsed)
      timer = timer + (elapsed * 1000)
      if timer < ms then return end
      a._eventListener:SetScript("OnUpdate", nil)
      if type(fn) == "function" then
        fn()
      else
        s[fn](s)
      end
    end)
  end

  a.after = function(_, ms, fn)
    C_Timer.After(ms / 1000, fn)
  end

  -- Collapse a storm of same-`key` calls into a single trailing-edge fire: the
  -- first call schedules `fn` for `ms` later, every call arriving before that
  -- timer fires is dropped, and once it fires the key clears so the next call
  -- opens a fresh window. Unlike `delay` (one slot per addon, last call wins)
  -- each key coalesces independently; unlike `after` (every call fires) a burst
  -- collapses to one fire. For high-frequency events (QUEST_LOG_UPDATE,
  -- CURRENCY_DISPLAY_UPDATE) that would otherwise trigger a full refresh dozens
  -- of times a second.
  a.coalesce = function(self, key, ms, fn)
    local pending = self._coalescing
    if pending[key] then return end   -- a fire is already scheduled for this key
    pending[key] = true
    C_Timer.After(ms / 1000, function()
      pending[key] = nil
      fn()
    end)
  end
end
