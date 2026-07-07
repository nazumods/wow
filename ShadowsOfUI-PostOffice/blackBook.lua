---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- BlackBook: a recipient picker + name autocomplete for the Send-Mail "To:" field.
-- An arrow button beside the box opens a menu of recently-mailed names, your warband
-- alts (WarbandeerApi, class-coloured), friends, and guild mates; typing in the box
-- inline-completes from the same lists. Blizzard's own autocomplete popup (the dead
-- "Press Tab" box) is suppressed while the feature is on — ours replaces it.
local RECENT_MAX = 15

local button ---@type Button?
local pendingRecipient ---@type string?  captured at Send click, committed on MAIL_SEND_SUCCESS

--------------------------------------------------------------------------------
-- Candidate lists (built lazily per mailbox visit)
--------------------------------------------------------------------------------
local candidates ---@type string[]?  autocomplete order: recent, alts, friends, guild

local function addCandidate(seen, name)
  if name and name ~= "" and not seen[name:upper()] then
    seen[name:upper()] = true
    candidates[#candidates + 1] = name
  end
end

-- Warband alts from WarbandeerApi (empty when Warbandeer_Characters isn't installed —
-- LibNAddOn creates the api global either way). Same-realm alts mail by plain name;
-- cross-realm ones need Name-Realm.
local function altList()
  local alts = {}
  if not ns.api.GetAllCharacters then return alts end
  local me, myRealm = UnitName("player"), GetRealmName()
  for _, c in ipairs(ns.api:GetAllCharacters()) do
    if not (c.name == me and (c.realm or myRealm) == myRealm) then
      local target = (c.realm and c.realm ~= myRealm) and (c.name .. "-" .. c.realm) or c.name
      alts[#alts + 1] = { target = target, classKey = c.classKey }
    end
  end
  table.sort(alts, function(a, b) return a.target < b.target end)
  return alts
end

local function friendList()
  local friends = {}
  -- Own warband characters already live in the Alts list; keep them out of Friends.
  local mine = {}
  for _, a in ipairs(altList()) do
    mine[a.target:upper()] = true
    mine[a.target:match("^([^%-]+)"):upper()] = true -- plain name too
  end
  for i = 1, C_FriendList.GetNumFriends() do
    local info = C_FriendList.GetFriendInfoByIndex(i)
    -- Deleted/transferred characters linger in the friends list as a truncated
    -- name + hex GUID suffix (e.g. "Ashlyn" -> "AshlynD92F9"). Character names can
    -- never contain digits, so drop any entry whose name portion has one.
    if info and info.name and not info.name:match("^[^%-]*%d") and not mine[info.name:upper()] then
      friends[#friends + 1] = info.name
    end
  end
  table.sort(friends)
  return friends
end

-- Guild roster entries come realm-qualified; strip our own realm for plain-name mail.
local function guildList()
  local mates = {}
  if not IsInGuild() then return mates end
  local me, mySuffix = UnitName("player"), "-" .. GetRealmName():gsub("%s", "")
  for i = 1, GetNumGuildMembers() do
    local name, _, _, _, _, _, _, _, _, _, classToken = GetGuildRosterInfo(i)
    if name then
      name = name:gsub(mySuffix .. "$", "")
      if name ~= me then
        mates[#mates + 1] = { target = name, classKey = ns.wow.ClassKeyByToken[classToken] }
      end
    end
  end
  table.sort(mates, function(a, b) return a.target < b.target end)
  return mates
end

local function buildCandidates()
  candidates = {}
  local seen = {}
  for _, name in ipairs(ns.db.blackBookRecent) do addCandidate(seen, name) end
  for _, a in ipairs(altList()) do addCandidate(seen, a.target) end
  for _, f in ipairs(friendList()) do addCandidate(seen, f) end
  for _, g in ipairs(guildList()) do addCandidate(seen, g.target) end
end

ns.OnMailHide(function() candidates = nil end) -- rosters can change between visits

--------------------------------------------------------------------------------
-- Recently mailed
--------------------------------------------------------------------------------
local function recordRecent(name)
  local recent = ns.db.blackBookRecent
  for i = #recent, 1, -1 do
    if recent[i]:upper() == name:upper() then table.remove(recent, i) end
  end
  table.insert(recent, 1, name)
  for i = #recent, RECENT_MAX + 1, -1 do table.remove(recent, i) end
  candidates = nil
end

function ns.MAIL_SEND_SUCCESS()
  if pendingRecipient and ns.db.blackBook then
    recordRecent(pendingRecipient)
    SendMailNameEditBox:AddHistoryLine(pendingRecipient)
  end
  pendingRecipient = nil
end
ns:registerEvent("MAIL_SEND_SUCCESS")

--------------------------------------------------------------------------------
-- Recipient menu
--------------------------------------------------------------------------------
local function fill(name)
  SendMailNameEditBox:SetText(name)
  SendMailSubjectEditBox:SetFocus()
end

local function entryButton(root, target, classKey)
  root:CreateButton(classKey and ns.Colors.className(target, classKey) or target,
    function() fill(target) end)
end

local function buildMenu(_, root)
  local recent = ns.db.blackBookRecent
  if #recent > 0 then
    root:CreateTitle("Recently Mailed")
    for _, name in ipairs(recent) do entryButton(root, name) end
    root:CreateDivider()
  end
  local alts = altList()
  if #alts > 0 then
    local sub = root:CreateButton("Alts")
    sub:SetScrollMode(400)
    for _, a in ipairs(alts) do entryButton(sub, a.target, a.classKey) end
  end
  local friends = friendList()
  if #friends > 0 then
    local sub = root:CreateButton("Friends")
    sub:SetScrollMode(400)
    for _, f in ipairs(friends) do entryButton(sub, f) end
  end
  local mates = guildList()
  if #mates > 0 then
    local sub = root:CreateButton("Guild")
    sub:SetScrollMode(400)
    for _, g in ipairs(mates) do entryButton(sub, g.target, g.classKey) end
  end
  if #recent > 0 then
    root:CreateDivider()
    root:CreateButton("Clear recently mailed", function()
      wipe(ns.db.blackBookRecent)
      candidates = nil
    end)
  end
end

--------------------------------------------------------------------------------
-- Inline autocomplete (replaces the dead native "Press Tab" popup)
--------------------------------------------------------------------------------
local function onChar(editbox)
  if not ns.db.blackBook then return end
  local text = editbox:GetText()
  if text == "" or editbox:GetCursorPosition() < #text then return end
  if not candidates then buildCandidates() end
  local upper = text:upper()
  for _, name in ipairs(candidates) do
    if name:upper():sub(1, #upper) == upper and #name > #text then
      editbox:SetText(name)
      editbox:HighlightText(#text, -1) -- typed prefix stays; completion selected
      editbox:SetCursorPosition(#text)
      return
    end
  end
end

-- Suppress or restore Blizzard's autocomplete popup: AutoComplete bails when the
-- box has no autoCompleteParams; restoring re-registers the stock MAIL source.
local function setNativePopup(enabled)
  if not SendMailNameEditBox then return end
  if enabled then
    AutoCompleteEditBox_SetAutoCompleteSource(SendMailNameEditBox,
      C_AutoComplete.GetAutoCompleteResults, AUTOCOMPLETE_LIST.MAIL.include, AUTOCOMPLETE_LIST.MAIL.exclude)
  else
    SendMailNameEditBox.autoCompleteParams = nil
  end
end

--------------------------------------------------------------------------------
-- Lazy install (SendMailFrame is load-on-demand) + live toggle
--------------------------------------------------------------------------------
local function ensureButton()
  if button then return end
  button = CreateFrame("Button", nil, SendMailFrame)
  button:SetSize(25, 25)
  button:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", -2, 2)
  button:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
  button:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
  button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Round]])
  button:SetScript("OnClick", function(self) MenuUtil.CreateContextMenu(self, buildMenu) end)
end

local installed = false
ns.OnMailShow(function()
  if not SendMailFrame then return end
  if not installed then
    installed = true
    ensureButton()
    SendMailNameEditBox:SetHistoryLines(RECENT_MAX)
    SendMailNameEditBox:HookScript("OnChar", onChar)
    hooksecurefunc("SendMailFrame_SendMail", function()
      local name = strtrim(SendMailNameEditBox:GetText())
      pendingRecipient = name ~= "" and name or nil
    end)
  end
  button:SetShown(ns.db.blackBook)
  setNativePopup(not ns.db.blackBook)
end)

ns.OnSettingChanged("blackBook", function(value)
  if button then button:SetShown(value) end
  setNativePopup(not value)
end)
