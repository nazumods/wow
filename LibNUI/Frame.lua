---@type LibNUI_AddOn
local ns = select(2, ...)
local _G, insert = _G, table.insert
local CreateFrame = CreateFrame
local UISpecialFrames = UISpecialFrames
local C_Timer = C_Timer
local Class, unpack = ns.lua.Class, unpack
---@class LibNUI
local ui = ns.ui
local Region, Texture = ui.Region, ui.Texture

-- https://www.reddit.com/r/wowaddondev/comments/1cc2qgj/creating_a_wow_addon_part_2_creating_a_frame/
-- frame/UI control templates: https://www.wowinterface.com/forums/showthread.php?t=40444

---@class WoWFrame: WoWRegion
---@field SetScript fun(self: WoWFrame, event: string, handler: function) set a script handler for an event
---@field RegisterEvent fun(self: WoWFrame, event: string) register for an event
---@field UnregisterEvent fun(self: WoWFrame, event: string) unregister for an

-- empty frame
---@class Frame: Region
---@field OnLogin function
---@field onUpdate function
local Frame = Class(Region, function(self)
  if self.strata then self._widget:SetFrameStrata(self.strata) end
  if self.clamped then self._widget:SetClampedToScreen(true) end
  if self.scale then self._widget:SetScale(self.scale) end
  if self.level then self._widget:SetFrameLevel(self.level) end
  if self.special then
    -- make it closable with Escape key
    _G[self._widget:GetName()] = self._widget -- put it in the global namespace
    insert(UISpecialFrames, self._widget:GetName()) -- make it a special frame
  end

  if self.background then
    self.background = Texture:new{
      parent = self,
      layer = ui.layer.Background,
      position = { All = true },
      color = self.background,
    }
  end

  if self.drag then
    self:makeDraggable()
    self:makeContainerDraggable()
  end
  if self.dragTarget then self:setDragTarget(self.dragTarget._widget or self.dragTarget) end

  if self.scripts then
    self:RegisterScript(unpack(self.scripts))
  end
  if self.events then
    self:listenForEvents()
    for _,e in pairs(self.events) do
      self._widget:RegisterEvent(e)
    end
  end
  if self.unitEvents then
    self:listenForEvents()
    for e,u in pairs(self.unitEvents) do
      self._widget:RegisterUnitEvent(e, unpack(u))
    end
  end
end, {
  CreateWidget = function(self)
    return CreateFrame(self.type or "Frame", self.name, self.parent and self.parent._widget or self.parent, self.template)
  end,
})
ui.Frame = Frame

-- Dispatch a WoW event to the same-named method on self, if defined.
---@param event string
---@param ... any  event payload
function Frame:OnEvent(event, ...)
  if self[event] then
    self[event](self, ...)
  end
end

---@param login boolean  true on initial login
---@param reload boolean  true after /reload
function Frame:PLAYER_ENTERING_WORLD(login, reload)
  if self.OnLogin and (login or reload) then self:OnLogin() end
end

-- separate func so we don't occlude the varargs (...)
local function scriptHandlerFor(c, e)
  return function(...)
    if c[e] then c[e](c, ...) end
  end
end
-- Bridge script handlers to same-named methods on self.
---@param ... string  script handler names (e.g. "OnEnter", "OnMouseUp")
function Frame:RegisterScript(...)
  local e
  for i=1,select("#", ...) do
    e = select(i, ...)
    self:SetScript(e, scriptHandlerFor(self, e))
  end
end
---@param event string  script handler name
---@param handler function?
---@return Frame
function Frame:SetScript(event, handler) self._widget:SetScript(event, handler); return self end
---@param event string  script handler name
---@return Frame
function Frame:RemoveScript(event) self._widget:SetScript(event, nil); return self end
---@param enabled boolean  receive keyboard input (so an OnKeyDown handler fires)
---@return Frame
function Frame:EnableKeyboard(enabled) self._widget:EnableKeyboard(enabled); return self end
---@param propagate boolean  pass handled keys on to the next frame / default bindings (false consumes the key)
---@return Frame
function Frame:SetPropagateKeyboardInput(propagate)
  -- Restricted for insecure code in combat lockdown (Patch 10.1.5) — calling it then fires
  -- ADDON_ACTION_BLOCKED, so it is skipped to dodge the taint error.
  --
  -- The skip is NOT free, despite what this comment used to claim. The call no-ops, but the
  -- frame keeps whatever propagation state it last had, and that state outlives combat entry:
  -- a frame that consumed a key (propagate false) and then entered combat stays consuming.
  -- So a caller that also holds the keyboard (EnableKeyboard) in combat will eat the player's
  -- movement and action-bar keys with no way to release them. Pair capture with this call and
  -- drop both for the duration of combat — see nazumods/wow#736.
  if not InCombatLockdown() then self._widget:SetPropagateKeyboardInput(propagate) end
  return self
end
function Frame:listenForEvents()
  if self._listening then return end
  self._listening = true
  local o = self
  self:SetScript("OnEvent", function(_, e, ...) o:OnEvent(e, ...) end)
end
---@param event string
---@return Frame
function Frame:registerEvent(event) self._widget:RegisterEvent(event); return self end
---@param event string
---@return Frame
function Frame:unregisterEvent(event) self._widget:UnregisterEvent(event); return self end

-- https://wowpedia.fandom.com/wiki/Making_draggable_frames
---@return Frame
function Frame:makeDraggable()
  self._widget:SetMovable(true)
  self._widget:EnableMouse(true)
  self._widget:RegisterForDrag("LeftButton")
  return self
end
---@return Frame
function Frame:makeContainerDraggable()
  self._widget:SetScript("OnDragStart", function()
    self._widget:StartMoving()
  end)
  self._widget:SetScript("OnDragStop", function()
    self._widget:StopMovingOrSizing()
  end)
  return self
end
---@param target table  raw WoW frame moved when this frame is dragged
function Frame:setDragTarget(target)
  self._widget:SetScript("OnMouseDown", function()
    target:StartMoving()
  end)
  self._widget:SetScript("OnMouseUp", function()
    target:StopMovingOrSizing()
  end)
end

function Frame:startUpdates()
  if self.onUpdate and not self.animating then
    self.animating = true
    local s = self
    self._widget:SetScript("OnUpdate", function(_, elapsed)
      if s.animating then s:onUpdate(elapsed * 1000) end
    end)
  end
end
function Frame:stopUpdates()
  self._widget:SetScript("OnUpdate", nil)
  self.animating = false
end

---@param ms number  delay in milliseconds
---@param fn function|string  callback, or the name of a method on self
function Frame:delay(ms, fn)
  local s = self
  C_Timer.After(ms / 1000, function()
    if type(fn) == "function" then
      fn()
    else
      s[fn](s)
    end
  end)
end

-- todo, resizable: https://wowpedia.fandom.com/wiki/Making_resizable_frames

---@param name string  attribute name
---@param value any?
---@return any  the attribute value when getting
function Frame:Attribute(name, value) return value == nil and self._widget:GetAttribute(name) or self._widget:SetAttribute(name, value) end

-- Toggle mouse interactivity so the frame can receive OnEnter/OnLeave/OnMouseUp.
---@param enabled boolean?  defaults to true
---@return Frame
function Frame:EnableMouse(enabled)
  self._widget:EnableMouse(enabled ~= false)
  return self
end

-- Getter/setter for the frame level. Always returns the (new) frame level.
---@param level number?
---@return number
function Frame:Level(level)
  if level then
    self._widget:SetFrameLevel(level)
  end
  return self._widget:GetFrameLevel()
end

-- Raise the frame above its siblings within its strata.
---@return Frame
function Frame:Raise()
  self._widget:Raise()
  return self
end
