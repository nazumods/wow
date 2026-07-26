local bars = require("Warbandeer_Bars.spec.bars")

-- restore.lua touches no WoW API at load time (every C_* reference is and-guarded), so
-- ns.Restore can be driven out of game against the fake action bar in spec/bars.lua.
-- These specs cover the petaction/futurespell branch (#751): both types are documented as
-- "cleared on restore", but picking the action up without dropping it let the shared
-- place/blank tail put it straight back, so a pre-existing action survived a restore that
-- should have blanked it.
describe("Warbandeer_Bars restore", function()
  local ns, bar

  local SLOT = 5

  ---@param initial table?  starting bar contents, { [slotID] = { type, index } }
  local function setup(initial)
    bar = bars.actionbars(initial)
    ns  = bars.loadRestore(bar.env)
  end

  local function restore(slots)
    ns.Restore({ slots = slots }, { bars = true }, true)
  end

  for _, case in ipairs({
    { type = "petaction",   label = "pet action" },
    { type = "futurespell", label = "unlearned spell" },
  }) do
    describe(case.type .. " slots", function()
      local warning = "Slot " .. SLOT .. ": " .. case.label .. " can't be restored — slot cleared"

      it("blanks a slot the character already has an action in", function()
        setup({ [SLOT] = { "spell", 1234 } })
        restore({ { id = SLOT, type = case.type } })
        assert.is_nil(bar.slots[SLOT])
      end)

      it("blanks a slot that already holds the same type", function()
        -- the "current state already matches" early-out must not apply here: the wanted
        -- state for these types is empty, never "whatever is there now"
        setup({ [SLOT] = { case.type } })
        restore({ { id = SLOT, type = case.type } })
        assert.is_nil(bar.slots[SLOT])
      end)

      it("leaves an already-empty slot empty and says nothing", function()
        setup()
        restore({ { id = SLOT, type = case.type } })
        assert.is_nil(bar.slots[SLOT])
        -- no "Slot error:" from the pcall, and no warning about a button that never existed
        assert.are.same({}, ns.printed)
      end)

      it("warns about the slot it cleared", function()
        setup({ [SLOT] = { "spell", 1234 } })
        restore({ { id = SLOT, type = case.type } })
        assert.are.same({ "|cffff9900[Bars]|r " .. warning }, ns.printed)
      end)

      it("drops the picked-up action instead of leaking it onto the cursor", function()
        -- the bug: a non-empty cursor at the tail placed the action back into the slot;
        -- a leak would also swap into whichever slot the loop handles next
        setup({ [SLOT] = { "spell", 1234 }, [SLOT + 1] = { "spell", 5678 } })
        restore({
          { id = SLOT,     type = case.type },
          { id = SLOT + 1, type = "spell", index = 99 },
        })
        assert.is_nil(bar.cursor)
        assert.is_nil(bar.slots[SLOT])
        assert.are.same({ "spell", 99 }, bar.slots[SLOT + 1])
      end)
    end)
  end

  describe("ordinary slots are unaffected", function()
    it("still places a spell slot", function()
      setup()
      restore({ { id = SLOT, type = "spell", index = 42 } })
      assert.are.same({ "spell", 42 }, bar.slots[SLOT])
      assert.is_nil(bar.cursor)
      assert.are.same({}, ns.printed)
    end)

    it("leaves a spell slot that already holds that spell untouched", function()
      setup({ [SLOT] = { "spell", 42 } })
      restore({ { id = SLOT, type = "spell", index = 42 } })
      assert.are.same({ "spell", 42 }, bar.slots[SLOT])
    end)

    it("clears a slot the profile doesn't mention", function()
      setup({ [SLOT] = { "spell", 42 }, [SLOT + 1] = { "spell", 5678 } })
      restore({ { id = SLOT, type = "spell", index = 42 } })
      assert.is_nil(bar.slots[SLOT + 1])
    end)
  end)
end)
