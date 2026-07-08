---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- Wire: when you enter a coin amount on the Send-Mail tab, fill a blank subject
-- with that amount so the recipient sees what the letter contains. We only ever
-- overwrite a subject we set ourselves, never one the player typed. (Mail subjects
-- don't render texture escapes, so we use the plain ns.wow.CoinString string.)
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
      ourSubject = ns.wow.CoinString(copper)
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
