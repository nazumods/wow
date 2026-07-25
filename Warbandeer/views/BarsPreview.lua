---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label
local CleanFrame = ui.CleanFrame
local theme = ns.theme

-- The real-orientation bar layout render lives in LibNUI (ui.BarsPreview); this file
-- keeps only Warbandeer's profile-schema slot resolvers and the companion box that
-- docks the preview beside the main window.

local P     = 12   -- outer padding (shared with the preview widget's own P)
local LBL_H = 12   -- heading row height
-- The condensed-topographic layout (LibNUI #469) renders wider than the old stacked
-- one, so the docked box can overflow the screen edge (#468). Render the preview at a
-- reduced scale so its footprint fits the box without clipping (0.7 clears the
-- widest real profiles — bars spread across the screen — with margin to spare).
local SCALE = 0.7

local GetSpellTex  = (C_Spell and C_Spell.GetSpellTexture) or _G.GetSpellTexture
local GetSpellName = (C_Spell and C_Spell.GetSpellName)    or _G.GetSpellInfo
local GetItemTex   = (C_Item  and C_Item.GetItemIconByID)  or _G.GetItemIcon

-- ─── Slot resolvers (passed to ui.BarsPreview) ────────────────────────────────
-- Texture for a captured profile slot; nil hides the cell.

local function slotTex(slot, macroMap)
  if not slot then return nil end
  local t = slot.type
  if t == "spell" then
    return GetSpellTex and GetSpellTex(slot.index) or nil
  elseif t == "item" or t == "toy" then
    return slot.index and GetItemTex and GetItemTex(slot.index) or nil
  elseif t == "macro" then
    -- Captured macro icons are numeric fileIDs (as strings); legacy ones may be
    -- bare texture names or full paths.
    local ic = macroMap[slot.index] and macroMap[slot.index].icon
    if not ic then return nil end
    local fileID = tonumber(ic)
    if fileID then return fileID end
    if ic:find("\\") or ic:find("/") then return ic end
    return "Interface\\Icons\\" .. ic
  elseif t == "summonmount" then
    -- Mounts/pets are account-wide, so journal lookups work cross-character.
    -- The "Random Favorite Mount" pseudo-ID has no journal entry.
    local _, _, icon = C_MountJournal.GetMountInfoByID(slot.index)
    return icon or "Interface\\Icons\\achievement_guildperk_mountup"
  elseif t == "summonpet" then
    local icon = slot.strindex and select(9, C_PetJournal.GetPetInfoByPetID(slot.strindex))
    return icon or "Interface\\Icons\\inv_pet_achievement_capturer"
  elseif t == "equipmentset" then
    return "Interface\\Icons\\inv_misc_enggizmos_19"
  elseif t == "flyout" then
    -- Flyout IDs have no texture of their own; show the first known spell's,
    -- or any spell's when viewing a character that the player can't match
    -- (isKnown is evaluated against the logged-in character).
    local _, _, numSlots = GetFlyoutInfo(slot.index)
    local fallback
    for i = 1, numSlots or 0 do
      local spellID, _, isKnown = GetFlyoutSlotInfo(slot.index, i)
      if spellID and spellID > 0 then
        local tex = GetSpellTex(spellID)
        if tex and isKnown then return tex end
        fallback = fallback or tex
      end
    end
    return fallback
  end
end

-- Display name for the hover tooltip; nil when nothing sensible is known.
local function slotName(slot, macroMap)
  if not slot then return nil end
  local t = slot.type
  if t == "spell" or t == "companion" then
    return GetSpellName and GetSpellName(slot.index) or nil
  elseif t == "item" or t == "toy" then
    return slot.index and C_Item.GetItemNameByID(slot.index) or nil
  elseif t == "macro" then
    local m = macroMap[slot.index]
    return m and m.name
  elseif t == "flyout" then
    return (GetFlyoutInfo(slot.index))
  elseif t == "summonmount" then
    local name = C_MountJournal.GetMountInfoByID(slot.index)
    return name or "Random Favorite Mount"
  elseif t == "summonpet" then
    local customName, petName
    if slot.strindex then
      customName = select(2, C_PetJournal.GetPetInfoByPetID(slot.strindex))
      petName    = select(8, C_PetJournal.GetPetInfoByPetID(slot.strindex))
    end
    -- A caged/released pet's GUID stops resolving, degrading the tooltip to the literal
    -- "Battle Pet". v3 profiles snapshot the names, so prefer the stored copy over that.
    return customName or petName or slot.customName or slot.speciesName or "Battle Pet"
  elseif t == "equipmentset" then
    return slot.strindex
  end
end

-- Pet-bar slot icon/name: spell abilities resolve by ID; command tokens use the
-- texture captured with the profile (name-only can't resolve cross-character).
local function petTex(slot)
  if not slot then return nil end
  if slot.type == "spell" then return GetSpellTex and GetSpellTex(slot.index) or nil end
  return slot.tex   -- token (captured texture)
end
local function petName(slot)
  if not slot then return nil end
  if slot.type == "spell" then return GetSpellName and GetSpellName(slot.index) or nil end
  return slot.strindex   -- token command name
end

-- Edit Mode orientation fallback for a bar that isn't currently on screen (e.g. the
-- main bar paged to a stance) or pre-barLayout profiles — keyed by system index.
local function editLayoutFor(profile)
  return (WarbandeerBarsApi and profile.layoutName
    and WarbandeerBarsApi:GetLayout(profile.layoutName)) or nil
end

-- ─── BarsPreviewFrame (companion box docked right of the main window) ────────
-- Plain box like the IconStrip rail: parented to the Bars view so it only shows
-- while that view does, and inherits the main window's strata/level.

---@class BarsPreviewFrame: CleanFrame
---@field title Label          "<character> — <spec>" heading
---@field _preview BarsPreview
---@field _dragStrip Frame     invisible grip over the heading row; drags the main window
---@field _dragBound boolean?  true once the strip has been wired to ns.MainWindow
local BarsPreviewFrame = Class(CleanFrame, function(self)
  self.title = Label:new{
    parent   = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {P, -P}, Height = LBL_H },
    wordWrap = false,
  }
  -- Invisible grip over the heading row (only — leaves the preview cells below it
  -- free for their hover tooltips). Anchored to both top corners so it spans the box
  -- and tracks width changes; wired to drag the main window in Set() (see below).
  self._dragStrip = Frame:new{
    parent   = self,
    position = {
      TopLeft  = {self, ui.edge.TopLeft, 0, 0},
      TopRight = {self, ui.edge.TopRight, 0, 0},
      Height   = P + LBL_H,
    },
  }
  self._preview = ui.BarsPreview:new{
    parent   = self,
    scale    = SCALE,
    -- SetPoint offsets are measured in the frame's own (scaled) space, so divide by
    -- SCALE to keep the preview's top LBL_H+P px below the box top after scaling.
    position = { TopLeft = {0, -(P + LBL_H) / SCALE}, Hide = true },
    resolveIcon    = slotTex,
    resolveName    = slotName,
    resolvePetIcon = petTex,
    resolvePetName = petName,
    editLayoutFor  = editLayoutFor,
    rowColor       = theme.colors.module,
    highlightColor = theme.colors.selected,
    labelColor     = theme.colors.muted,
    stanceColor    = { theme.colors.gold[1], theme.colors.gold[2], theme.colors.gold[3], 0.35 },
    labelFontInfo  = theme.fonts.body,
  }
  self:Hide()
end, {
  -- anchored to the (already clamped) window — same rule as IconStrip
  clamped    = false,
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
})
---@class Warbandeer
---@field BarsPreviewFrame BarsPreviewFrame
ns.BarsPreviewFrame = BarsPreviewFrame

---Forward a bar highlight to the inner preview (driven by the apply panel's toggle hover).
---@param profileBar number
---@param on boolean
function BarsPreviewFrame:HighlightProfileBar(profileBar, on)
  self._preview:HighlightBar(profileBar, on)
end

---Point the preview box at a profile and show it; hide if profile is nil.
---@param profile table?
function BarsPreviewFrame:Set(profile)
  if not profile then self:Hide(); return end
  -- Bind the heading grip to the main window once it exists (it always does by the
  -- time a profile is shown — the window must be open for the Bars view to appear).
  if ns.MainWindow and not self._dragBound then
    ns.MainWindow:BindDragHandle(self._dragStrip)
    self._dragBound = true
  end
  self.title:Text(profile.char .. "  \226\128\148  " .. (profile.spec or "?"))
  self._preview:Set(profile)
  -- The preview renders at SCALE, so its on-screen footprint is its logical size
  -- times SCALE; wrap the box to that.
  local w = self._preview:Width() * SCALE
  self.title:Width(w - 2 * P)
  self:Width(w)
  self:Height(P + LBL_H + self._preview:Height() * SCALE)
  self:Show()
end
