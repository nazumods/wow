---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame = ui.Frame
local GetCursorPosition = GetCursorPosition

-- Blizzard's dressup model scene (DRESS_UP_FRAME_MODEL_SCENE_ID): borrowing it
-- gives us a full-body camera, lighting, and a dressable player actor we then
-- re-skin. A bare DressUpModel can't skin a race other than the player's (it
-- renders untextured/white) — only a ModelScene actor does it correctly.
local DRESSUP_SCENE = 596

-- Rotation-inertia bounds (rad/sec). SPIN_CUTOFF is where a glide is considered
-- stopped; SPIN_MAX clamps a single throw so a cursor warp can't launch the model.
local SPIN_CUTOFF = 0.04
local SPIN_MAX = 12

-- A ModelScene-backed 3D viewer: skin the actor (a unit, an arbitrary race via a
-- creature display ID, or a unit rendered as another race), then TryOn transmog
-- appearance sources. Left-drag rotates (actor yaw) with release inertia, right-drag
-- pans, wheel zooms. Pan + zoom are eased by the borrowed OrbitCamera's own DeltaLerp
-- interpolation; the actor-yaw rotation isn't routed through the camera, so we give
-- it the same feel ourselves (track throw speed while dragging, glide to a stop on
-- release via the engine's DeltaLerp).
---@class Model: Frame
---@field rotateSpeed number  radians of yaw applied per screen pixel dragged
---@field facing number  initial yaw (radians) applied on load so the model faces the camera; re-skinned models default to a side-on pose, so we quarter-turn it
---@field minZoom number  closest the camera may zoom in (scene units); widens the borrowed scene's tight 6–10 range so the wheel actually does something
---@field maxZoom number  farthest the camera may zoom out (scene units)
---@field spinFriction number  inertia decay per ideal 60fps frame (DeltaLerp amount toward 0); lower = longer glide after a flick
---@field spinTracking number  how quickly the tracked throw speed follows the cursor while dragging (DeltaLerp amount); de-spikes so placing the model still doesn't fling it
---@field _actor table?  the scene's player actor (backing model)
---@field _cam table?  the scene's active OrbitCamera (drives right-drag pan + wheel zoom)
---@field _yaw number  accumulated drag yaw in radians (internal); seeded from `facing`
---@field _yawVel number  current rotation speed in rad/sec (internal); carries the flick on release and decays to 0
---@field _naturalZoom number  the scene's natural zoom distance captured at construction; restored by ResetView
---@field _scale number  user scale multiplier, re-applied after each async model load (1 = the normalized size)
---@field _aggressiveness number  bounding-box normalization strength 0..1 (0 = the model's natural size, 1 = forced to ~human-male size); default 0 (opt-in)
---@field _outfit number[]?  remembered transmog sources, re-applied after each async model load (empty = undressed)
local Model = Class(Frame, function(self)
  -- Borrow the dressup scene so we inherit its camera + a player actor.
  self._widget:TransitionToModelSceneID(
    DRESSUP_SCENE, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
  self._actor = self._widget:GetPlayerActor()
  self._yaw = self.facing   -- seed so the model faces the camera, not side-on, on load
  self._yawVel = 0          -- no spin until the user flicks it
  self._scale = 1
  self._aggressiveness = 0   -- no normalization unless the caller opts in via Aggressiveness

  -- The OrbitCamera owns pan (right-drag) and zoom (wheel). We keep yaw on the ACTOR
  -- (left-drag) instead of the camera so re-skins don't disturb the framing. So: left
  -- mouse drives nothing on the camera; right drives pan; wheel drives zoom. (Y on the
  -- left/right is the snap arg; the modes themselves are unchanged from the defaults of
  -- leftY/rightY = NOTHING, wheel = ZOOM — we set them explicitly to be self-documenting.)
  local cam = self._widget:GetActiveCamera()
  self._cam = cam
  cam:SetLeftMouseButtonXMode(ORBIT_CAMERA_MOUSE_MODE_NOTHING)
  cam:SetLeftMouseButtonYMode(ORBIT_CAMERA_MOUSE_MODE_NOTHING)
  cam:SetRightMouseButtonXMode(ORBIT_CAMERA_MOUSE_PAN_HORIZONTAL)
  cam:SetRightMouseButtonYMode(ORBIT_CAMERA_MOUSE_PAN_VERTICAL)
  cam:SetMouseWheelMode(ORBIT_CAMERA_MOUSE_MODE_ZOOM)
  -- The dressup scene's camera info pins zoom to a tight 6–10, leaving the wheel barely
  -- any travel; widen it so the user can zoom in on the face / out to full body. Zoom is
  -- stored as a PERCENT of the min–max range, so widening alone re-maps the scene's
  -- starting percent to a much larger distance (the model loads way too far out). Capture
  -- the scene's natural distance first and restore it after, to keep the default framing.
  self._naturalZoom = cam:GetZoomDistance()
  cam:SetMinZoomDistance(self.minZoom)
  cam:SetMaxZoomDistance(self.maxZoom)
  cam:SetZoomDistance(self._naturalZoom)

  local w = self._widget
  w:EnableMouse(true)
  w:EnableMouseWheel(true)
  local dragging, lastX
  w:SetScript("OnMouseDown", function(_, button)
    -- Forward to the mixin so it tracks button state for the camera (pan needs to know
    -- the right button is held). Only the LEFT button drives our actor-yaw drag.
    w:OnMouseDown(button)
    if button == "LeftButton" then
      dragging = true
      lastX = (GetCursorPosition())
      self._yawVel = 0   -- grabbing the model halts any ongoing inertia glide
    end
  end)
  w:SetScript("OnMouseUp", function(_, button)
    w:OnMouseUp(button)
    if button == "LeftButton" then dragging = false end
  end)
  w:SetScript("OnMouseWheel", function(_, delta) w:OnMouseWheel(delta) end)
  w:SetScript("OnUpdate", function(_, elapsed)
    if not self._actor then return end
    -- Re-assert the intended scale every frame. An async re-skin resets the actor's
    -- scale when the load finishes, and on a cold first load that reset lands AFTER
    -- _reapply's backstop fires — wiping the per-race correction (the model would
    -- show at default size until the next race change). Polling here makes it stick
    -- regardless of load timing; it's idempotent and corrects within a frame.
    self:_applyScale()
    if dragging then
      local x = GetCursorPosition()
      local dyaw = (x - lastX) / w:GetEffectiveScale() * self.rotateSpeed
      lastX = x
      self._yaw = self._yaw + dyaw
      self._actor:SetYaw(self._yaw)
      -- Track the throw speed (rad/sec), DeltaLerp-smoothed so a cursor held still at
      -- the end of a drag decays toward zero — placing the model precisely doesn't
      -- fling it on release, only an actual flick carries inertia. Clamped so a cursor
      -- warp can't impart a runaway spin.
      local instant = elapsed > 0 and dyaw / elapsed or 0
      instant = math.max(-SPIN_MAX, math.min(SPIN_MAX, instant))
      self._yawVel = DeltaLerp(self._yawVel, instant, self.spinTracking, elapsed)
    elseif self._yawVel ~= 0 then
      -- Inertia: keep rotating after release, easing to a stop via the same DeltaLerp
      -- the OrbitCamera uses for zoom/pan, then snap to rest under the cutoff.
      self._yaw = self._yaw + self._yawVel * elapsed
      self._actor:SetYaw(self._yaw)
      self._yawVel = DeltaLerp(self._yawVel, 0, self.spinFriction, elapsed)
      if math.abs(self._yawVel) < SPIN_CUTOFF then self._yawVel = 0 end
    end
    -- Drive the camera ourselves: our SetScript replaced the template's OnUpdate, so the
    -- mixin's per-frame camera step (pan/zoom interpolation) no longer runs unless we call
    -- it. With leftX = NOTHING this can't fight our left-drag actor yaw.
    w:OnUpdate(elapsed)
  end)
end, {
  type = "ModelScene",
  template = "ModelSceneMixinTemplate",
  rotateSpeed = 0.01,
  facing = -math.rad(88),   -- just shy of a quarter-turn from the side-on default, facing the camera
  minZoom = 2,
  maxZoom = 16,
  spinFriction = 0.05,      -- ~1s glide to rest after a flick
  spinTracking = 0.5,       -- responsive throw-speed tracking while dragging
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
    self:_applyScale()
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
-- what's worn via TryOn. `useNativeForm` is the unit's native vs altered form (Worgen
-- human, Dracthyr visage); it follows the unit's own alternate-form state, so it only
-- has an effect when the *unit* (not customRaceID) has one. Defaults to native (true).
---@param token string  unit token (e.g. "player")
---@param customRaceID number?  chrRaceID to render the unit as
---@param useNativeForm boolean?  unit native (true, default) vs altered form
---@return Model
function Model:Unit(token, customRaceID, useNativeForm)
  if self._actor then
    if useNativeForm == nil then useNativeForm = true end
    self:_reapply()   -- arm the one-shot load callback BEFORE loading
    self._actor:SetModelByUnit(token, false, false, false, useNativeForm, false, customRaceID)
  end
  return self
end

---@param source string|number  item link or itemModifiedAppearanceID (sourceID)
---@return Model
function Model:TryOn(source)
  if self._actor then self._actor:TryOn(source) end
  return self
end

-- Scale the actor as a user multiplier on top of the normalized size (see
-- Aggressiveness): 1 = the normalized size, >1 zooms in, <1 out. Remembered and
-- re-applied automatically after each async model load.
---@param scale number?
---@return number|Model
function Model:Scale(scale)
  if scale == nil then return self._scale end
  self._scale = scale   -- remembered so OnUpdate re-asserts it every frame
  self:_applyScale()
  return self
end

-- Apply the actor scale through the engine's bounding-box normalization. The borrowed
-- dressup scene renders every model through one player-sized actor, so races at their
-- natural size come out wildly inconsistent; SetNormalizedScaleAggressiveness fits each
-- model toward ~human-male dimensions instead, with _aggressiveness controlling how
-- strongly (0 = natural size, 1 = forced). _scale rides on top as a user multiplier.
-- UpdateScale recomputes effectiveScale = requestedScale * (1/maxBoundingBoxScale) and
-- calls SetScale itself; the setters only mark dirty when a value changes, so per-frame
-- calls are no-ops once settled, and an async re-skin's OnModelLoaded re-marks dirty and
-- re-normalizes automatically.
function Model:_applyScale()
  if not self._actor then return end
  self._actor:SetNormalizedScaleAggressiveness(self._aggressiveness)
  self._actor:SetRequestedScale(self._scale)
  self._actor:UpdateScale()
end

-- Set the bounding-box normalization strength (0 = the model's natural size, 1 = forced
-- to ~human-male size). A mid value keeps some racial size character while bounding the
-- extremes. Remembered and re-applied after each async model load.
---@param v number?
---@return number|Model
function Model:Aggressiveness(v)
  if v == nil then return self._aggressiveness end
  self._aggressiveness = v
  self:_applyScale()
  return self
end

-- Impart (or read) the model's rotation speed in radians/sec. A non-zero value spins
-- the model and eases to a stop with the same inertia as a mouse flick — handy for a
-- programmatic showcase spin or to stop one (Spin(0)). Read returns the live speed.
---@param v number?
---@return number|Model
function Model:Spin(v)
  if v == nil then return self._yawVel end
  self._yawVel = v
  return self
end

-- Restore the view to its load defaults: the facing yaw (cancelling any spin), the
-- scene's natural zoom, and no pan. The user scale multiplier is a separate control
-- (see Scale) and is left untouched. No-op until the actor/camera exist.
---@return Model
function Model:ResetView()
  self._yaw = self.facing
  self._yawVel = 0
  if self._actor then self._actor:SetYaw(self._yaw) end
  if self._cam then
    self._cam.panningXOffset = 0
    self._cam.panningYOffset = 0
    self._cam:SetZoomDistance(self._naturalZoom)
  end
  return self
end

---@return Model
function Model:Undress() if self._actor then self._actor:Undress() end; return self end

---@return Model
function Model:Dress() if self._actor then self._actor:Dress() end; return self end
