---@class LibNUI_ModelViewer: AddOn
local ns = LibNAddOn(...)
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

-- Which equipment slot an appearance source occupies, for Outfit's drop diff. Blizzard's own
-- two-step (Blizzard_Wardrobe_Sets.lua): source → invType → slot.
--
-- `GetSlotForInventoryType` returns an INVENTORY slot id — the same numbering UndressSlot and
-- SlotTransmog take — so its result is usable directly (measured in game: head 2→1, shoulder 4→3,
-- cloak 17→15, tabard 20→19, main hand 22→16, off hand 24→17). It returns **0** for anything with
-- no transmog slot at all: neck, finger, trinket, bag, ammo. Those are skipped, not stored.
--
-- The mapping is MANY-TO-ONE, which is why the diff below works in slots rather than sources: every
-- weapon invType (one-hand, shield, ranged, two-hand, main hand, off hand, ranged-right) collapses
-- onto a hand slot, and a robe lands on CHEST. Swapping a two-hander for a one-hander is therefore
-- correctly "the same slot, still occupied" rather than a drop.
--
-- Memoized because Outfit runs on every armour-slot toggle and GetSourceInfo isn't free; the mapping
-- is static per source. **Only successes are cached** — a source whose item data hasn't streamed yet
-- returns nothing, and caching that would make the miss permanent instead of self-healing.
local _slotForSource = {}
local function slotForSource(sourceID)
  local cached = _slotForSource[sourceID]
  if cached then return cached end
  local info = C_TransmogCollection.GetSourceInfo(sourceID)
  local slot = info and C_Transmog.GetSlotForInventoryType(info.invType)
  if slot and slot > 0 then
    _slotForSource[sourceID] = slot
    return slot
  end
end

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
---@field _slotMog table<number, {info: table, ignoreChildItems: boolean}>?  remembered per-slot ItemTransmogInfo (keyed by inventory slot), re-applied after each async model load
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
  -- A hidden frame gets neither mouse events nor OnUpdate, so a release that lands while the viewer
  -- is away (ESC closing the window, a tab switch) never reaches OnMouseUp: the drag would stay
  -- armed holding a cursor position from the previous session, and the next show would snap the yaw
  -- by however far the cursor travelled in between, then keep tracking it with no button held. The
  -- inertia is parked too, so the viewer comes back at rest instead of resuming a frozen flick.
  -- Nothing to forward here, unlike the handlers above: the template declares no OnHide.
  w:SetScript("OnHide", function()
    dragging = false
    self._yawVel = 0
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
    self:_applySlotMog()
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

-- Re-apply the remembered per-slot transmog overrides after every model (re)load,
-- AFTER _applyOutfit so a precise SlotTransmog wins over the base outfit for its slot.
-- SetItemTransmogInfo state (appearance + illusion + secondary) is wiped by an async
-- re-skin just like TryOn'd sources, so it must be re-applied on the load callback too.
-- The two WEAPON slots are written last, in a fixed order, behind a ResetNextHandSlot(). Ordinary
-- slots are independent of each other and go in whatever order `pairs` gives; the hands are not.
--
-- The actor keeps an internal "next hand slot" cursor deciding which hand a weapon lands in, and
-- `SetItemTransmogInfo` makes its own dual-wield judgement on top of it ("actor:SetItemTransmogInfo
-- will automatically handle whether the player can dual wield" — Blizzard_PerksProgramModel.lua).
-- Left to drift across re-applications, the second weapon claims the hand the first is already in
-- and a two-weapon look renders as one weapon. Blizzard's own two-weapon previews do exactly what
-- this does — reset the cursor, then off hand, then main hand — with the comment "Since we are
-- manually setting the 2 items in each hand, reset the actors sense of what hand to put stuff
-- into". The off-hand-first order is theirs too, and Blizzard_Transmog.lua gives the reason:
-- "offhand is processed first and mainhand might override offhand".
--
-- Symptom this fixes: a two-weapon look rendering as one weapon. The hand cursor is only half of
-- it — see the off-hand repair at the end, which handles the main-hand write clobbering the off
-- hand once both are addressed deterministically.
--
-- **A hand this call is not overriding is preserved, not stripped.** Overriding one hand does not
-- make the other one this function's business, even though clearing the pair is unavoidable.
function Model:_applySlotMog()
  if not self._actor or not self._slotMog then return end
  local mh, oh = self._slotMog[INVSLOT_MAINHAND], self._slotMog[INVSLOT_OFFHAND]
  for slot, rec in pairs(self._slotMog) do
    if slot ~= INVSLOT_MAINHAND and slot ~= INVSLOT_OFFHAND then
      self._actor:SetItemTransmogInfo(rec.info, slot, rec.ignoreChildItems)
    end
  end
  if not (mh or oh) then return end
  -- Clear both hands before re-placing them. Blizzard's own two-weapon previews undress the pair
  -- first and only then reset the cursor, and this runs on EVERY re-apply, so without it each pass
  -- stacks onto whatever the actor already had in those hands.
  --
  -- **Both hands are cleared even when only ONE is overridden** — so the base outfit's weapon or
  -- shield in the hand we are NOT overriding was undressed with nothing to re-place it, and a
  -- one-hander + shield look lost its shield to a main-hand-only override (#734). Scoping the
  -- undress to the overridden hand is NOT the fix: that reintroduces the stacking and the cursor
  -- drift the paragraph above exists to prevent. Capture the other hand first instead, and re-place
  -- it inside the same ordered write, so the pair still goes off-hand-first behind one cursor reset.
  --
  -- appearanceID 0 is NoTransmogID — "no override for this slot" rather than an appearance — so an
  -- empty hand reads back as 0 or nil and there is nothing to keep. Same guard, same reason, as the
  -- off-hand repair below documents at length.
  local function keptHand(slot)
    local h = self._actor:GetItemTransmogInfo(slot)
    if h and h.appearanceID and h.appearanceID ~= 0 then return h end
    return nil
  end
  local keepOH = (not oh) and keptHand(INVSLOT_OFFHAND) or nil
  local keepMH = (not mh) and keptHand(INVSLOT_MAINHAND) or nil
  self._actor:UndressSlot(INVSLOT_MAINHAND)
  self._actor:UndressSlot(INVSLOT_OFFHAND)
  self._actor:ResetNextHandSlot()
  if oh then self._actor:SetItemTransmogInfo(oh.info, INVSLOT_OFFHAND, oh.ignoreChildItems)
  elseif keepOH then self._actor:SetItemTransmogInfo(keepOH, INVSLOT_OFFHAND) end
  if mh then self._actor:SetItemTransmogInfo(mh.info, INVSLOT_MAINHAND, mh.ignoreChildItems)
  elseif keepMH then self._actor:SetItemTransmogInfo(keepMH, INVSLOT_MAINHAND) end

  -- **Re-place the off hand if the main-hand write took it away.** Measured: the off-hand write
  -- succeeds and the actor genuinely holds the weapon, then writing the main hand clears the
  -- off-hand slot back to nil — Blizzard's own "offhand is processed first and mainhand might
  -- override offhand" (Blizzard_Transmog.lua), which happens whatever the main hand's
  -- `secondaryAppearanceID` discriminator says. The result is that a second WEAPON never survives
  -- in the off hand; a shield or holdable does, which is why this went unnoticed until the
  -- off-hand dropdown started offering weapons at all (#661).
  --
  -- Verified rather than assumed: both slots are read back, and the repair only fires when the
  -- actor disagrees with what we asked for. Ordering alone can't fix this — writing the main hand
  -- first only moves the clobber onto the other weapon — and `TryOn`'s `handSlotName` is the one
  -- primitive that addresses a hand directly. Its `spellEnchantmentID` carries the illusion, so an
  -- enchanted off-hand survives the repair too.
  --
  -- Skipped when the request is appearanceID 0. That is NoTransmogID — it records "no override for
  -- this slot" rather than an appearance to verify, so there is nothing for the read-back to
  -- disagree with and nothing TryOn could re-place (source 0 is not "wear nothing"). Left unguarded
  -- the repair reads an empty hand slot back as nil, calls that a failed write, and fires
  -- TryOn(0, "SECONDARYHANDSLOT", 0) on every re-apply — three times per re-skin — to no effect.
  -- The comparison is appearance-only: an off hand whose illusion was clobbered alongside its
  -- appearance is repaired (TryOn's spellEnchantmentID carries it), but a clobbered
  -- secondaryAppearanceID is beyond TryOn's reach.
  -- Repairs a RESTORED off hand as well as an overridden one (#734). The main-hand write clobbers
  -- whatever the off hand holds, override or not — a shield just put back by `keepOH` is exactly as
  -- vulnerable as one the caller asked for, and gating this on `oh` alone would leave the case the
  -- restore was added to fix broken by the very next line. Exactly one of the two is ever set.
  local ohInfo = (oh and oh.info) or keepOH
  if ohInfo and ohInfo.appearanceID ~= 0 then
    local h = self._actor:GetItemTransmogInfo(INVSLOT_OFFHAND)
    if not (h and h.appearanceID == ohInfo.appearanceID) then
      self._actor:TryOn(ohInfo.appearanceID, "SECONDARYHANDSLOT", ohInfo.illusionID)
    end
  end
end

-- Remember the outfit to (re)apply after every model (re)load: a list of transmog
-- appearance sources (sourceIDs). Applied now and on each subsequent re-skin, so it
-- survives the async model load. Call before loading a new model (DisplayInfo/Unit) so
-- the load callback honors it.
--
-- **Setting an outfit removes the slots the previous one occupied that the new one doesn't** (#754),
-- so swapping to a shorter or different look in place no longer leaves the old pieces rendering.
-- Per-slot `SlotTransmog` overrides are unaffected — `ClearSlotTransmog` owns that lifecycle, and a
-- slot holding one is left alone here rather than having an override a caller set deliberately
-- pulled out from under it.
--
-- The diff lives HERE and not in _applyOutfit, which stays purely additive: that runs on every
-- re-skin backstop, three times per load, against an already-bare body, and stripping there flashed
-- the settled model. This runs once, on user intent, against a model that is already dressed.
--
-- Diffed in SLOTS rather than sources, because several appearances share one slot (every weapon
-- invType collapses onto a hand, a robe onto CHEST) — so replacing a two-hander with a one-hander
-- reads as "still occupied" and nothing flashes. Unchanged pieces are never touched at all, which
-- is what keeps this cheap on the busiest caller: a dressing-room armour-slot toggle changes one
-- entry, so the diff is at most that one slot.
--
-- The list is copied so a caller that goes on mutating its own (a look builder appending and
-- removing sources in place) can't silently change what the next model load re-applies.
---@param sources number[]  itemModifiedAppearanceIDs; empty table = undress every slot the previous outfit held
---@return Model
function Model:Outfit(sources)
  local prev = self._outfit
  self._outfit = ns.lua.lists.map(sources)
  self:_undressDroppedSlots(prev)
  self:_applyOutfit()
  return self
end

-- Take off the slots `prev` occupied that the new `_outfit` doesn't. No-op on the first Outfit
-- (nothing to drop) so a plain dress-up costs nothing.
---@param prev number[]?  the outfit being replaced
function Model:_undressDroppedSlots(prev)
  if not self._actor or not prev or #prev == 0 then return end
  local keep = {}
  for _, src in ipairs(self._outfit) do
    local slot = slotForSource(src)
    if slot then keep[slot] = true end
  end
  for _, src in ipairs(prev) do
    local slot = slotForSource(src)
    -- A source that won't resolve is skipped rather than guessed at: a missed strip is a cosmetic
    -- leftover, a wrong one removes a piece the caller asked for.
    if slot and not keep[slot] and not (self._slotMog and self._slotMog[slot]) then
      self._actor:UndressSlot(slot)
    end
  end
end

-- Forget the remembered outfit WITHOUT touching the actor: the model keeps rendering whatever it
-- shows, but no re-skin will re-apply the old list.
--
-- This is what `Outfit({})` used to be used for. Since Outfit gained its drop diff (#754) an empty
-- list means what it says — undress every slot the previous outfit held — so a caller that only
-- wanted to reset the bookkeeping before driving each slot itself needs to say so explicitly.
---@return Model
function Model:ForgetOutfit()
  self._outfit = nil
  return self
end

-- Precisely set ONE equipment slot's transmog, including the extras a bare TryOn can't
-- express: an enchant **illusion** (weapon slots), a **secondary appearance** (split shoulders) —
-- which doubles as a paired-artifact discriminator on the main hand, see below — and control over
-- child items.
-- Routes through the actor's SetItemTransmogInfo — the same primitive Blizzard's own
-- dressing room uses — so it composes with Outfit/TryOn (which set the base look): the
-- override is re-applied last for its slot after each async re-skin. `slot` is an inventory slot id
-- (INVSLOT_MAINHAND, INVSLOT_SHOULDER, …).
--
-- `appearanceID` 0 is NoTransmogID, which records "no override for this slot" — it does NOT mean
-- "wear nothing there". The actor keeps whatever it was last given, so a slot cleared that way goes
-- on rendering; to genuinely bare a slot use ClearSlotTransmog + UndressSlot instead (measured in
-- Warbandeer_Collected's DressingRoom:_bareSlot, where a cleared shirt kept rendering).
--
-- Typical illusion preview:
--   model:SlotTransmog(INVSLOT_MAINHAND, hostWeaponAppearanceID, { illusionID = sid })
--
-- `opts.secondaryAppearanceID` is SLOT-DEPENDENT, and on a weapon it is not an appearance at all:
-- on the SHOULDERS it is a genuine second appearance id (split shoulders), but on the MAIN HAND it
-- is a **discriminator** — Constants.Transmog.MainHandTransmogIsIndividualWeapon (-1) for an
-- ordinary weapon, MainHandTransmogIsPairedWeapon (0) for a Legion artifact whose off hand is
-- derived from it. Omitting it is not neutral: ItemTransmogInfoMixin:Init falls back to
-- NoTransmogID, which is also 0 = PAIRED, so an ordinary main-hand weapon comes out flagged as half
-- of a pair it has nothing to do with. That is a mislabelling trap, NOT the reason the off hand
-- gets clobbered — that happens whatever the discriminator says (see the read-back repair above).
---@param slot number  inventory slot id the transmog targets
---@param appearanceID number  itemModifiedAppearanceID for the slot (0 = NoTransmogID, i.e. "no override recorded" — it does NOT bare the slot; use ClearSlotTransmog + UndressSlot for that)
---@param opts {secondaryAppearanceID: number?, illusionID: number?, ignoreChildItems: boolean?}?  ignoreChildItems defaults true; secondaryAppearanceID is a real appearance on the shoulders but a DISCRIMINATOR on the main hand (-1 = ordinary weapon, 0 = paired Legion artifact — and 0 is also what omitting it means)
---@return Model
function Model:SlotTransmog(slot, appearanceID, opts)
  opts = opts or {}
  self._slotMog = self._slotMog or {}
  self._slotMog[slot] = {
    info = ItemUtil.CreateItemTransmogInfo(appearanceID, opts.secondaryAppearanceID, opts.illusionID),
    ignoreChildItems = opts.ignoreChildItems ~= false,   -- default true
  }
  self:_applySlotMog()
  return self
end

-- Forget a slot's SlotTransmog override so a subsequent re-skin no longer re-applies it
-- (the base Outfit/TryOn look then governs that slot again). Does not restrip the model
-- in place — call before a re-skin, or follow with a fresh Outfit/Dress. No-op if the
-- slot has no override.
---@param slot number  inventory slot id previously passed to SlotTransmog
---@return Model
function Model:ClearSlotTransmog(slot)
  if self._slotMog then self._slotMog[slot] = nil end
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

-- Strip a single equipment slot's item off the model, leaving the rest worn — the
-- removal half of a paper-doll per-slot toggle (TryOn re-adds a slot's piece, this
-- takes one off). Does not touch the remembered Outfit; the caller re-sets that so
-- an async re-skin honors the change.
---@param slot number  inventory slot id
---@return Model
function Model:UndressSlot(slot) if self._actor then self._actor:UndressSlot(slot) end; return self end
