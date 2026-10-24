local ilvl = require("ShadowsOfUI-Ilvl.spec.ilvl")

describe("ShadowsOfUI-Ilvl WantGear", function()
  local ns, st
  before_each(function()
    ns, st = ilvl.load()
    st.itemClass[1] = ilvl.ARMOR
    st.itemClass[2] = ilvl.WEAPON
    st.itemClass[3] = 0   -- consumable
  end)

  it("accepts weapons and armor", function()
    assert.is_true(ns.WantGear(1, 4))
    assert.is_true(ns.WantGear(2, 4))
  end)

  it("rejects other item classes", function()
    assert.is_false(ns.WantGear(3, 4))
  end)

  it("rejects an item that resolves to no class (uncached)", function()
    assert.is_false(ns.WantGear(99, 4))
  end)

  it("defaults the minimum quality to 3 (Rare): Uncommon-or-better passes the threshold", function()
    -- the check is `quality < minQuality - 1`: minQuality 3 admits quality >= 2
    assert.is_true(ns.WantGear(1, 2))
    assert.is_false(ns.WantGear(1, 1))
  end)

  it("follows the saved minimum-quality setting", function()
    ns.db.minQuality = 5
    assert.is_false(ns.WantGear(1, 3))
    assert.is_true(ns.WantGear(1, 4))
    ns.db.minQuality = 1
    assert.is_true(ns.WantGear(1, 0))
  end)

  it("treats a nil quality as 0 (Poor)", function()
    assert.is_false(ns.WantGear(1, nil))
    ns.db.minQuality = 1
    assert.is_true(ns.WantGear(1, nil))
  end)

  it("works without a db at all", function()
    ns.db = nil
    assert.is_true(ns.WantGear(1, 3))
  end)
end)

describe("ShadowsOfUI-Ilvl UpdateButton", function()
  local ns, st, button
  before_each(function()
    ns, st = ilvl.load()
    st.itemClass[100], st.itemClass[200], st.itemClass[300] = ilvl.ARMOR, ilvl.ARMOR, 0
    button = ilvl.button("ContainerFrame1Item1")
  end)

  local function item(id, opts) return ilvl.item(st, id, opts) end

  it("paints the ilvl once the item data has loaded, not before", function()
    ns.UpdateButton(button, item(100, { ilvl = 515 }))
    assert.is_nil(button.soiIlvl)
    st.flush()
    assert.equals(515, button.soiIlvl.text)
    assert.is_true(button.soiIlvl.shown)
  end)

  it("a cached item resolving synchronously paints immediately", function()
    ns.UpdateButton(button, item(100, { ilvl = 515, sync = true }))
    assert.equals(515, button.soiIlvl.text)
  end)

  it("a later refresh wins over an earlier load that fires late (rapid bag churn)", function()
    ns.UpdateButton(button, item(100, { ilvl = 400 }))                -- slow load, old item
    ns.UpdateButton(button, item(200, { ilvl = 600, sync = true }))   -- cached, resolves at once
    assert.equals(600, button.soiIlvl.text)
    st.flush(1)                                                       -- the stale callback lands
    assert.equals(600, button.soiIlvl.text)
  end)

  it("the newest of several in-flight loads is the one that paints", function()
    ns.UpdateButton(button, item(100, { ilvl = 400 }))
    ns.UpdateButton(button, item(200, { ilvl = 600 }))
    st.flush(2)
    assert.equals(600, button.soiIlvl.text)
    st.flush(1)
    assert.equals(600, button.soiIlvl.text)
  end)

  it("emptying the slot invalidates an in-flight paint for the previous item", function()
    ns.UpdateButton(button, item(100, { ilvl = 400 }))
    ns.UpdateButton(button, nil)
    st.flush()
    assert.is_nil(button.soiIlvl)
  end)

  it("an empty Item object invalidates an in-flight paint too", function()
    ns.UpdateButton(button, item(100, { ilvl = 400 }))
    ns.UpdateButton(button, item(0, { empty = true }))
    st.flush()
    assert.is_nil(button.soiIlvl)
  end)

  it("CleanButton invalidates an in-flight paint (mode switched off mid-load)", function()
    ns.UpdateButton(button, item(100, { ilvl = 400 }))
    ns.CleanButton(button)
    st.flush()
    assert.is_nil(button.soiIlvl)
  end)

  it("a non-gear item cleans the button instead of tagging it", function()
    ns.UpdateButton(button, item(100, { ilvl = 400, sync = true }))
    assert.is_true(button.soiIlvl.shown)
    ns.UpdateButton(button, item(300, { sync = true }))       -- now a consumable
    assert.is_false(button.soiIlvl.shown)
  end)

  it("an item below the minimum quality is not tagged", function()
    ns.UpdateButton(button, item(100, { quality = 1, sync = true }))
    assert.is_nil(button.soiIlvl)
  end)

  it("overlay mode shows the track in its own label, or hides it for non-upgradeable gear", function()
    st.upgrade = { trackString = "Champion", currentLevel = 2 }
    ns.UpdateButton(button, item(100, { ilvl = 515, sync = true }))
    assert.equals("C2", button.soiTrack.text)
    assert.is_true(button.soiTrack.shown)
    st.upgrade = nil
    ns.UpdateButton(button, item(100, { ilvl = 515, sync = true }))
    assert.is_false(button.soiTrack.shown)
  end)

  it("inset mode paints one combined label and leaves the corner overlay alone", function()
    st.upgrade = { trackString = "Hero", currentLevel = 3 }
    ns.UpdateButton(button, item(100, { ilvl = 580, sync = true }), true)
    assert.is_true(button.soiInset.shown)
    assert.is_truthy(button.soiInset.text:find("580", 1, true))
    assert.is_truthy(button.soiInset.text:find("H3", 1, true))
    assert.is_nil(button.soiIlvl)
  end)

  it("inset mode has no track suffix for non-upgradeable gear", function()
    ns.UpdateButton(button, item(100, { ilvl = 580, sync = true }), true)
    assert.is_nil(button.soiInset.text:find("  ", 1, true))
  end)
end)
