---@type Warbandeer_Collected
local ns = select(2, ...)
local GetSourceInfo = C_TransmogCollection.GetSourceInfo
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
---@field OutfitIssues fun(list: table[]): { unusable: number[], pending: boolean, filled: number }
---@field OutfitIcon fun(list: table[]): number?
---@field OutfitSummary fun(list: table[]): string
---@field CustomSets fun(): { id: number, name: string, icon: number }[]
---@field CustomSetOutfit fun(customSetID: number): table[]?
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

---What would stop this outfit being saved as a custom set.
---
---The game **silently drops** every slot whose appearance this character can't collect (Blizzard's
---own save path clears them before writing), so callers surface `unusable` before writing rather
---than after. That matters here because the grid previews **every class's** sets: composing a
---plate tier set on a cloth wearer and saving it would quietly produce a near-empty set.
---
---`unusable`, NOT "uncollected" — `PlayerCanCollectSource`'s second return means *"this character
---is able to collect this appearance"* (armour type / class / faction validity), which is **not**
---the same as owning it. Verified in game: sources the player demonstrably did not own still
---answered `canCollect = true`. An appearance you simply haven't collected yet saves fine, which
---is why nothing here reports collection state — `ns.OutfitSummary` marks that separately, off
---`AppearanceSourceInfo.isCollected`.
---
---`pending` means item data is still streaming and the answer isn't knowable yet — the caller
---should retry shortly rather than treat those slots as unusable.
---@param list table[]
---@return { unusable: number[], pending: boolean, filled: number }
function ns.OutfitIssues(list)
  local out = { unusable = {}, pending = false, filled = 0 }
  for _, slotID in ipairs(ns.OutfitSlotOrder) do
    local info = list[slotID]
    local appearanceID = info and info.appearanceID or 0
    if appearanceID > 0 then
      out.filled = out.filled + 1
      local hasAllData, canCollect = PlayerCanCollectSource(appearanceID)
      if not hasAllData then
        out.pending = true
      elseif not canCollect then
        out.unusable[#out.unusable + 1] = slotID
      end
    end
  end
  return out
end

---Icon for a saved custom set: the first filled slot's appearance icon, matching how Blizzard
---picks one. nil when the outfit is empty or nothing resolves yet.
---@param list table[]
---@return number?
function ns.OutfitIcon(list)
  for _, slotID in ipairs(ns.OutfitSlotOrder) do
    local info = list[slotID]
    local appearanceID = info and info.appearanceID or 0
    if appearanceID > 0 then
      local src = GetAppearanceSourceInfo(appearanceID)
      if src and src.icon then return src.icon end
    end
  end
end

---A human-readable listing of an outfit — one line per filled slot. Feeds the copy window behind
---`/collected outfit export`, so what the string encodes can be eyeballed against what the model
---shows.
---
---Two independent markers, deliberately not conflated (see `ns.OutfitIssues`): `not owned` is
---collection state, which costs nothing to share and saves fine; `UNUSABLE` means this character
---can't collect the appearance at all, so a save would silently drop that slot.
---@param list table[]
---@return string
function ns.OutfitSummary(list)
  local lines = {}
  for _, slotID in ipairs(ns.OutfitSlotOrder) do
    local info = list[slotID]
    local appearanceID = info and info.appearanceID or 0
    if appearanceID > 0 then
      local src = GetSourceInfo(appearanceID)
      local _, canCollect = PlayerCanCollectSource(appearanceID)
      local extra = ""
      if info.illusionID and info.illusionID > 0 then
        extra = extra .. (" + illusion %d"):format(info.illusionID)
      end
      if info.secondaryAppearanceID and info.secondaryAppearanceID > 0 then
        extra = extra .. (" + secondary %d"):format(info.secondaryAppearanceID)
      end
      -- `src.isCollected` is the same per-source ownership flag the paper-doll slots colour their
      -- borders from, so this column matches the green/red the user is looking at.
      lines[#lines + 1] = ("%-14s %-8d %s%s%s%s"):format(
        ns.SlotLabel(slotID), appearanceID,
        (src and src.name) or "(name pending)", extra,
        (src and not src.isCollected) and "   (not owned)" or "",
        canCollect and "" or "   [UNUSABLE BY THIS CHARACTER — dropped on save]")
    end
  end
  if #lines == 0 then return "(empty outfit)" end
  return table.concat(lines, "\n")
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
