---@type Warbandeer_Collected
local ns = select(2, ...)
local GetClassInfo = GetClassInfo
local GetAtlasInfo = C_Texture.GetAtlasInfo
local GetAllSourceIDs = C_TransmogSets.GetAllSourceIDs
local DressingRoom = ns.DressingRoom

-- Model dressing (Dress) + the class icon / expansion badge / class backdrop / tier-bar
-- rendering, plus the shared ShowDressingRoom / HideDressingRoom entry points and the
-- dev preview helpers. Reopens the DressingRoom class.
local k = DressingRoom._k
local SELECTED, IDLE, tierBar = k.SELECTED, k.IDLE, k.tierBar

-- The transmog sources the model should currently wear: the previewed set's full
-- appearance list (`GetAllSourceIDs`) minus the sources of any slot the user has
-- toggled off (`_hiddenSlots`). Sources that map to no shown slot — e.g. weapons —
-- have no toggle and always stay on. Shared by Dress (a full re-skin) and the
-- in-place slot/undress toggles (which avoid a reload).
---@return number[]
function DressingRoom:_currentSources()
  local sources = {}
  for _, src in ipairs(GetAllSourceIDs(self._set.id)) do
    local slot = ns.SourceSlot(src)
    if not (slot and self._hiddenSlots[slot]) then sources[#sources + 1] = src end
  end
  return sources
end

-- Render the selected race on a DRESSABLE actor, then put on the previewed set.
-- We always use the customRaceID-overridden player unit: it renders any race
-- textured AND can wear transmog / undress. The exact-gender creature-display path
-- (Model:DisplayInfo) is a static NPC whose baked gear can't be removed or dressed
-- over, so it can't show a set — hence the gender follows the logged-in character
-- (see _syncGenderToggle). Sizing is handled by the model's bounding-box normalization.
function DressingRoom:Dress()
  if not self._set then return end
  -- The body always renders as the logged-in character's gender (it can't be
  -- overridden), and the race defaults to theirs until one is picked. Seed the race
  -- here so it always resolves regardless of how Dress was reached (the open path
  -- doesn't always run _defaultToPlayer); _sex is tracked for reference/debug only.
  if not self._raceID then self._raceID = ns.CanonRace(select(3, UnitRace("player"))) end
  self._sex = UnitSex("player")
  local m = self._model
  -- Multi-form races resolve through the selected form (for its `normalize` override);
  -- others are the entry itself.
  local form = self:_resolvedForm()

  -- Weapon-cosmetic groups preview a held weapon, not armor — a separate render path.
  if self._group and self._group.kind then return self:_dressWeapon(m, form) end

  -- Decide the outfit BEFORE (re)loading the model. The re-skin loads async and
  -- resets the actor to its default body once the load finishes, so the model
  -- re-applies this on its load callback (Model:Outfit). _currentSources drops the
  -- pieces the user toggled off (all slots off = undressed).
  m:Outfit(self:_currentSources())

  -- Set normalization BEFORE the re-skin: `Model:Unit` arms the re-apply machinery
  -- (load callback + backstop) right then, and a synchronous load (e.g. the logged-in
  -- character's own race on first open, already in memory) re-applies immediately — so
  -- the strength must already be correct or the model renders at the previous one until
  -- the next race change. Per-race sizing is automatic; an optional `normalize` override
  -- (entry or form) replaces the global strength for exceptions (Dracthyr's wingspan).
  -- The user scale slider rides on top as a multiplier, reset to 1 per race.
  m:Aggressiveness(form and form.normalize or ns.NORMALIZE_AGGRESSIVENESS)
  m:Scale(1)
  self._scaleSlider:Value(1)

  -- A form may override the render race (Worgen's "Human" form → race 1, rendered as a
  -- plain Human) or select the unit's native/altered form (Dracthyr dragon/visage via
  -- `useNativeForm`); otherwise render the selected race in its native form.
  --
  -- When the resolved race is the player's OWN race, pass NO customRaceID: the visage
  -- (altered form) is customization-driven and only textures when rendered as the player's
  -- actual unit. A customRaceID override — even the matching id — loads a base race with no
  -- customizations, so the visage comes out untextured (white); the baked native dragon
  -- survives it, which is why only the visage breaks. nil renders the player's real race +
  -- customizations, and lets `useNativeForm` actually take effect (it's a no-op under an
  -- override). Other races keep the customRaceID override.
  local _, _, playerRace = UnitRace("player")
  local renderRace = (form and form.race) or self._raceID
  if renderRace == ns.CanonRace(playerRace) then renderRace = nil end
  m:Unit("player", renderRace, form and form.useNativeForm)
end

-- The player's equipped main-hand appearance (itemModifiedAppearanceID) — the host
-- weapon an illusion's enchant shimmer renders on (an illusion has nothing to sit on
-- by itself). nil when nothing's equipped.
---@return number?
function ns.HostWeaponAppearance()
  local mh = GetInventoryItemID("player", INVSLOT_MAINHAND)
  return mh and select(2, C_TransmogCollection.GetItemInfo(mh)) or nil
end

-- Weapon-cosmetic preview (#516): render the char's race holding the previewed piece —
-- an arsenal weapon appearance (via Outfit → TryOn), or a host weapon with the enchant
-- illusion layered on (via Model:SlotTransmog). Bare body; the focus is the weapon. The
-- up/down nav cycles `_weaponPiece` through the cell's pieces (see StepTierVisual).
-- Decision B: the logged-in character's race only.
---@param m Model
---@param form table?
function DressingRoom:_dressWeapon(m, form)
  local set = self._set
  local idx = self._weaponPiece or 1
  m:ClearSlotTransmog(INVSLOT_MAINHAND)
  if self._group.weaponCell then
    -- Weapon-cell preview: the chosen weapon's current colour variant (looks grouped by item).
    -- FORCE it onto the hand with SlotTransmog rather than Outfit — Outfit drops a weapon the
    -- character's class can't equip (an axe wouldn't show for a caster), while SlotTransmog renders
    -- any appearance on any character (the look-builder relies on this). Shields/off-hands → off hand.
    -- Render the SPECIFIC appearance's source (WeaponSource picked it per visualID), NOT the item's
    -- default modified-appearance: GetItemInfo(itemID) returns the base-difficulty look, so several
    -- distinct visuals of one base weapon (e.g. difficulty recolours) would all collapse to one render.
    -- SlotTransmog takes an appearance sourceID directly, exactly as the look-builder does.
    local look = set._looks[idx]
    m:Outfit({})   -- bare body; the weapon is the focus, forced on below
    m:ClearSlotTransmog(INVSLOT_OFFHAND)
    if look and look.sourceID then m:SlotTransmog(set._offHand and INVSLOT_OFFHAND or INVSLOT_MAINHAND, look.sourceID) end
  elseif self._group.kind == "illusion" then
    m:Outfit({})   -- bare; the illusion rides the host weapon applied below
    local piece = set.illusions[idx]
    local host = ns.HostWeaponAppearance()
    if piece and host then m:SlotTransmog(INVSLOT_MAINHAND, host, { illusionID = piece.sourceID }) end
  else   -- arsenal: preview the one weapon appearance
    local itemID = set.pieces[idx]
    local ima = itemID and select(2, C_TransmogCollection.GetItemInfo(itemID))
    m:Outfit(ima and { ima } or {})
  end

  self:_titleWeapon()   -- surface the previewed piece's real name in the title bar

  m:Aggressiveness(form and form.normalize or ns.NORMALIZE_AGGRESSIVENESS)
  m:Scale(1)
  self._scaleSlider:Value(1)
  local _, _, playerRace = UnitRace("player")
  local renderRace = (form and form.race) or self._raceID
  if renderRace == ns.CanonRace(playerRace) then renderRace = nil end
  m:Unit("player", renderRace, form and form.useNativeForm)
end

-- Title the window with the previewed weapon piece's real name (+ position when the
-- cell holds several: "Frostbrand (2/5)"). Illusion names resolve synchronously via
-- GetIllusionStrings; arsenal item names load async, so retitle shortly (capped, no
-- re-skin) until the name is cached, guarding against a set/piece change mid-wait.
function DressingRoom:_titleWeapon()
  local set, idx = self._set, self._weaponPiece or 1
  local name, count
  if self._group.weaponCell then
    count = #set._looks
    local look = set._looks[idx]
    name = look and C_Item.GetItemNameByID(look.itemID)
    if look and not name then C_Item.RequestLoadItemDataByID(look.itemID) end
    if name and look.difficulty then name = name .. " — " .. look.difficulty end   -- disambiguate difficulty recolours
  elseif self._group.kind == "illusion" then
    count = #set.illusions
    local piece = set.illusions[idx]
    name = piece and C_TransmogCollection.GetIllusionStrings(piece.sourceID)
  else
    count = #set.pieces
    local itemID = set.pieces[idx]
    name = itemID and C_Item.GetItemNameByID(itemID)
    if itemID and not name then C_Item.RequestLoadItemDataByID(itemID) end
  end
  self:Title((name or set.name) .. (count and count > 1 and (" (%d/%d)"):format(idx, count) or ""))

  if self._weaponTitleTimer then self._weaponTitleTimer:Cancel(); self._weaponTitleTimer = nil end
  if not name and (self._weaponTitleTries or 0) < 10 then
    self._weaponTitleTries = (self._weaponTitleTries or 0) + 1
    self._weaponTitleTimer = C_Timer.NewTimer(0.2, function()
      self._weaponTitleTimer = nil
      if self._set == set and (self._weaponPiece or 1) == idx then self:_titleWeapon() end
    end)
  else
    self._weaponTitleTries = 0
  end
end

-- Point the title-bar class icon at the class in column `classId` (hidden if the
-- id is missing or has no class icon). `group.sets` is positional — the array
-- index is the classId — so callers pass the set's index, not `set.classId`
-- (which is only populated for the earliest groups).
---@param classId number?
function DressingRoom:_showClass(classId)
  local name, file
  if classId then name, file = GetClassInfo(classId) end
  self._className = name   -- localized class name for the icon's hover tooltip
  local lower = file and file:lower()
  local atlas = lower and ("classicon-" .. lower)
  if atlas and GetAtlasInfo(atlas) then
    self._classIcon:Atlas(atlas)
    self._classIcon:Show()
  else
    self._classIcon:Hide()
  end
  self:_setBackground(lower)   -- class-themed model backdrop
end

-- Point the bottom-right expansion badge at the set-group's release (hidden if the
-- index is missing or has no icon). `release` indexes ns.Releases / ns.ReleaseIcons.
---@param release number?
function DressingRoom:_showRelease(release)
  local path = release and ns.ReleaseIcons[release]
  self._expName = release and ns.Releases[release]
  if path then
    self._expIcon:Texture(path)
    self._expIcon:Show()
  else
    self._expIcon:Hide()
  end
end

-- Remember the class for the model backdrop and (re)apply it. The atlas
-- (`dressingroom-background-<class>`) is a managed atlas sheet that only streams in when
-- `SetAtlas` runs on a *shown* texture — so a class set during `_load` (before the frame
-- is Show()n on a fresh open) never queues the load. `_applyBackground` does the actual
-- work and is re-run after Show() (see ShowDressingRoom) to catch that case.
---@param classFile string?  lowercased class file (e.g. "warrior")
function DressingRoom:_setBackground(classFile)
  self._bgClass = classFile
  self:_applyBackground()
end

-- Apply the remembered class backdrop (or hide it when the toggle is off / no class).
-- `SetAtlas` is a no-op when the atlas is unchanged and won't re-queue a sheet that
-- failed to stream the first time (e.g. set while the frame was hidden), so clear the
-- texture first to force a fresh load every time this runs on a shown frame.
function DressingRoom:_applyBackground()
  if self._bgEnabled and self._bgClass then
    self._bg:Texture(nil)   -- force SetAtlas to re-trigger the sheet stream
    self._bg:Atlas("dressingroom-background-" .. self._bgClass, false)   -- false = stretch to the model rect
    self._bg:Show()
  else
    self._bg:Hide()
  end
end

-- Color the slot-column backdrop bars for the raid's difficulty tier (parsed from
-- the group name). Each bar fades from BARALPHA at its outer window edge to 0 at the
-- inner model edge.
---@param groupName string?  the set-group's name (carries the "(Difficulty)" suffix)
function DressingRoom:_setTierBars(groupName)
  local c, outerA, innerA = tierBar(groupName)
  local outer = CreateColor(c.r, c.g, c.b, outerA)
  local inner = CreateColor(c.r, c.g, c.b, innerA)
  self._tierBarL:Gradient("HORIZONTAL", outer, inner)   -- window edge → model edge
  self._tierBarR:Gradient("HORIZONTAL", inner, outer)   -- model edge → window edge
  self._tierBarL:Show()
  self._tierBarR:Show()
end

---@param on boolean  show the class-themed model backdrop
function DressingRoom:SetBackgroundOn(on)
  self._bgEnabled = on
  self._bgBorder:Color(on and SELECTED or IDLE)
  self:_setBackground(self._bgClass)
end

local _room

---Open the shared dressing room previewing a class set on a selectable race/gender.
---@class Warbandeer_Collected
---@field ShowDressingRoom fun(group: table, set: table)  group/set are entries from ns.Sets
ns.ShowDressingRoom = function(group, set)
  -- A set the local client has no appearance data for — a PTR-only "upcoming" set on a
  -- live client: there's nothing for the 3D model to render, so don't open an empty
  -- viewer; point the user to the PTR instead. On a PTR client these resolve and the
  -- preview opens normally. (Live sets, incl. Trading Post variants, always return pieces
  -- here.) Weapon-cosmetic groups (kind) have synthetic ids with no C_TransmogSets
  -- sources, so skip this gate — they render via _dressWeapon on the char's own race.
  if not (group and group.kind) and set and set.id then
    local src = GetAllSourceIDs(set.id)
    if not src or #src == 0 then
      ns.Print(('"%s" is upcoming on the PTR — log into the PTR to preview it in 3D.'):format(set.name or ("set " .. tostring(set.id))))
      return
    end
  end

  if not _room then
    _room = DressingRoom:new{}
    _room:RememberPosition(ns.db.dressPos)   -- restore + persist the user's dragged position
    -- Clear the grid row highlight whenever the room closes — via OnHide so every path
    -- lands here (Escape/UISpecialFrames, the close button, and HideDressingRoom alike).
    _room._widget:HookScript("OnHide", function()
      ns:NotifyDressedSetChanged(nil)
      ns:NotifyDressedWeaponCellChanged(nil)
    end)
  end

  -- Reset to the current character's race on a fresh open — the first ever (no race
  -- picked yet) or a reopen after closing; clicking another cell while it's already
  -- open keeps the chosen race. The IsShown check alone misses the first open (the
  -- frame is shown on creation), so also seed when `_raceID` is still unset.
  if not _room._raceID or not _room._widget:IsShown() then _room:_defaultToPlayer() end

  _room:_load(group, set)
  _room:Show()
  _room:_applyBackground()   -- re-trigger the atlas-sheet stream now the frame is shown (a set made while hidden never queues the load)
end

---Hide the shared dressing room (no-op if never opened).
---@class Warbandeer_Collected
---@field HideDressingRoom fun()
ns.HideDressingRoom = function()
  if _room then _room:Hide() end
end

---The shared dressing room while it's on screen, else nil — the entry point for anything that
---acts on "the look currently being previewed" (the outfit compose/export path, the
---`/collected outfit` commands). Deliberately nil for a closed room rather than a hidden
---instance, so callers get one "nothing to act on" answer instead of two.
---@class Warbandeer_Collected
---@field OpenDressingRoom fun(): DressingRoom?
ns.OpenDressingRoom = function()
  if _room and _room._widget:IsShown() then return _room end
end


---Dev/verify helper: force a raw creature display id into the open dressing room
---model so a candidate RaceModels id can be eyeballed (no-op if not open). The
---next race/gender/form change reverts to the configured model. Used by
---`/collected model <id>`.
---@class Warbandeer_Collected
---@field PreviewModelID fun(id: number, useCustomizations: boolean?)
ns.PreviewModelID = function(id, useCustomizations)
  if _room and _room._widget:IsShown() then _room._model:DisplayInfo(id, useCustomizations) end
end

---Dev/verify helper: force an expansion badge into the open dressing room by
---release index (1=Vanilla .. 12=Midnight), to eyeball each icon without
---navigating to a set from that expansion. Reverts on the next set load.
---`/collected release <n>`.
---@class Warbandeer_Collected
---@field PreviewRelease fun(release: number)
ns.PreviewRelease = function(release)
  if _room and _room._widget:IsShown() then _room:_showRelease(release) end
end

---Dev/verify helper: live-set the open preview model's scale, to tune a race's
---`scale` correction (reverts on the next race/gender/form change). `/collected scale`.
---@class Warbandeer_Collected
---@field PreviewModelScale fun(scale: number)
ns.PreviewModelScale = function(scale)
  if _room and _room._widget:IsShown() then _room._scaleSlider:Value(scale) end
end

---Dev: live-set the open preview model's normalization strength (0..1), to tune a
---race's `normalize` override (reverts on the next race/gender/form change).
---`/collected normalize`.
---@class Warbandeer_Collected
---@field PreviewNormalize fun(v: number)
ns.PreviewNormalize = function(v)
  if _room and _room._widget:IsShown() then _room._model:Aggressiveness(v) end
end

---Dev: dump the open preview's scale state, to tell a wrong value from a wrong
---application (`/collected scale` with no arg).
---@class Warbandeer_Collected
---@field DebugDressScale fun()
ns.DebugDressScale = function()
  if not _room then ns.Print("dressing room not opened yet"); return end
  local form = _room:_resolvedForm()
  ns.Print(("raceID=%s sex=%s form.normalize=%s | aggressiveness=%s | scale=%s | slider=%s | shown=%s"):format(
    tostring(_room._raceID), tostring(_room._sex), tostring(form and form.normalize),
    tostring(_room._model:Aggressiveness()), tostring(_room._model:Scale()),
    tostring(_room._scaleSlider:Value()), tostring(_room._widget:IsShown())))
end
