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
---@field facing number  initial yaw (radians) applied on load so the model faces the camera; re-skinned models default to a side-on pose, so we quarter-turn it
---@field _actor table?  the scene's player actor (backing model)
---@field _yaw number  accumulated drag yaw in radians (internal); seeded from `facing`
---@field _scale number  intended actor scale, re-applied after each async model load
---@field _outfit number[]?  remembered transmog sources, re-applied after each async model load (empty = undressed)
local Model = Class(Frame, function(self)
  -- Borrow the dressup scene so we inherit its camera + a player actor.
  self._widget:TransitionToModelSceneID(
    DRESSUP_SCENE, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
  self._actor = self._widget:GetPlayerActor()
  self._yaw = self.facing   -- seed so the model faces the camera, not side-on, on load
  self._scale = 1

  local w = self._widget
  w:EnableMouse(true)
  local dragging, lastX
  w:SetScript("OnMouseDown", function() dragging = true; lastX = (GetCursorPosition()) end)
  w:SetScript("OnMouseUp", function() dragging = false end)
  w:SetScript("OnUpdate", function()
    if not self._actor then return end
    -- Re-assert the intended scale every frame. An async re-skin resets the actor's
    -- scale when the load finishes, and on a cold first load that reset lands AFTER
    -- _reapply's backstop fires — wiping the per-race correction (the model would
    -- show at default size until the next race change). Polling here makes it stick
    -- regardless of load timing; it's idempotent and corrects within a frame.
    self._actor:SetScale(self._scale)
    if not dragging then return end
    local x = GetCursorPosition()
    self._yaw = self._yaw + (x - lastX) / w:GetEffectiveScale() * self.rotateSpeed
    lastX = x
    self._actor:SetYaw(self._yaw)
  end)
end, {
  type = "ModelScene",
  template = "ModelSceneMixinTemplate",
  rotateSpeed = 0.01,
  facing = -math.rad(88),   -- just shy of a quarter-turn from the side-on default, facing the camera
})
ui.Model = Model

-- Restore the intended yaw + scale. A re-skin loads the model asynchronously and
-- resets the actor to its natural values when the load finishes (a frame or more
-- later), so we both (a) re-arm the model-loaded callback — which is ONE-SHOT, so
-- it must be set before every re-skin — and (b) apply now + on a short delay as a
-- backstop for loads that don't fire it.
function Model:_reapply()
  if not self._actor then return end
  local apply = function()
    if not self._actor then return end
    self._actor:SetYaw(self._yaw)
    self._actor:SetScale(self._scale)
    self:_applyOutfit()
  end
  self._actor:SetOnModelLoadedCallback(apply)
  apply()
  self:delay(80, apply)
end

-- Re-apply the remembered outfit by TryOn-ing each source onto the model. No-op
-- until Outfit is called — so direct TryOn/Undress users keep the old behavior.
-- Without this the async re-skin would leave the model in its default dress once
-- the load completes, ignoring the requested outfit.
--
-- Deliberately does NOT Undress() first: the Unit re-skin loads with autoDress off
-- (an already-bare body), so an empty outfit is undressed and a re-apply just
-- re-TryOns the same sources — which is a visual no-op. Stripping here instead made
-- every backstop re-apply flash the settled model bare before redressing it.
function Model:_applyOutfit()
  if not self._actor or not self._outfit then return end
  for _, src in ipairs(self._outfit) do self._actor:TryOn(src) end
end

-- Remember the outfit to (re)apply after every model (re)load: a list of transmog
-- appearance sources (sourceIDs); an empty list = fully undressed. Applied now and
-- on each subsequent re-skin, so it survives the async model load. Call before
-- loading a new model (DisplayInfo/Unit) so the load callback honors it.
---@param sources number[]  itemModifiedAppearanceIDs; empty table = undressed
---@return Model
function Model:Outfit(sources)
  self._outfit = sources
  self:_applyOutfit()
  return self
end

-- Skin the actor with a creature display ID (a specific race + gender).
---@param creatureDisplayID number
---@param useCustomizations boolean?  overlay the active player's customizations (default false). Leave false for a pre-baked display (it carries its own race+gender textures); true only textures when the display matches the player's own race.
---@return Model
function Model:DisplayInfo(creatureDisplayID, useCustomizations)
  if self._actor then
    self:_reapply()   -- arm the one-shot load callback BEFORE loading
    self._actor:SetModelByCreatureDisplayID(creatureDisplayID, useCustomizations or false)
  end
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
    self:_reapply()   -- arm the one-shot load callback BEFORE loading
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

-- Scale the actor. The borrowed dressup scene renders every model through one
-- player-sized actor, so large races (Tauren, etc.) come out undersized; a per-race
-- multiplier corrects them. 1 = the actor's natural size. The value is remembered
-- and re-applied automatically after each async model load.
---@param scale number
---@return Model
function Model:Scale(scale)
  self._scale = scale   -- remembered so the model-loaded callback can re-apply it
  if self._actor then self._actor:SetScale(scale) end
  return self
end

---@return Model
function Model:Undress() if self._actor then self._actor:Undress() end; return self end

---@return Model
function Model:Dress() if self._actor then self._actor:Dress() end; return self end
