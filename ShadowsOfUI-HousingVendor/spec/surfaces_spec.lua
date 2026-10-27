local hv = require("ShadowsOfUI-HousingVendor.spec.hvendor")

-- The merchant's Buy and Buyback tabs reuse the same MerchantItemNItemButton frames, so an
-- overlay painted on the Buy tab must not survive onto a bought-back row (surfaces.lua).
describe("ShadowsOfUI-HousingVendor merchant surfaces", function()
  local w
  before_each(function()
    w = hv.loadSurfaces()
    -- slot 1 and 2 hold owned decor, slot 3 is plain merchandise
    w.state.links = { "link:1", "link:2", "link:3" }
    w.state.decor["link:1"] = { owned = true, stored = 4, bonusAvailable = false }
    w.state.decor["link:2"] = { owned = true, stored = 0, bonusAvailable = true }
  end)

  local function overlay(i) return w.buttons[i].shvOverlay end

  it("Buy tab: paints an overlay on decor rows only", function()
    w.hooks.MerchantFrame_UpdateMerchantInfo()
    assert.is_true(overlay(1).count.shown)
    assert.equals(4, overlay(1).count.text)
    assert.is_true(overlay(1).check.shown)
    assert.is_nil(overlay(3))   -- non-decor row never gets an overlay built
  end)

  it("Buy tab: a repaint strips the previous page's indicators before painting", function()
    w.hooks.MerchantFrame_UpdateMerchantInfo()
    assert.is_true(overlay(2).star.shown)
    w.state.decor["link:2"] = nil   -- same button now holds something else
    w.hooks.MerchantFrame_UpdateMerchantInfo()
    assert.is_false(overlay(2).count.shown)
    assert.is_false(overlay(2).star.shown)
    assert.is_false(overlay(2).check.shown)
  end)

  it("Buy tab: pages the link index by MERCHANT_ITEMS_PER_PAGE", function()
    w.state.links = { [4] = "link:4" }
    w.state.decor["link:4"] = { owned = true, stored = 9 }
    _G.MerchantFrame.page = 2
    w.hooks.MerchantFrame_UpdateMerchantInfo()
    assert.equals(9, overlay(1).count.text)   -- button 1 on page 2 is merchant index 4
  end)

  it("Buyback tab: a repaint hides every indicator left from the Buy tab", function()
    w.hooks.MerchantFrame_UpdateMerchantInfo()
    w.hooks.MerchantFrame_UpdateBuybackInfo()
    for i = 1, 2 do
      assert.is_false(overlay(i).count.shown)
      assert.is_false(overlay(i).star.shown)
      assert.is_false(overlay(i).check.shown)
      assert.is_false(overlay(i).wanted.shown)
    end
  end)

  it("Buyback tab: does not decorate bought-back rows even when their link is decor", function()
    w.hooks.MerchantFrame_UpdateBuybackInfo()
    assert.is_nil(overlay(1))
  end)

  it("honours the per-indicator toggles", function()
    w.state.db.countBadge = false
    w.hooks.MerchantFrame_UpdateMerchantInfo()
    assert.is_false(overlay(1).count.shown)
    assert.is_true(overlay(1).check.shown)
  end)

  describe("refresher (settings change)", function()
    it("repaints only on the shown Buy tab", function()
      w.refreshers[1]()
      assert.is_true(overlay(1).count.shown)
    end)

    it("leaves the Buyback tab alone, so Buy overlays never reappear on bought-back rows", function()
      w.hooks.MerchantFrame_UpdateMerchantInfo()
      w.hooks.MerchantFrame_UpdateBuybackInfo()
      _G.MerchantFrame.selectedTab = 2
      w.refreshers[1]()
      assert.is_false(overlay(1).count.shown)
      assert.is_false(overlay(1).check.shown)
    end)

    it("does nothing while the merchant is closed", function()
      _G.MerchantFrame.shown = false
      w.refreshers[1]()
      assert.is_nil(overlay(1))
    end)
  end)
end)
