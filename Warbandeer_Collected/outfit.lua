---@type Warbandeer_Collected
local ns = select(2, ...)
local GetSourceInfo = C_TransmogCollection.GetSourceInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetAppearanceSourceInfo = C_TransmogCollection.GetAppearanceSourceInfo
local PlayerCanCollectSource = C_TransmogCollection.PlayerCanCollectSource
local GetCustomSets = C_TransmogCollection.GetCustomSets
local GetCustomSetInfo = C_TransmogCollection.GetCustomSetInfo
local GetCustomSetList = C_TransmogCollection.GetCustomSetItemTransmogInfoList
local GetNumMaxCustomSets = C_TransmogCollection.GetNumMaxCustomSets
local IsValidCustomSetName = C_TransmogCollection.IsValidCustomSetName

-- The WoW-side half of the outfit layer: reading and writing the game's own **custom sets**
-- store, and the validation an outfit needs before it can go in there. The pure `/customset v1`
-- codec is the sibling outfitcodec.lua; the room-coupled compose/apply is
-- controls/DressingRoomOutfit.lua.
--
-- Custom sets are the 12.0 replacement for the old outfits API (`GetOutfits` / `NewOutfit` /
-- `ModifyOutfit`, all removed). They are the saved-appearance sets the transmogrifier offers.
-- The separate `C_TransmogOutfitInfo` namespace is a different thing — the *worn* outfit with
-- its pending transmogs, situations and gold cost — and is deliberately untouched here.
--
-- Every function below is addon-callable: the C side documents them `SecretArguments =
-- "AllowedWhenUntainted"` with no secure-execution requirement.

-- Inventory slot id -> localized label, for the human-readable summary. Read through _G at call
-- time (the same idiom weaponbrowser.lua uses for its source strings) so no new globals need
-- registering, and a client missing one falls back to the slot number rather than erroring.
local SLOT_LABEL = {
  [INVSLOT_HEAD] = "HEADSLOT", [INVSLOT_SHOULDER] = "SHOULDERSLOT", [INVSLOT_BACK] = "BACKSLOT",
  [INVSLOT_CHEST] = "CHESTSLOT", [INVSLOT_BODY] = "SHIRTSLOT", [INVSLOT_TABARD] = "TABARDSLOT",
  [INVSLOT_WRIST] = "WRISTSLOT", [INVSLOT_HAND] = "HANDSSLOT", [INVSLOT_WAIST] = "WAISTSLOT",
  [INVSLOT_LEGS] = "LEGSSLOT", [INVSLOT_FEET] = "FEETSLOT",
  [INVSLOT_MAINHAND] = "MAINHANDSLOT", [INVSLOT_OFFHAND] = "SECONDARYHANDSLOT",
}

---@class Warbandeer_Collected
---@field SlotLabel fun(slotID: number): string
---@field SanitizeOutfit fun(list: table[]): table[]
---@field OutfitIssues fun(list: table[]): { pending: boolean, filled: number }
---@field OutfitIcon fun(list: table[]): number?
---@field OutfitSummary fun(list: table[]): string
---@field CustomSets fun(): { id: number, name: string, icon: number }[]
---@field CustomSetOutfit fun(customSetID: number): table[]?
---@field ClassLabel fun(classFile: string?): string?
---@field ClassColored fun(text: string, classFile: string?): string
---@field OutfitArmorType fun(list: table[]): string
---@field OutfitOrigin fun(entry: LibraryOutfit): string
---@field SaveCustomSet fun(name: string, list: table[], customSetID: number?): number?, string?
---@field RenameCustomSet fun(customSetID: number, name: string): boolean, string?
---@field DeleteCustomSet fun(customSetID: number)

---Localized name for an equipment slot ("Head", "Shirt", "Tabard", …).
---@param slotID number
---@return string
function ns.SlotLabel(slotID)
  local key = SLOT_LABEL[slotID]
  return (key and _G[key]) or ("slot " .. tostring(slotID))
end

---Drop a decoded shoulder secondary that isn't actually a shoulder appearance.
---
---This is the one validation the codec deliberately leaves out — it needs the appearance API, and
---outfitcodec.lua stays WoW-free so it can be unit-tested. Mirrors the same guard in Blizzard's
---own parser: a hand-edited or corrupted string could otherwise put an arbitrary appearance into
---the split-shoulder field, where the model would try to render it as a shoulder. Mutates and
---returns the list.
---@param list table[]
---@return table[]
function ns.SanitizeOutfit(list)
  local info = list[INVSLOT_SHOULDER]
  local secondary = info and info.secondaryAppearanceID or 0
  if secondary and secondary ~= 0 then
    local src = GetAppearanceSourceInfo(secondary)
    if not (src and src.category == Enum.TransmogCollectionType.Shoulder) then
      info.secondaryAppearanceID = 0
    end
  end
  return list
end

---What would stop this outfit being written yet: how many slots it fills, and whether the answer
---is still knowable.
---
---`pending` means item data is still streaming, so the caller should wait rather than write from a
---half-known list.
---
---**There is deliberately no "this character can't use it" check**, though two earlier revisions
---had one. Both premises were measured false in game (2026-07-22):
---
---* *"The game drops slots this character can't collect."* That clearing lives in Blizzard's
---  `WardrobeCustomSetManager:EvaluateAppearances`, a **UI-layer** step. A direct
---  `C_TransmogCollection.NewCustomSet` call never goes through it — a plate set saved from a
---  Druid round-tripped complete, every slot intact.
---* *"`PlayerCanCollectSource`'s `canCollect` reports armour-type/class validity."* It doesn't.
---  On a Druid, with the wardrobe class filter correctly reading Druid, a plate appearance still
---  answered `canCollect = true`. The flag can't distinguish the case it was being used for.
---
---Wearing such a set at a transmogrifier is a separate gate and may well refuse — but that is an
---*application* question, not a *storage* one, and `PlayerCanCollectSource` is not the signal for
---it (`C_Transmog.CanTransmogItemWithItem` and the slot-level checks are the honest source).
---@param list table[]
---@return { pending: boolean, filled: number }
function ns.OutfitIssues(list)
  local out = { pending = false, filled = 0 }
  for _, slotID in ipairs(ns.OutfitSlotOrder) do
    local info = list[slotID]
    local appearanceID = info and info.appearanceID or 0
    if appearanceID > 0 then
      out.filled = out.filled + 1
      if not (PlayerCanCollectSource(appearanceID)) then out.pending = true end
    end
  end
  return out
end

---Icon for a saved custom set: the first filled slot's appearance icon, matching how Blizzard
---picks one. nil when the outfit is empty or nothing resolves yet.
---
---Hide visuals are skipped (#654): a look whose head slot is hidden is still a look *about* its
---other pieces, and "Hidden Helm" makes a useless library thumbnail for it.
---@param list table[]
---@return number?
function ns.OutfitIcon(list)
  for _, slotID in ipairs(ns.OutfitSlotOrder) do
    local info = list[slotID]
    local appearanceID = info and info.appearanceID or 0
    if appearanceID > 0 and not ns.IsHideVisual(slotID, appearanceID) then
      local src = GetAppearanceSourceInfo(appearanceID)
      if src and src.icon then return src.icon end
    end
  end
end

---A human-readable listing of an outfit — one line per filled slot. Feeds the copy window behind
---`/collected outfit export`, so what the string encodes can be eyeballed against what the model
---shows.
---
---`not owned` marks collection state only — it costs nothing to share and saves fine. There is no
---"unusable" marker any more: the claim it made (that such slots are dropped on save) was measured
---false, see `ns.OutfitIssues`.
---@param list table[]
---@return string
function ns.OutfitSummary(list)
  local lines = {}
  for _, slotID in ipairs(ns.OutfitSlotOrder) do
    local info = list[slotID]
    local appearanceID = info and info.appearanceID or 0
    if appearanceID > 0 then
      local src = GetSourceInfo(appearanceID)
      local extra = ""
      if info.illusionID and info.illusionID > 0 then
        extra = extra .. (" + illusion %d"):format(info.illusionID)
      end
      if info.secondaryAppearanceID and info.secondaryAppearanceID > 0 then
        extra = extra .. (" + secondary %d"):format(info.secondaryAppearanceID)
      end
      -- `src.isCollected` is the same per-source ownership flag the paper-doll slots colour their
      -- borders from, so this column matches the green/red the user is looking at.
      lines[#lines + 1] = ("%-14s %-8d %s%s%s"):format(
        ns.SlotLabel(slotID), appearanceID,
        (src and src.name) or "(name pending)", extra,
        (src and not src.isCollected) and "   (not owned)" or "")
    end
  end
  if #lines == 0 then return "(empty outfit)" end
  return table.concat(lines, "\n")
end

-- ── Provenance (who saved a library look, and what it's for) ───────────────────--
--
-- The WoW-side half of the outfit library: deriving the fields a save records, and rendering them.
-- Kept out of outfitlibrary.lua deliberately — that file is pure Lua over `ns.db` + the codec so it
-- can be unit-tested, and every function here needs a `C_*` call or a FrameXML global.

local _classNames   -- [classFile] = localized name, built once
local _classIds     -- [classFile] = class id, filled by the same sweep

-- `GetClassInfo` maps id → (name, file) and there is no reverse lookup, so a sweep is the only way
-- back from a class file — and one sweep answers both directions, so both maps are filled together.
-- (`LOCALIZED_CLASS_NAMES_*` would mean whitelisting another global in two config files.)
local function buildClassMaps()
  if _classNames then return end
  _classNames, _classIds = {}, {}
  for id = 1, #ns.icons.classes do
    local name, file = GetClassInfo(id)
    if file then _classNames[file], _classIds[file] = name, id end
  end
end

---Localized class name for a class file ("DRUID" → "Druid"), or the file itself if it doesn't
---resolve.
---@param classFile string?
---@return string?
function ns.ClassLabel(classFile)
  if not classFile then return nil end
  buildClassMaps()
  return _classNames[classFile] or classFile
end

---The class id for a class file ("PRIEST" → 5), or nil if it doesn't resolve. The inverse of what
---`GetClassInfo` offers, which is why it shares `ClassLabel`'s sweep. Needed because the library
---stores a look's provenance as a class FILE, while the room's `_showClass` — like the grid it was
---written for — addresses classes by id.
---@param classFile string?
---@return number?
function ns.ClassId(classFile)
  if not classFile then return nil end
  buildClassMaps()
  return _classIds[classFile]
end

---Whether a main-hand appearance is a **paired Legion artifact** — the one weapon kind whose
---off-hand is derived from the main hand rather than picked.
---
---This is the input to the main-hand slot's `secondaryAppearanceID`, which is a DISCRIMINATOR and
---not an appearance id: `MainHandTransmogIsIndividualWeapon` (-1) says "an ordinary weapon",
---`MainHandTransmogIsPairedWeapon` (0) says "derive the off-hand from me". Both the render path
---(`DressingRoom:_applyLook`) and the save path (`DressingRoom:ComposeOutfit`) have to answer this
---the same way, which is why the question lives here rather than in either of them.
---
---Getting it wrong is not cosmetic: `ItemTransmogInfoMixin:Init` defaults a nil secondary to 0, so
---a main-hand set without one is flagged PAIRED, and Blizzard's own transmog code notes that a
---paired main-hand overrides the off-hand ("offhand is processed first and mainhand might override
---offhand", Blizzard_Transmog.lua). That is what stopped a Titan's Grip pair rendering (#661).
---@param sourceID number?
---@return boolean
function ns.PairedArtifactWeapon(sourceID)
  return sourceID ~= nil
    and C_TransmogCollection.GetCategoryForItem(sourceID) == Enum.TransmogCollectionType.Paired
end

---`text` wrapped in a class colour escape, or unchanged when the class is unknown. Lets a narrow
---dropdown label carry the class without spending any width on it.
---@param text string
---@param classFile string?
---@return string
function ns.ClassColored(text, classFile)
  local color = classFile and RAID_CLASS_COLORS[classFile]
  if not color then return text end
  return ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, text)
end

-- Armour subclass id → the label stored on a library entry. Cosmetic is deliberately absent: it
-- goes on any armour type, so a cosmetic piece constrains nothing and shouldn't out-vote a real
-- armour type sitting beside it.
local ARMOR_LABEL = {
  [Enum.ItemArmorSubclass.Cloth] = "Cloth", [Enum.ItemArmorSubclass.Leather] = "Leather",
  [Enum.ItemArmorSubclass.Mail] = "Mail",   [Enum.ItemArmorSubclass.Plate] = "Plate",
}

-- The ONLY slots whose subclass reports the wearer's armour type. A positive list, because the
-- exceptions aren't guessable: a **cloak is always Cloth** and a **shirt is always Cloth** whatever
-- your class, and a **tabard is Generic** — so a plate set with a cloak reads Plate + Cloth and
-- looks "mixed", which made effectively every complete set derive as "Any". Weapons are out for the
-- obvious reason (their subclasses are Sword, Axe, …).
local ARMOR_SLOTS = {
  INVSLOT_HEAD, INVSLOT_SHOULDER, INVSLOT_CHEST, INVSLOT_WRIST,
  INVSLOT_HAND, INVSLOT_WAIST, INVSLOT_LEGS, INVSLOT_FEET,
}

---The armour type a look is made of — the filter key for "which of my characters could wear this",
---which is what actually groups a leather set across a rogue, a druid and a demon hunter.
---
---Derived from the pieces rather than from the previewed set's class: a class implies an armour
---type only for real class sets, while this also answers correctly for cosmetic, mixed and
---weapon-only looks. `GetItemInfoInstant` is synchronous and needs no cached item data (it's the
---same call `ns.SourceSlot` uses), so this costs nothing at save time.
---
---Only `ARMOR_SLOTS` are consulted — see the note there for why cloaks, shirts and tabards have to
---be left out. "Any" when those pieces disagree, are all cosmetic, or there are none: every case
---where no single armour type gates who can wear the look.
---@param list table[]
---@return string
function ns.OutfitArmorType(list)
  local found
  for _, slotID in ipairs(ARMOR_SLOTS) do
    local info = list[slotID]
    local appearanceID = info and info.appearanceID or 0
    -- A hide visual is a real appearance sitting in an armour slot, but it constrains nobody — the
    -- Hidden pieces are wearable by every class. Left in, one hidden slot could disagree with the
    -- rest and derive the whole look as "Any" (#654), exactly as a cloak once did.
    if appearanceID > 0 and not ns.IsHideVisual(slotID, appearanceID) then
      local src = GetSourceInfo(appearanceID)
      local subclass = src and src.itemID and select(7, GetItemInfoInstant(src.itemID))
      local label = subclass and ARMOR_LABEL[subclass]
      if label then
        if found and found ~= label then return "Any" end   -- mixed: no single type gates it
        found = label
      end
    end
  end
  return found or "Any"
end

---A one-line "where this came from" for display: the saving character, their class, and the armour
---type. Empty when an entry predates provenance (saved before #655) or carries none.
---@param entry LibraryOutfit
---@return string
function ns.OutfitOrigin(entry)
  if not entry then return "" end
  local bits = {}
  if entry.char then bits[#bits + 1] = entry.char end
  local class = ns.ClassLabel(entry.class)
  if class then bits[#bits + 1] = class end
  if entry.armor and entry.armor ~= "Any" then bits[#bits + 1] = entry.armor end
  return table.concat(bits, ", ")
end

-- ── Custom sets (the game's saved-outfit store) ────────────────────────────────--

---Every saved custom set, in the game's own order.
---@return { id: number, name: string, icon: number }[]
function ns.CustomSets()
  local out = {}
  for _, id in ipairs(GetCustomSets() or {}) do
    local name, icon = GetCustomSetInfo(id)
    out[#out + 1] = { id = id, name = name or ("set " .. id), icon = icon }
  end
  return out
end

---A saved custom set's outfit list, ready to apply. nil when the id is unknown.
---@param customSetID number
---@return table[]?
function ns.CustomSetOutfit(customSetID)
  return GetCustomSetList(customSetID)
end

-- Shared name validation for the write paths: non-empty, allowed by the game's own filter, and
-- not already taken by a DIFFERENT set (`exceptID` lets a rename keep its own name). Checked up
-- front because the C calls fail SILENTLY — `NewCustomSet` returns nil, `RenameCustomSet` simply
-- doesn't rename — which reads as "the button did nothing". Returns nil when the name is fine,
-- else the message to show.
---@param name string
---@param exceptID number?  a set id allowed to already hold this name
---@return string?
local function nameError(name, exceptID)
  if not name or name == "" then return "a name is required" end
  if not IsValidCustomSetName(name) then return ("\"%s\" isn't an allowed name"):format(name) end
  for _, s in ipairs(ns.CustomSets()) do
    if s.name == name and s.id ~= exceptID then
      return ("a set named \"%s\" already exists"):format(name)
    end
  end
end

---Write an outfit to the custom-set store — overwriting `customSetID` when given, else creating
---a new set named `name`.
---
---Validates up front rather than letting the C call no-op (see `nameError`). A duplicate name is
---reported rather than resolved — overwrite-versus-rename is the caller's decision to put to the
---user.
---@param name string
---@param list table[]
---@param customSetID number?  overwrite this set instead of creating one
---@return number? customSetID, string? err  exactly one is non-nil
function ns.SaveCustomSet(name, list, customSetID)
  if customSetID then
    C_TransmogCollection.ModifyCustomSet(customSetID, list)
    return customSetID
  end

  local err = nameError(name)
  if err then return nil, err end

  local max = GetNumMaxCustomSets()
  if max and #ns.CustomSets() >= max then
    return nil, ("you already have the maximum of %d saved sets"):format(max)
  end

  local id = C_TransmogCollection.NewCustomSet(name, ns.OutfitIcon(list), list)
  if not id then return nil, "the game refused to save the set" end
  return id
end

---Rename a saved custom set. Same up-front validation as the save path, except the set is allowed
---to keep its own name (so re-clicking Rename with the field untouched isn't an error).
---@param customSetID number
---@param name string
---@return boolean ok, string? err
function ns.RenameCustomSet(customSetID, name)
  local err = nameError(name, customSetID)
  if err then return false, err end
  C_TransmogCollection.RenameCustomSet(customSetID, name)
  return true
end

---Delete a saved custom set.
---@param customSetID number
function ns.DeleteCustomSet(customSetID)
  C_TransmogCollection.DeleteCustomSet(customSetID)
end
