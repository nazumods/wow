---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local TitleFrame, Frame, Label, Texture, CheckButton =
  ui.TitleFrame, ui.Frame, ui.Label, ui.Texture, ui.CheckButton
local C_Timer = C_Timer

-- A movable, Escape-closable notification card built on TitleFrame: an accent title
-- strip + close X, an optional icon, a wrapped body, an optional "don't show again"
-- checkbox, and a dismiss button. Call :Notify() to show it (resets the checkbox and
-- arms the optional auto-hide); the close X, the dismiss button, and Escape all take it
-- down through the same path. Because it registers as a UISpecialFrame, pass a unique
-- `name` (required whenever `special` is left true, as it is by default).
---@class Notification: TitleFrame
---@field body string?           wrapped body text
---@field icon string|number?    icon texture path/fileID shown left of the body
---@field dismiss string|boolean dismiss button label; false to omit (default "Dismiss")
---@field dontShowAgain boolean  show the "don't show again" checkbox (default false)
---@field dontShowText string    checkbox label (default "Don't show this again")
---@field duration number?       auto-hide after N seconds (default nil = manual dismiss)
---@field width number           card width (default 360) — intrinsic, survives any `position`
---@field height number          card height (default 170)
---@field onDismiss fun(self: Notification)?  fired on dismiss (button, close X, or Escape)
---@field onDontShowAgain fun(self: Notification, checked: boolean)?  fired when the checkbox toggles
---@field _bodyLabel Label
---@field _iconTex Texture?
---@field _checkbox CheckButton?
---@field _dismissBtn Frame?
---@field _timer table?          pending auto-hide timer
local Notification = Class(TitleFrame, function(self)
  -- intrinsic size (not a `position` default: a caller's position table would replace it)
  self:Size(self.width, self.height)
  -- Accent the title and drop TitleFrame's default titlebar icon in favour of the
  -- body icon; slide the title back to the left edge the icon used to clear.
  self.titlebar.title:Color("header")
  self.titlebar.icon:Hide()
  self.titlebar.title:ClearAllPoints()
  self.titlebar.title:Left(self.titlebar, 10, 0)

  -- Close X and Escape share the dismiss path (fire onDismiss, cancel the timer).
  self.closeButton:SetScript("OnClick", function() self:_dismiss() end)

  if self.icon then
    self._iconTex = Texture:new{
      parent   = self,
      layer    = ui.layer.Artwork,
      path     = self.icon,
      position = { TopLeft = {self, ui.edge.TopLeft, 16, -42}, Size = {40, 40} },
    }
  end

  self._bodyLabel = Label:new{
    parent   = self,
    text     = self.body,
    color    = "text",
    justifyH = ui.justify.Left,
    justifyV = ui.justify.Top,
    position = {
      TopLeft = self.icon
        and {self._iconTex, ui.edge.TopRight, 12, 0}
        or  {self, ui.edge.TopLeft, 16, -42},
      BottomRight = {self, ui.edge.BottomRight, -16, 40},
    },
  }

  if self.dontShowAgain then
    self._checkbox = CheckButton:new{
      parent   = self,
      text     = self.dontShowText,
      position = { BottomLeft = {self, ui.edge.BottomLeft, 12, 12}, Size = {20, 20} },
      OnToggle = function(_, checked)
        if self.onDontShowAgain then self:onDontShowAgain(checked) end
      end,
    }
  end

  if self.dismiss ~= false then
    -- A plain labelled button in the TitleFrame close-button idiom (Frame + backdrop
    -- texture + centred Label), rather than the heavier action-oriented Button widget.
    local btn = Frame:new{
      type       = "Button",
      parent     = self,
      background = "backdrop",
      position   = { BottomRight = {self, ui.edge.BottomRight, -12, 12}, Size = {88, 22} },
    }
    btn.label = Label:new{
      parent = btn, text = self.dismiss, color = "text",
      position = { Center = {} },
    }
    btn:SetScript("OnClick", function() self:_dismiss() end)
    btn:SetScript("OnEnter", function() btn.background:Color("tabActive") end)
    btn:SetScript("OnLeave", function() btn.background:Color("backdrop") end)
    self._dismissBtn = btn
  end
end, {
  drag          = true,
  special       = true,
  strata        = "DIALOG",
  dismiss       = "Dismiss",
  dontShowAgain = false,
  dontShowText  = "Don't show this again",
  width         = 360,
  height        = 170,
  position      = { Center = {} },
})
ui.Notification = Notification

-- Show the card: reset the "don't show again" checkbox, (re)arm the optional auto-hide,
-- and Show. Use this rather than Show() so re-showing a reused card starts clean.
---@return Notification
function Notification:Notify()
  if self._checkbox then self._checkbox:Checked(false) end
  if self._timer then self._timer:Cancel(); self._timer = nil end
  self:Show()
  if self.duration then
    self._timer = C_Timer.NewTimer(self.duration, function() self:Hide() end)
  end
  return self
end

-- Take the card down and notify: cancels any pending auto-hide, hides, fires onDismiss.
-- Shared by the dismiss button, the close X, and Escape.
function Notification:_dismiss()
  if self._timer then self._timer:Cancel(); self._timer = nil end
  self:Hide()
  if self.onDismiss then self:onDismiss() end
end

-- Get/set the body text.
---@param text string?
---@return string|Notification
function Notification:Body(text)
  if text == nil then return self._bodyLabel:Text() end
  self._bodyLabel:Text(text)
  return self
end
