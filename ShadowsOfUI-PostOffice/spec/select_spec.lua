-- Drives the REAL select.lua through its registered callbacks against a fake mail API: the tick
-- bookkeeping (#1011) and the open-mode retry cap (#1037). Frames are inert stubs that keep just
-- the state the file reads back (scripts, id, checked). Path is relative to the AddOns root.
local GLOBALS = {
  "CreateFrame", "bit", "wipe", "InboxFrame", "GetInboxNumItems", "GetInboxHeaderInfo", "GetInboxItem",
  "TakeInboxItem", "TakeInboxMoney", "InboxItemCanDelete", "ReturnInboxItem", "ATTACHMENTS_MAX_RECEIVE",
  "NUM_BAG_SLOTS", "C_Container", "C_Item", "IsShiftKeyDown", "IsControlKeyDown",
}

local MAX_TAKES = 7 -- select.lua's MAX_TAKES: tries on one refused attachment slot

describe("ShadowsOfUI-PostOffice Select", function()
  local saved, ns, state, rowFn, showFn, buttons, checkboxes

  local function fakeFrame(kind)
    local f = { kind = kind, scripts = {}, shown = true, id = 0, checked = false }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetID(id) self.id = id end
    function f:GetID() return self.id end
    function f:GetChecked() return self.checked end
    function f:SetChecked(v) self.checked = v and true or false end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(v) self.shown = v end
    function f:Disable() self.disabled = true end
    function f:Enable() self.disabled = false end
    function f:SetText(t) self.text = t end
    function f:CreateFontString() return fakeFrame("fs") end
    for _, m in ipairs({ "SetPoint", "SetSize", "SetHitRectInsets", "ClearAllPoints", "SetWidth" }) do f[m] = function() end end
    return f
  end

  before_each(function()
    saved = {}
    for _, k in ipairs(GLOBALS) do saved[k] = _G[k] end
    state = { count = 5, items = {}, taken = {}, returned = {} }
    buttons, checkboxes = {}, {}

    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
    _G.bit = { band = function(a, b) return (a % 2 == 1 and b % 2 == 1) and 1 or 0 end } -- family 0 only in these specs
    _G.CreateFrame = function(kind, _, _, template)
      local f = fakeFrame(kind)
      if template == "UIPanelButtonTemplate" then buttons[#buttons + 1] = f end
      if template == "InterfaceOptionsCheckButtonTemplate" then checkboxes[#checkboxes + 1] = f end
      return f
    end
    _G.InboxFrame = fakeFrame("InboxFrame"); _G.InboxFrame.pageNum = 1
    _G.GetInboxNumItems = function() return state.count end
    _G.GetInboxHeaderInfo = function() return nil, nil, "Sender", "Subject", 0, 0 end
    _G.GetInboxItem = function(index, slot) return state.items[index .. ":" .. slot] and "item" or nil end
    _G.TakeInboxItem = function(index, slot) state.taken[#state.taken + 1] = index .. ":" .. slot end
    _G.TakeInboxMoney = function() end
    _G.InboxItemCanDelete = function() return false end
    _G.ReturnInboxItem = function(index) state.returned[#state.returned + 1] = index end
    _G.ATTACHMENTS_MAX_RECEIVE = 16
    _G.NUM_BAG_SLOTS = 4
    _G.C_Container = { GetContainerNumFreeSlots = function() return 10, 0 end }
    _G.C_Item = { GetItemFamily = function() return 0 end }
    _G.IsShiftKeyDown = function() return false end
    _G.IsControlKeyDown = function() return false end

    ns = {
      db = { select = true },
      OnInboxRow = function(fn) rowFn = fn end,
      OnMailShow = function(fn) showFn = fn end,
      OnMailHide = function() end,
      OnSettingChanged = function() end,
      RefreshInbox = function() end,
    }
    assert(loadfile("ShadowsOfUI-PostOffice/select.lua"))("ShadowsOfUI-PostOffice", ns)
    showFn() -- builds the Open / Return buttons and one checkbox per row
  end)

  after_each(function()
    for _, k in ipairs(GLOBALS) do _G[k] = saved[k] end
    for i = 1, 7 do _G["MailItem" .. i] = nil end
  end)

  local function redraw()
    for i = 1, 5 do rowFn({ i = i, index = i, present = true }) end
  end
  local function tick(i)
    local cb = checkboxes[i]
    cb.checked = true
    cb.scripts.OnClick(cb)
  end
  local function press(btn) btn.scripts.OnClick(btn) end

  describe("tick bookkeeping (#1011)", function()
    it("returns exactly the ticked letters when the inbox is unchanged", function()
      redraw()
      tick(2); tick(4)
      press(buttons[2]) -- Return
      assert.same({ 4 }, { state.returned[1] })
      ns._selectStep()
      assert.same({ 4, 2 }, state.returned)
    end)

    it("drops every tick when a letter leaves the inbox, so nothing un-ticked is returned", function()
      redraw()
      tick(2); tick(4)
      state.count = 4        -- a letter above them was returned / deleted: indices have shifted
      redraw()               -- the inbox redraws
      press(buttons[2])      -- Return
      assert.same({}, state.returned)
    end)

    it("also drops ticks when mail arrives", function()
      redraw()
      tick(2)
      state.count = 6
      redraw()
      press(buttons[2])
      assert.same({}, state.returned)
    end)

    it("clears the ticks even if Return is pressed before any redraw", function()
      redraw()
      tick(3)
      state.count = 4
      press(buttons[2])
      assert.same({}, state.returned)
    end)
  end)

  describe("open mode retry cap (#1037)", function()
    it("gives up on an attachment the server keeps refusing instead of retrying forever", function()
      state.items["3:1"] = true -- TakeInboxItem never removes it
      redraw()
      tick(3)
      press(buttons[1])         -- Open: first step runs immediately
      for _ = 1, 3 * MAX_TAKES do ns._selectStep() end
      assert.equal(MAX_TAKES, #state.taken)
    end)

    it("moves on to the next ticked letter after giving up", function()
      state.items["4:1"] = true
      redraw()
      tick(4); tick(2)
      state.items["2:1"] = true
      press(buttons[1])
      for _ = 1, 4 * MAX_TAKES do ns._selectStep() end
      local n4, n2 = 0, 0
      for _, t in ipairs(state.taken) do
        if t:sub(1, 1) == "4" then n4 = n4 + 1 else n2 = n2 + 1 end
      end
      assert.equal(MAX_TAKES, n4)
      assert.equal(MAX_TAKES, n2)
    end)
  end)
end)
