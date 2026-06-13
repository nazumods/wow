---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local Class = ns.lua.Class
local Frame = ui.Frame
local GetCursorPosition = GetCursorPosition

-- Blizzard's dressup model scene (DRESS_UP_FRAME_MODEL_SCENE_ID): borrowing it
-- gives us a full-body camera, lighting, and a dressable player actor we then
-- re-skin. A bare DressUpModel can't skin a race other than the player's (it
-- renders untextured/white) — only a ModelScene actor does it correctly.
local DRESSUP_SCENE = 596

-- A ModelScene-backed 3D viewer: skin the actor (a unit, an arbitrary race via a
-- creature display ID, or a unit rendered as another race), then TryOn transmog
-- appearance sources. Drag horizontally to rotate.
---@class Model: Frame
---@field rotateSpeed number  radians of yaw applied per screen pixel dragged
---@field _actor table?  the scene's player actor (backing model)
---@field _yaw number  accumulated drag yaw in radians (internal)
local Model = Class(Frame, function(self)
  -- Borrow the dressup scene so we inherit its camera + a player actor.
  self._widget:TransitionToModelSceneID(
    DRESSUP_SCENE, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
  self._actor = self._widget:GetPlayerActor()
  self._yaw = 0

  local w = self._widget
  w:EnableMouse(true)
  local dragging, lastX
  w:SetScript("OnMouseDown", function() dragging = true; lastX = (GetCursorPosition()) end)
  w:SetScript("OnMouseUp", function() dragging = false end)
  w:SetScript("OnUpdate", function()
    if not dragging or not self._actor then return end
    local x = GetCursorPosition()
    self._yaw = self._yaw + (x - lastX) / w:GetEffectiveScale() * self.rotateSpeed
    lastX = x
    self._actor:SetYaw(self._yaw)
  end)
end, {
  type = "ModelScene",
  template = "ModelSceneMixinTemplate",
  rotateSpeed = 0.01,
})
ui.Model = Model

-- Skin the actor with a creature display ID (a specific race + gender). Textures
-- correctly; the second arg uses the active player's customizations as a base.
---@param creatureDisplayID number
---@return Model
function Model:DisplayInfo(creatureDisplayID)
  if self._actor then self._actor:SetModelByCreatureDisplayID(creatureDisplayID, true) end
  return self
end

-- Skin the actor from a unit, optionally rendered as another race (customRaceID,
-- a chrRaceID — keeps the unit's gender). autoDress is off so the caller controls
-- what's worn via TryOn.
---@param token string  unit token (e.g. "player")
---@param customRaceID number?  chrRaceID to render the unit as
---@return Model
function Model:Unit(token, customRaceID)
  if self._actor then
    self._actor:SetModelByUnit(token, false, false, false, true, false, customRaceID)
  end
  return self
end

---@param source string|number  item link or itemModifiedAppearanceID (sourceID)
---@return Model
function Model:TryOn(source)
  if self._actor then self._actor:TryOn(source) end
  return self
end

---@return Model
function Model:Undress() if self._actor then self._actor:Undress() end; return self end

---@return Model
function Model:Dress() if self._actor then self._actor:Dress() end; return self end
