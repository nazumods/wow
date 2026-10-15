local po = require("ShadowsOfUI-PostOffice.spec.postoffice")

-- core.lua hooks the mail frame's redraw functions lazily on the first mailbox open. Retail has
-- them as globals (InboxFrame_Update, OpenMail_Update); Forever's mail frame replaced them with
-- the frames' own methods (InboxFrame:Update, OpenMailFrame:Update), which Blizzard calls through
-- the frame. These specs drive both shapes through the real core.lua / express.lua.
describe("ShadowsOfUI-PostOffice core mail-frame hooks", function()
  local ns

  -- A fake inbox frame whose Update counts redraws; `pageNum` as Blizzard keeps it.
  local function newInboxFrame() return { pageNum = 1, updates = 0, Update = function(self) self.updates = self.updates + 1 end } end
  local function newOpenMailFrame() return { updates = 0, Update = function(self) self.updates = self.updates + 1 end } end

  local function fakeRows(count)
    _G.GetInboxNumItems = function() return count end
    for i = 1, 7 do _G["MailItem" .. i] = { name = "MailItem" .. i }; _G["MailItem" .. i .. "ExpireTime"] = { name = "Expire" .. i } end
  end

  before_each(function() ns = po.loadCore() end)
  after_each(function() po.resetMail() end)

  it("Retail: hooks the InboxFrame_Update global and decorates rows", function()
    local redraws = 0
    _G.InboxFrame_Update = function() redraws = redraws + 1 end
    _G.InboxFrame = { pageNum = 1 }
    fakeRows(3)
    local seen = {}
    ns.OnInboxRow(function(row) seen[#seen + 1] = row end)
    po.openMailbox(ns)
    _G.InboxFrame_Update()
    assert.equals(1, redraws)                      -- the original still ran
    assert.equals(7, #seen)                        -- one callback per visible row
    assert.is_true(seen[3].present)                -- 3 letters: rows 1-3 present
    assert.is_false(seen[4].present)
    assert.equals(_G.MailItem2, seen[2].item)
    assert.equals(_G.MailItem2ExpireTime, seen[2].expire)
  end)

  it("Forever: hooks InboxFrame:Update when the global is absent, and rows are decorated when the frame updates", function()
    _G.InboxFrame = newInboxFrame()
    fakeRows(10)
    _G.InboxFrame.pageNum = 2
    local seen = {}
    ns.OnInboxRow(function(row) seen[#seen + 1] = row end)
    po.openMailbox(ns)
    assert.is_nil(_G.InboxFrame_Update)
    _G.InboxFrame:Update()
    assert.equals(1, _G.InboxFrame.updates)        -- the original method ran
    assert.equals(7, #seen)
    assert.equals(8, seen[1].index)                -- page 2 starts at mail index 8
    assert.is_true(seen[3].present)                -- index 10 exists
    assert.is_false(seen[4].present)
  end)

  it("Forever: hooks OpenMailFrame:Update when OpenMail_Update is absent", function()
    _G.OpenMailFrame = newOpenMailFrame()
    local fired = 0
    ns.OnOpenMailUpdate(function() fired = fired + 1 end)
    po.openMailbox(ns)
    assert.is_nil(_G.OpenMail_Update)
    _G.OpenMailFrame:Update()
    assert.equals(1, _G.OpenMailFrame.updates)
    assert.equals(1, fired)
  end)

  it("Retail: reopening the mailbox does not hook the global a second time", function()
    _G.InboxFrame_Update = function() end
    _G.InboxFrame = { pageNum = 1 }
    fakeRows(1)
    local seen = 0
    ns.OnInboxRow(function() seen = seen + 1 end)
    po.openMailbox(ns); po.openMailbox(ns); po.openMailbox(ns)
    _G.InboxFrame_Update()
    assert.equals(7, seen)                         -- 7 rows once, not 21
  end)

  it("a non-function value in the global slot is not hooked as a global", function()
    _G.OpenMail_Update = true                      -- truthy but not callable
    _G.OpenMailFrame = newOpenMailFrame()
    local fired = 0
    ns.OnOpenMailUpdate(function() fired = fired + 1 end)
    assert.has_no.errors(function() po.openMailbox(ns) end)
    _G.OpenMailFrame:Update()
    assert.equals(1, fired)                        -- fell through to the frame method
  end)

  it("Retail: hooks the OpenMail_Update global", function()
    _G.OpenMail_Update = function() end
    _G.OpenMailFrame = newOpenMailFrame()          -- present, but the global wins
    local fired = 0
    ns.OnOpenMailUpdate(function() fired = fired + 1 end)
    po.openMailbox(ns)
    _G.OpenMail_Update()
    assert.equals(1, fired)
    _G.OpenMailFrame:Update()                      -- the frame method was NOT hooked
    assert.equals(1, fired)
  end)

  it("a mailbox open before the frames exist does not mark the hook installed", function()
    local inboxSeen, openFired = 0, 0
    ns.OnInboxRow(function() inboxSeen = inboxSeen + 1 end)
    ns.OnOpenMailUpdate(function() openFired = openFired + 1 end)
    po.openMailbox(ns)                             -- Blizzard_MailFrame not loaded yet: nothing to hook
    _G.InboxFrame = newInboxFrame(); _G.OpenMailFrame = newOpenMailFrame()
    fakeRows(1)
    po.openMailbox(ns)                             -- the next open retries and hooks
    _G.InboxFrame:Update(); _G.OpenMailFrame:Update()
    assert.equals(7, inboxSeen)
    assert.equals(1, openFired)
    po.openMailbox(ns)                             -- already installed: no double hook
    _G.InboxFrame:Update(); _G.OpenMailFrame:Update()
    assert.equals(14, inboxSeen)
    assert.equals(2, openFired)                    -- one hook, not two, on the open-letter side too
  end)

  it("a frame that exists without an Update method is not hooked and the install is retried", function()
    _G.InboxFrame = { pageNum = 1 }                -- no Update field yet
    _G.OpenMailFrame = {}
    ns.OnInboxRow(function() end)
    assert.has_no.errors(function() po.openMailbox(ns) end)
    _G.InboxFrame.Update = function() end          -- the mixin arrives later
    fakeRows(0)
    local seen = 0
    ns.OnInboxRow(function() seen = seen + 1 end)
    po.openMailbox(ns)
    _G.InboxFrame:Update()
    assert.equals(7, seen)
  end)

  describe("ns.RefreshInbox", function()
    it("redraws via InboxFrame:Update on Forever and does nothing away from the mailbox", function()
      _G.InboxFrame = newInboxFrame()
      ns.RefreshInbox()                            -- not at the mailbox
      assert.equals(0, _G.InboxFrame.updates)
      ns._atMailbox = true
      ns.RefreshInbox()
      assert.equals(1, _G.InboxFrame.updates)
    end)

    it("uses the InboxFrame_Update global on Retail", function()
      local n = 0
      _G.InboxFrame_Update = function() n = n + 1 end
      _G.InboxFrame = newInboxFrame()
      ns._atMailbox = true
      ns.RefreshInbox()
      assert.equals(1, n)
      assert.equals(0, _G.InboxFrame.updates)
    end)

    it("does nothing, and does not error, when neither exists yet", function()
      ns._atMailbox = true
      assert.has_no.errors(function() ns.RefreshInbox() end)
    end)
  end)

  describe("express Ctrl+click return", function()
    it("express Ctrl+click return redraws without a global InboxFrame_Update", function()
      ns = po.loadCore(true)
      fakeRows(0)                                  -- core's row hook reads the inbox size on every redraw
      _G.InboxFrame = newInboxFrame()
      _G.InboxFrame.openMailID = 5
      local origCalls = 0
      _G.InboxFrame_OnClick = function() origCalls = origCalls + 1 end
      _G.InboxFrameItem_OnEnter = function() end
      _G.HandleModifiedItemClick = function() end
      _G.IsControlKeyDown = function() return true end
      _G.IsShiftKeyDown = function() return false end
      _G.IsAltKeyDown = function() return false end
      -- GetInboxHeaderInfo(index): select(10, ...) = wasReturned, _, canReply
      _G.GetInboxHeaderInfo = function() return nil, nil, nil, nil, nil, nil, nil, nil, nil, false, nil, true end
      local returned
      _G.ReturnInboxItem = function(i) returned = i end
      po.openMailbox(ns)                           -- installs the InboxFrame_OnClick wrapper
      local checked
      local button = { SetChecked = function(_, v) checked = v end }
      assert.has_no.errors(function() _G.InboxFrame_OnClick(button, 3) end)
      assert.equals(3, returned)
      assert.is_false(checked)
      assert.equals(0, _G.InboxFrame.openMailID)
      assert.equals(1, _G.InboxFrame.updates)      -- the frame's Update, called exactly once
      assert.equals(0, origCalls)                  -- the native handler did not also run
    end)
  end)
end)
