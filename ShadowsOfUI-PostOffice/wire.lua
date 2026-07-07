---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- Wire: when you enter a coin amount on the Send-Mail tab, fill a blank subject
-- with that amount so the recipient sees what the letter contains. We only ever
-- overwrite a subject we set ourselves, never one the player typed.
local floor = math.floor

-- Plain-text coin string for a mail subject. Mail subjects don't render texture
-- escapes, so GetCoinTextureString is unsuitable here. e.g. 10230405 -> "1023g 4s 5c".
local function coinSubject(copper)
  local parts = {}
  local g = floor(copper / 10000)
  local s = floor(copper % 10000 / 100)
  local c = copper % 100
  if g > 0 then parts[#parts + 1] = g .. "g" end
  if s > 0 then parts[#parts + 1] = s .. "s" end
  if c > 0 then parts[#parts + 1] = c .. "c" end
  return table.concat(parts, " ")
end

local ourSubject ---@type string?  the subject text we last wrote, so we don't clobber the player's
local wired = false

local function onMoneyChanged()
  if not ns.db.wire then return end
  local box = SendMailSubjectEditBox
  if not box then return end
  local copper = MoneyInputFrame_GetCopper(SendMailMoney)
  local current = box:GetText()
  if copper > 0 then
    if current == "" or current == ourSubject then
      ourSubject = coinSubject(copper)
      box:SetText(ourSubject)
    end
  elseif current == ourSubject then
    ourSubject = nil -- money cleared: remove the subject we added
    box:SetText("")
  end
end

-- SendMailMoney only exists once Blizzard_MailFrame has loaded (first mailbox
-- open). Blizzard leaves its onValueChangedFunc unset, so we install ours lazily
-- on the first visit and own it thereafter.
ns.OnMailShow(function()
  if wired or not SendMailMoney then return end
  wired = true
  MoneyInputFrame_SetOnValueChangedFunc(SendMailMoney, onMoneyChanged)
end)
