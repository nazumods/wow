-- luacheck: globals LibNAddOn SendChatMessage
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
  db.version = 1 -- update version after migration
end

local SettingsFrame, TextSetting = ns.ui.SettingsFrame, ns.ui.TextSetting

local NameMatches = function()
  return not ns.player == ns.db.settings.alias
end

local NameStartsWith = function()
  return not ns.lua.strings.startsWith(ns.player, ns.db.settings.alias)
end

function ns:onLoad()
  ns.player = ns.wow.Player.GetName()
  ns.prefix = ns.db.settings.startsWith and NameStartsWith or NameMatches

  local settings = SettingsFrame:new{
    headingText = ns._TITLE,
  }
  settings:AddTextControl("Alias", ns.db.settings, "alias").SettingChanged = nil
  settings:AddToggleControl("Suppress if character name starts with alias", ns.db.settings, "startsWith").SettingChanged = function(_, state)
    ns.prefix = state and NameStartsWith or NameMatches
  end
  if ns.api.SettingsCategory then
    ns.api.AliasSettingsCategory = settings:RegisterSubcategory(ns.api.SettingsCategory)
  else
    ns.api.AliasSettingsCategory = settings:RegisterCategory()
  end

  for i = 1, NUM_CHAT_WINDOWS do
    local editBox = _G["ChatFrame" .. i .. "EditBox"]
    if editBox then
      local send = editBox.SendText
      editBox.SendText = function(editBox, addToHistory)
        local text = editBox:GetText()
        if not text or text == "" or not ns.prefix() then
          send(editBox, addToHistory)
          return
        end
        local chatType = (editBox.GetAttribute and editBox:GetAttribute("chatType")) or editBox.chatType
        if type(text) == "string" then
          local symbols = "/!#@?"
          local firstChar = text:match("^%s*(.)")
          if firstChar and symbols:find(firstChar, 1, true) then
            send(editBox, addToHistory)
            return
          end
        end
        if chatType == "GUILD" then
          local prefixedText = "(" .. ns.db.settings.alias .. ") " .. text
          editBox:SetText(prefixedText)
          send(editBox, 0)
          editBox:SetText(text)
          if addToHistory and addToHistory ~= 0 then
            editBox:AddHistoryLine(text)
          end
          return
        end
        send(editBox, addToHistory)
      end
    end
  end
end
