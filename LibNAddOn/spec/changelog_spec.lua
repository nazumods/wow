-- changelog.lua isn't part of the libn.lua harness (it reads Settings and registers a settings
-- initializer), so this spec loads it standalone. `format` is file-local, so it is exercised
-- through the add-on's ShowChangelog, which hands the formatted text to ui.ShowCopyWindow (or
-- to Print when no UI lib is available).

describe("LibNAddOn changelog", function()
  local addOn, shown

  before_each(function()
    shown = nil
    local ns = {}
    assert(loadfile("LibNAddOn/changelog.lua"))("LibNAddOn", ns)
    addOn = {
      _TITLE = "Test",
      registerEvent = function() end,
      ui = { ShowCopyWindow = function(title, text) shown = { title = title, text = text } end },
    }
    ns.registerChangelog(addOn, "Test")
  end)

  describe("format (via ShowChangelog)", function()
    it("writes a v-prefixed header then the notes, one block per release", function()
      addOn.changelog = { { version = "12.0.5-r1", notes = "- fix a thing" } }
      addOn:ShowChangelog()
      assert.equals("v12.0.5-r1\n- fix a thing\n", shown.text)
    end)

    it("separates releases with a blank line and keeps the given (newest-first) order", function()
      addOn.changelog = {
        { version = "12.0.5-r2", notes = "- newer" },
        { version = "12.0.5-r1", notes = "- older" },
      }
      addOn:ShowChangelog()
      assert.equals("v12.0.5-r2\n- newer\n\nv12.0.5-r1\n- older\n", shown.text)
    end)

    it("trims leading and trailing whitespace from the notes", function()
      addOn.changelog = { { version = "1", notes = "\n  - a\n- b  \n\n" } }
      addOn:ShowChangelog()
      assert.equals("v1\n- a\n- b\n", shown.text)
    end)

    it("keeps interior line breaks in the notes", function()
      addOn.changelog = { { version = "1", notes = "### Fixes\n- a\n\n### Features\n- b" } }
      addOn:ShowChangelog()
      assert.equals("v1\n### Fixes\n- a\n\n### Features\n- b\n", shown.text)
    end)
  end)

  describe("ShowChangelog", function()
    it("titles the window after the add-on", function()
      addOn.changelog = { { version = "1", notes = "x" } }
      addOn:ShowChangelog()
      assert.equals("Test Changelog", shown.title)
    end)

    it("does nothing with no changelog", function()
      addOn:ShowChangelog()
      assert.is_nil(shown)
    end)

    it("does nothing with an empty changelog", function()
      addOn.changelog = {}
      addOn:ShowChangelog()
      assert.is_nil(shown)
    end)

    it("falls back to printing to chat when there is no UI lib", function()
      local printed
      addOn.ui = nil
      addOn.Print = function(text) printed = text end
      addOn.changelog = { { version = "1", notes = "x" } }
      addOn:ShowChangelog()
      assert.equals("v1\nx\n", printed)
    end)
  end)
end)
