local collected = require("Warbandeer_Collected.spec.collected")

-- The save flow behind the transmogrifier's **Save Look** button (#699), and specifically the rule
-- #757 added to it: the look is read ONCE, when the name is committed, and every step after that
-- acts on that captured list.
--
-- Why this is worth a spec at all when the rest of the file is frames: the replace confirm is a
-- StaticPopup, which is not modal and never times out, so the user can keep staging pieces while it
-- waits. Re-reading the model when they finally clicked Yes replaced a library entry with a look
-- they were never asked about — and the library is the only copy, so nothing could undo it.

local SAVE_POPUP    = "WARBANDEER_COLLECTED_SAVE_LOOK"
local REPLACE_POPUP = "WARBANDEER_COLLECTED_REPLACE_LOOK"

-- A staged look with one recognisable appearance, so "which look landed" is assertable rather than
-- merely "something did".
---@param head number
---@return table[]
local function lookWith(ns, head)
  local list = ns.EmptyOutfitList()
  list[INVSLOT_HEAD].appearanceID = head
  return list
end

-- Type a name into the Save popup and accept it — the click that commits, and so the moment the
-- look is captured. `editBox` is the plain-field half of the two shapes `editBoxOf` accepts.
local function nameIt(env, name)
  env.dialogs[SAVE_POPUP].OnAccept({ editBox = { GetText = function() return name end } })
end

-- The head appearance of a stored library entry, decoded back out.
local function storedHead(ns, name)
  return ns.LibraryOutfitList(name)[INVSLOT_HEAD].appearanceID
end

describe("transmogrifier save flow", function()
  local ns, env
  before_each(function()
    ns = collected.load()
    env = collected.loadTransmogButtons(ns)
  end)

  describe("the replace confirm", function()
    it("stores the look it asked about, not whatever is on the model when Yes is clicked", function()
      env.model = lookWith(ns, 111)
      nameIt(env, "Boylane 3")
      assert.equal(111, storedHead(ns, "Boylane 3"))

      -- Save again under the same name: this is the click that arms the confirm, and so the look
      -- the confirm is about.
      env.model = lookWith(ns, 222)
      nameIt(env, "Boylane 3")
      assert.equal(REPLACE_POPUP, env.shown[#env.shown].which)
      assert.equal(111, storedHead(ns, "Boylane 3"))

      -- Leave the question hanging and stage something else entirely.
      env.model = lookWith(ns, 333)

      env.dialogs[REPLACE_POPUP].OnAccept()
      assert.equal(222, storedHead(ns, "Boylane 3"))
      assert.equal(1, #ns.LibraryOutfits())
    end)

    it("replaces under the library's own spelling of the name (#728)", function()
      env.model = lookWith(ns, 111)
      nameIt(env, "Boylane 3")

      env.model = lookWith(ns, 222)
      nameIt(env, "boylane 3")
      -- The popup has to name the entry actually at risk, not what was typed.
      assert.equal("Boylane 3", env.shown[#env.shown].data)

      env.dialogs[REPLACE_POPUP].OnAccept()
      assert.equal(1, #ns.LibraryOutfits())
      assert.equal("Boylane 3", ns.LibraryOutfits()[1].name)
      assert.equal(222, storedHead(ns, "Boylane 3"))
    end)

    it("saves nothing once the question has been answered No", function()
      env.model = lookWith(ns, 111)
      nameIt(env, "Boylane 3")

      env.model = lookWith(ns, 222)
      nameIt(env, "Boylane 3")
      env.dialogs[REPLACE_POPUP].OnCancel()

      -- A stale accept — the popup gone, the captured look released — must not write.
      env.dialogs[REPLACE_POPUP].OnAccept()
      assert.equal(111, storedHead(ns, "Boylane 3"))
    end)

    it("saves nothing when nothing armed it", function()
      env.dialogs[REPLACE_POPUP].OnAccept()
      assert.equal(0, #ns.LibraryOutfits())
    end)
  end)

  describe("a name not yet in the library", function()
    it("saves the captured look straight away, with no confirm", function()
      env.model = lookWith(ns, 111)
      nameIt(env, "TWW 1")
      assert.equal(0, #env.shown)
      assert.equal(111, storedHead(ns, "TWW 1"))
    end)

    it("stamps provenance from the look being saved", function()
      local staged = lookWith(ns, 111)
      env.model = staged
      nameIt(env, "TWW 1")
      assert.equal(1, #env.meta)
      assert.equal(staged, env.meta[1])
    end)
  end)

  -- Each of these refuses at capture time, which is BEFORE the collision is even looked up — being
  -- asked to replace a look and only then told there was nothing to save describes a save that
  -- never could have happened.
  describe("a look that can't be read", function()
    local function seedAndRetry(name)
      env.model = lookWith(ns, 111)
      nameIt(env, name)
      env.shown = {}
    end

    it("won't prompt or save when the model scene has no actor yet", function()
      seedAndRetry("Boylane 3")
      env.model = nil
      nameIt(env, "Boylane 3")
      assert.equal(0, #env.shown)
      assert.equal(111, storedHead(ns, "Boylane 3"))
      assert.matches("isn't ready", env.printed[#env.printed])
    end)

    it("won't prompt or save when there are no appearances on the model", function()
      seedAndRetry("Boylane 3")
      env.model = ns.EmptyOutfitList()
      nameIt(env, "Boylane 3")
      assert.equal(0, #env.shown)
      assert.equal(111, storedHead(ns, "Boylane 3"))
      assert.matches("Nothing to save", env.printed[#env.printed])
    end)

    it("won't prompt or save while item data is still streaming", function()
      seedAndRetry("Boylane 3")
      env.model, env.pending = lookWith(ns, 222), true
      nameIt(env, "Boylane 3")
      assert.equal(0, #env.shown)
      assert.equal(111, storedHead(ns, "Boylane 3"))
      assert.matches("still loading", env.printed[#env.printed])
    end)

    it("won't read the model at all for a blank name", function()
      env.model = lookWith(ns, 111)
      nameIt(env, "   ")
      assert.equal(0, #env.shown)
      assert.equal(0, #ns.LibraryOutfits())
      assert.matches("Give the look a name", env.printed[#env.printed])
    end)
  end)
end)
