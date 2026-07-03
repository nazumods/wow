---@class HideStanceBar: AddOn
local ns = LibNAddOn(...)
local SettingsFrame = ns.ui.SettingsFrame
local Player = ns.wow.Player

function ns:MigrateDB()
  local db = ns.db
  if not db.hide then
    db.hide = {}
  end
  db.version = 1
end

local Hider = CreateFrame("Frame", "StanceHider", UIParent)
Hider:Hide()

-- StanceBar is a protected, Edit-Mode-managed frame: Hide/Show/SetParent are
-- blocked under combat lockdown, and onLoad can run mid-combat (a /reload during
-- a fight). Defer any change requested during combat to PLAYER_REGEN_ENABLED.
local pendingHide  -- nil = nothing pending; boolean = desired hide state
local combatWatcher = CreateFrame("Frame")

local function applyHide(hide)
  if InCombatLockdown() then
    pendingHide = hide
    combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  if hide then
    StanceBar:Hide()
    StanceBar:SetParent(Hider)
  else
    StanceBar:Show()
    StanceBar:SetParent(UIParent)
  end
end

combatWatcher:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  if pendingHide ~= nil then
    local hide = pendingHide
    pendingHide = nil
    applyHide(hide)
  end
end)

local function update(classId, hide)
  if classId == Player:GetClassId() then
    applyHide(hide)
  end
end

-- Applying an Edit Mode layout (login, layout switch, leaving the editor)
-- re-anchors and reshows the managed StanceBar, undoing the reparent. Re-apply
-- the saved hide afterwards — but not while the editor is open, so the bar stays
-- visible and editable there (ExitEditMode clears editModeActive before its
-- hooks run, so the on-exit re-hide passes this guard).
local function reapply()
  if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
  if ns.db and ns.db.hide and ns.db.hide[Player:GetClassId()] == true then
    applyHide(true)
  end
end

function ns:onLoad()
  if ns.db.hide[Player:GetClassId()] == true then
    applyHide(true)
  end

  ns:registerEvent("EDIT_MODE_LAYOUTS_UPDATED", reapply)
  -- Exit reverts unsaved changes without necessarily firing the event; guarded
  -- like ShadowsOfUI-Castbar's WireEditMode for clients without the frame.
  if EditModeManagerFrame and EditModeManagerFrame.ExitEditMode then
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", reapply)
  end

  local settings = SettingsFrame:new{
    headingText = ns._TITLE,
  }
  settings:AddToggleControl("Warrior", ns.db.hide, 1).SettingChanged = function(_, state)
    update(1, state)
  end
  settings:AddToggleControl("Paladin", ns.db.hide, 2).SettingChanged = function(_, state)
    update(2, state)
  end
  settings:AddToggleControl("Rogue", ns.db.hide, 4).SettingChanged = function(_, state)
    update(4, state)
  end
  settings:AddToggleControl("Priest", ns.db.hide, 5).SettingChanged = function(_, state)
    update(5, state)
  end
  settings:AddToggleControl("Druid", ns.db.hide, 11).SettingChanged = function(_, state)
    update(11, state)
  end
  settings:RegisterSubcategory(ns:GetSettingsParent("Shadows of UI"), ns._TITLE)
end
