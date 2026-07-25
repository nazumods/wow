local po = require("ShadowsOfUI-PostOffice.spec.postoffice")

describe("ShadowsOfUI-PostOffice doNotWant", function()
  describe("ResolveDeleteIndex -- which letter a confirmed delete removes", function()
    local ns
    before_each(function() ns = po.load() end)

    -- An inbox is modelled as an array of opaque fingerprint strings (indices 1..#list);
    -- repeated strings model letters that share a fingerprint (identical AH expiries, etc).
    local function fpFrom(list)
      return function(i) return list[i] end, #list
    end

    it("deletes exactly the clicked index when the fingerprint is unique", function()
      local at, n = fpFrom({ "a", "b", "c" })
      assert.equals(2, ns.ResolveDeleteIndex("b", 2, n, at))
    end)

    it("deletes the clicked letter, not a lower-indexed twin, when fingerprints collide", function()
      -- indices 1 and 3 both carry fingerprint "cloth"; the user clicked index 3. The old
      -- first-match scan destroyed index 1 (the regression); the captured index fixes that.
      local at, n = fpFrom({ "cloth", "gold", "cloth" })
      assert.equals(3, ns.ResolveDeleteIndex("cloth", 3, n, at))
    end)

    it("deletes the clicked letter, not a higher-indexed twin, when fingerprints collide", function()
      local at, n = fpFrom({ "cloth", "gold", "cloth" })
      assert.equals(1, ns.ResolveDeleteIndex("cloth", 1, n, at))
    end)

    it("falls back to the first fingerprint match when the captured index has shifted", function()
      -- Mail arrived at the front mid-confirm: the clicked "cloth" that was at index 3 is now at
      -- index 4, and the captured index 3 holds a different letter ("gold") -- so the direct hit
      -- misses and the scan re-resolves to the first surviving "cloth".
      local at, n = fpFrom({ "new", "cloth", "gold", "cloth" })
      assert.equals(2, ns.ResolveDeleteIndex("cloth", 3, n, at))
    end)

    it("ignores a captured index that now points past a shrunk inbox", function()
      -- The inbox shrank to one letter; the captured index 3 is out of range, so we scan.
      local at, n = fpFrom({ "cloth" })
      assert.equals(1, ns.ResolveDeleteIndex("cloth", 3, n, at))
    end)

    it("returns nil (deletes nothing) when the letter is gone and nothing shares its fingerprint", function()
      local at, n = fpFrom({ "x", "y", "z" })
      assert.is_nil(ns.ResolveDeleteIndex("cloth", 2, n, at))
    end)

    it("scans from index 1 when no index was captured", function()
      local at, n = fpFrom({ "a", "cloth", "cloth" })
      assert.equals(2, ns.ResolveDeleteIndex("cloth", nil, n, at))
    end)
  end)

  describe("confirm payloads -- each dialog acts on the letter it was opened for", function()
    local ns, dialogs, letters, deleted, item, coin

    before_each(function()
      ns = po.load()
      dialogs = _G.StaticPopupDialogs
      item = { sender = "Auction House", subject = "Auction expired", hasItem = 1 }
      coin = { subject = "Payment", money = 5000 }
      letters = { item, coin, { sender = "Bob", subject = "Hi" } }
      deleted = po.inbox(letters)
    end)

    -- What onClick hands StaticPopup_Show as the dialog's payload, and what Blizzard hands
    -- straight back to OnAccept/OnShow.
    local function confirmFor(index)
      return { sig = ns.InboxFingerprint(index), index = index, money = letters[index].money }
    end

    it("destroys the accepted dialog's own letter when its sibling opened afterwards", function()
      -- #732: the item confirm is opened for letter 1 and the coin confirm for letter 2 before
      -- either is answered. Answering the coin confirm first must destroy 2, and the still-open
      -- item confirm must then destroy 1 -- neither may act on the other's letter.
      local itemConfirm, coinConfirm = confirmFor(1), confirmFor(2)
      dialogs[po.POPUP_MONEY].OnAccept(nil, coinConfirm)
      dialogs[po.POPUP_MAIL].OnAccept(nil, itemConfirm)
      assert.same({ coin, item }, deleted)
    end)

    it("re-resolves the second letter after the first accept shifted it up", function()
      -- Same two confirms, answered the other way round: destroying letter 1 slides the coin
      -- letter from index 2 to index 1, so the coin confirm's captured index now holds a
      -- different letter and its fingerprint has to find the real one.
      local itemConfirm, coinConfirm = confirmFor(1), confirmFor(2)
      dialogs[po.POPUP_MAIL].OnAccept(nil, itemConfirm)
      dialogs[po.POPUP_MONEY].OnAccept(nil, coinConfirm)
      assert.same({ item, coin }, deleted)
    end)

    it("follows its letter when mail arriving mid-confirm shifts every index up", function()
      local coinConfirm = confirmFor(2)
      table.insert(letters, 1, { sender = "Postmaster", subject = "Delivery" })
      dialogs[po.POPUP_MONEY].OnAccept(nil, coinConfirm)
      assert.same({ coin }, deleted)
    end)

    it("destroys nothing when its letter is gone by the time it is accepted", function()
      local coinConfirm = confirmFor(2)
      table.remove(letters, 2)
      dialogs[po.POPUP_MONEY].OnAccept(nil, coinConfirm)
      assert.same({}, deleted)
    end)

    it("shows the coin carried by the dialog being shown", function()
      local shown
      _G.MoneyFrame_Update = function(_, amount) shown = amount end
      dialogs[po.POPUP_MONEY].OnShow({ moneyFrame = {} }, confirmFor(2))
      assert.equals(5000, shown)
    end)

    it("closes the sibling confirm so only one of ours is ever answerable", function()
      assert.equals(po.POPUP_MONEY, dialogs[po.POPUP_MAIL].cancels)
      assert.equals(po.POPUP_MAIL, dialogs[po.POPUP_MONEY].cancels)
    end)
  end)
end)
