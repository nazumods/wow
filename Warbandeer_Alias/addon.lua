---@class Warbandeer_Alias: AddOn
local ns = LibNAddOn(...)

function ns:MigrateDB()
  local db = ns.db
  if not db.settings then
    db.settings = {}
  end
  if not db.settings.alias then
    db.settings.alias = ""
  end
  if not db.settings.startsWith then
    db.settings.startsWith = false
  end
  db.version = 1
end

local SettingsFrame = ns.ui.SettingsFrame

local function ShouldPrefix()
  local alias = ns.db.settings.alias
  if not alias or alias == "" then return false end
  if ns.db.settings.startsWith then
    return not ns.lua.strings.startsWith(ns.player, alias)
  end
  return ns.player ~= alias
end

local function GetPrefix()
  return "(" .. ns.db.settings.alias .. ") "
end

local function hookEditBox(editBox)
  if not editBox or editBox._aliasHooked then return end

  -- OnKeyDown fires before OnEnterPressed, so SetText here is picked up by
  -- the secure send path without causing taint (HookScript doesn't spread taint).
  editBox:HookScript("OnKeyDown", function(eb, key)
    if key ~= "ENTER" and key ~= "NUMPADENTER" then return end
    if not ShouldPrefix() then return end

    local text = eb:GetText()
    if not text or text == "" then return end

    local chatType = eb:GetAttribute("chatType") or
                     (eb.GetChatType and eb:GetChatType()) or
                     eb.chatType
    if chatType ~= "GUILD" then return end

    if text:match("^%s*[/!#@?]") then return end

    eb:SetText(GetPrefix() .. text)
  end)

  editBox._aliasHooked = true
end

function ns:onLoad()
  ns.player = ns.wow.Player.GetName()

  local settings = SettingsFrame:new{ headingText = ns._TITLE }
  settings:AddTextControl("Alias", ns.db.settings, "alias").SettingChanged = nil
  settings:AddToggleControl("Suppress if character name starts with alias", ns.db.settings, "startsWith").SettingChanged = nil
  if ns.api.SettingsCategory then
    ns.api.AliasSettingsCategory = settings:RegisterSubcategory(ns.api.SettingsCategory)
  else
    ns.api.AliasSettingsCategory = settings:RegisterCategory()
  end

  local numFrames = NUM_CHAT_WINDOWS or 10
  for i = 1, numFrames do
    hookEditBox(_G["ChatFrame" .. i .. "EditBox"])
  end

  if type(FCF_OpenTemporaryWindow) == "function" then
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
      for i = 1, (NUM_CHAT_WINDOWS or 10) do
        hookEditBox(_G["ChatFrame" .. i .. "EditBox"])
      end
    end)
  end
end
