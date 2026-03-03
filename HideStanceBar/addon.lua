local ns = LibNAddOn(...)
local SettingsFrame = ns.ui.SettingsFrame
local Player = ns.wow.Player

function ns:MigrateDB()
  local db = ns.db
  if not db.hide then
    db.hide = {}
  end
end

local Hider = CreateFrame("Frame", "StanceHider", UIParent)
Hider:Hide()

local function update(classId, hide)
  if classId == Player:GetClassId() then
    if hide then
      StanceBar:Hide()
      StanceBar:SetParent(Hider)
    else
      StanceBar:Show()
      StanceBar:SetParent(UIParent)
    end
  end
end

function ns:onLoad()
  if ns.db.hide[Player:GetClassId()] == true then
    StanceBar:Hide()
    StanceBar:SetParent(Hider)
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
  settings:RegisterCategory("Shadows of UI")
end
