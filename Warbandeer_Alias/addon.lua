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
  -- Read the name live (cheap UnitName("player")) rather than a value captured once at
  -- load, so a mid-session name-change/transfer that resolves without a full reload
  -- doesn't leave the prefix decision comparing against a stale name.
  local player = ns.wow.Player.GetName()
  if ns.db.settings.startsWith then
    return not ns.lua.strings.startsWith(player, alias)
  end
  return player ~= alias
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

    -- SendChatMessage enforces WoW's 255-byte server-side cap and silently drops the
    -- tail past it. Prepending the prefix must not push a near-max message over that cap,
    -- or the end of the user's own text is lost — leave it untouched instead (# is the
    -- byte length WoW counts).
    local prefix = GetPrefix()
    if #text + #prefix > 255 then return end

    eb:SetText(prefix .. text)
  end)

  editBox._aliasHooked = true
end

function ns:onLoad()
  local settings = SettingsFrame:new{ headingText = ns._TITLE }
  settings:AddTextControl("Alias", ns.db.settings, "alias").SettingChanged = nil
  settings:AddToggleControl("Suppress if character name starts with alias", ns.db.settings, "startsWith").SettingChanged = nil
  -- Nest under the shared "Warbandeer" group (Warbandeer's own settings carry it;
  -- if Warbandeer isn't loaded, an empty parent is created on demand).
  ns.api.AliasSettingsCategory = settings:RegisterSubcategory(ns:GetSettingsParent("Warbandeer"))

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
