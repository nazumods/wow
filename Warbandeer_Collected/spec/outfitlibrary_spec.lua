local collected = require("Warbandeer_Collected.spec.collected")

-- The outfit library (#655) — our own account-wide store, needed because the game's custom sets
-- are per-character. Pure Lua over `ns.db` plus the codec, so unlike the rest of the outfit chain
-- it can be tested without the client.

-- An outfit list with a recognisable appearance in one slot, so a round-trip can be asserted on
-- something more specific than "it came back non-nil".
---@param head number
---@return table[]
local function lookWith(ns, head)
  local list = ns.EmptyOutfitList()
  list[INVSLOT_HEAD].appearanceID = head
  return list
end

describe("outfit library", function()
  local ns
  before_each(function() ns = collected.load() end)

  describe("SaveLibraryOutfit", function()
    it("stores the look as its /customset encoding", function()
      assert.is_true(ns.SaveLibraryOutfit("mog", lookWith(ns, 7019)))
      local entry = ns.LibraryOutfit("mog")
      assert.equal("mog", entry.name)
      -- Stored as the wire string, not the table: that's what makes each entry its own export.
      assert.equal(ns.EncodeOutfit(lookWith(ns, 7019)), entry.look)
    end)

    it("round-trips the look back through LibraryOutfitList", function()
      ns.SaveLibraryOutfit("mog", lookWith(ns, 7019))
      local list = ns.LibraryOutfitList("mog")
      assert.equal(7019, list[INVSLOT_HEAD].appearanceID)
    end)

    it("replaces a same-named entry in place rather than appending", function()
      ns.SaveLibraryOutfit("a", lookWith(ns, 1))
      ns.SaveLibraryOutfit("b", lookWith(ns, 2))
      ns.SaveLibraryOutfit("a", lookWith(ns, 99))
      assert.equal(2, #ns.LibraryOutfits())
      -- Still first: re-saving must not reorder the library under the user.
      assert.equal("a", ns.LibraryOutfits()[1].name)
      assert.equal(99, ns.LibraryOutfitList("a")[INVSLOT_HEAD].appearanceID)
    end)

    it("keeps insertion order", function()
      for _, n in ipairs({ "one", "two", "three" }) do ns.SaveLibraryOutfit(n, ns.EmptyOutfitList()) end
      local names = {}
      for i, o in ipairs(ns.LibraryOutfits()) do names[i] = o.name end
      assert.same({ "one", "two", "three" }, names)
    end)

    it("rejects an empty or whitespace-only name", function()
      local ok, err = ns.SaveLibraryOutfit("", ns.EmptyOutfitList())
      assert.is_false(ok)
      assert.equal("a name is required", err)
      assert.is_false((ns.SaveLibraryOutfit("   ", ns.EmptyOutfitList())))
      assert.equal(0, #ns.LibraryOutfits())
    end)

    it("trims surrounding whitespace so ' x ' and 'x' are one entry", function()
      ns.SaveLibraryOutfit("  mog  ", lookWith(ns, 5))
      assert.equal("mog", ns.LibraryOutfits()[1].name)
      ns.SaveLibraryOutfit("mog", lookWith(ns, 6))
      assert.equal(1, #ns.LibraryOutfits())
    end)

    -- #728: the reported bug is the duplicate this now refuses to create.
    it("replaces a look whose name differs only in case", function()
      ns.SaveLibraryOutfit("Boylane 3", lookWith(ns, 1))
      ns.SaveLibraryOutfit("boylane 3", lookWith(ns, 2))
      assert.equal(1, #ns.LibraryOutfits())
      assert.equal(2, ns.LibraryOutfitList("Boylane 3")[INVSLOT_HEAD].appearanceID)
    end)

    -- …and keeps the name it was stored under. Names are display strings — class-coloured in the
    -- dropdown, printed by `/collected outfit list` — so a save the user asked to be a REPLACEMENT
    -- has no business re-capitalising the entry. Rename is how a name changes.
    it("leaves a replaced entry's own capitalisation alone", function()
      ns.SaveLibraryOutfit("Boylane 3", lookWith(ns, 1))
      ns.SaveLibraryOutfit("boylane 3", lookWith(ns, 2))
      assert.equal("Boylane 3", ns.LibraryOutfits()[1].name)
    end)
  end)

  describe("provenance", function()
    local META = { char = "Triandra-Silvermoon", class = "DRUID", forClass = "WARRIOR", armor = "Plate" }

    it("stores the fields the caller collected", function()
      ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList(), META)
      local entry = ns.LibraryOutfit("mog")
      assert.equal("Triandra-Silvermoon", entry.char)
      assert.equal("DRUID", entry.class)
      assert.equal("WARRIOR", entry.forClass)   -- the SET's class, not the saver's
      assert.equal("Plate", entry.armor)
    end)

    it("overwrites provenance when the look is replaced", function()
      -- The entry now holds a different look, so keeping the old attribution would be a lie.
      ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList(), META)
      ns.SaveLibraryOutfit("mog", lookWith(ns, 7019), { char = "Other-Realm", class = "MAGE" })
      local entry = ns.LibraryOutfit("mog")
      assert.equal("Other-Realm", entry.char)
      assert.equal("MAGE", entry.class)
      assert.is_nil(entry.forClass)   -- absent in the new meta, so cleared rather than inherited
      assert.is_nil(entry.armor)
    end)

    it("saves without provenance when none is given", function()
      -- The command path and any caller that can't determine it must still work.
      assert.is_true(ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList()))
      assert.is_nil(ns.LibraryOutfit("mog").char)
    end)

    it("survives a rename", function()
      ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList(), META)
      ns.RenameLibraryOutfit("mog", "renamed")
      assert.equal("Triandra-Silvermoon", ns.LibraryOutfit("renamed").char)
    end)
  end)

  describe("LibraryOutfit", function()
    it("returns the entry and its index", function()
      ns.SaveLibraryOutfit("a", ns.EmptyOutfitList())
      ns.SaveLibraryOutfit("b", ns.EmptyOutfitList())
      local entry, index = ns.LibraryOutfit("b")
      assert.equal("b", entry.name)
      assert.equal(2, index)
    end)

    it("is nil for an unknown or empty name", function()
      assert.is_nil(ns.LibraryOutfit("nope"))
      assert.is_nil(ns.LibraryOutfit(""))
    end)

    -- #728: the guards built on this function exist to stop an accidental duplicate, and matching
    -- exactly let a case variant past every one of them.
    it("matches a name that differs only in case", function()
      ns.SaveLibraryOutfit("Boylane 3", ns.EmptyOutfitList())
      local entry, index = ns.LibraryOutfit("boylane 3")
      assert.equal("Boylane 3", entry.name)
      assert.equal(1, index)
      assert.equal("Boylane 3", ns.LibraryOutfit("BOYLANE 3").name)
    end)

    -- A library saved before #728 may hold both variants — they were legal — so each name still has
    -- to resolve to its own entry rather than to whichever comes first.
    it("prefers an exact match over an earlier case variant", function()
      ns.LibraryOutfits()[1] = { name = "mog", look = ns.EncodeOutfit(ns.EmptyOutfitList()) }
      ns.LibraryOutfits()[2] = { name = "MOG", look = ns.EncodeOutfit(ns.EmptyOutfitList()) }
      assert.equal(2, select(2, ns.LibraryOutfit("MOG")))
      assert.equal(1, select(2, ns.LibraryOutfit("mog")))
    end)
  end)

  describe("LibraryOutfitList", function()
    it("errors rather than returning a list for an unknown name", function()
      local list, err = ns.LibraryOutfitList("nope")
      assert.is_nil(list)
      assert.is_truthy(err:find("nope", 1, true))
    end)

    it("surfaces the decoder's error for a corrupt stored string", function()
      -- A hand-edited SavedVariables file shouldn't dress the model from half an outfit.
      ns.SaveLibraryOutfit("bad", ns.EmptyOutfitList())
      ns.LibraryOutfit("bad").look = "v1 1,2,3"
      local list, err = ns.LibraryOutfitList("bad")
      assert.is_nil(list)
      assert.is_string(err)
    end)
  end)

  describe("RenameLibraryOutfit", function()
    it("renames in place, keeping position and look", function()
      ns.SaveLibraryOutfit("a", lookWith(ns, 42))
      ns.SaveLibraryOutfit("b", ns.EmptyOutfitList())
      assert.is_true(ns.RenameLibraryOutfit("a", "renamed"))
      assert.equal("renamed", ns.LibraryOutfits()[1].name)
      assert.equal(42, ns.LibraryOutfitList("renamed")[INVSLOT_HEAD].appearanceID)
      assert.is_nil(ns.LibraryOutfit("a"))
    end)

    it("allows a look to keep its own name", function()
      -- Re-committing an untouched name field must not read as a collision.
      ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList())
      assert.is_true(ns.RenameLibraryOutfit("mog", "mog"))
    end)

    it("rejects a name another look already holds", function()
      ns.SaveLibraryOutfit("a", ns.EmptyOutfitList())
      ns.SaveLibraryOutfit("b", ns.EmptyOutfitList())
      local ok, err = ns.RenameLibraryOutfit("a", "b")
      assert.is_false(ok)
      assert.is_truthy(err:find("already in the library", 1, true))
      assert.equal("a", ns.LibraryOutfits()[1].name)
    end)

    it("rejects an empty new name", function()
      ns.SaveLibraryOutfit("a", ns.EmptyOutfitList())
      local ok, err = ns.RenameLibraryOutfit("a", "  ")
      assert.is_false(ok)
      assert.equal("a name is required", err)
    end)

    -- The half of #728 that pulls the other way: with the lookup case-insensitive, a look renaming
    -- itself finds ITSELF, so fixing your own capitalisation must stay legal rather than read as a
    -- collision with a look that isn't there.
    it("allows a rename that only changes a look's own capitalisation", function()
      ns.SaveLibraryOutfit("boylane 3", ns.EmptyOutfitList())
      assert.is_true(ns.RenameLibraryOutfit("boylane 3", "Boylane 3"))
      assert.equal("Boylane 3", ns.LibraryOutfits()[1].name)
      assert.equal(1, #ns.LibraryOutfits())
    end)

    it("rejects a name ANOTHER look holds in a different case", function()
      ns.SaveLibraryOutfit("Boylane 3", ns.EmptyOutfitList())
      ns.SaveLibraryOutfit("other", ns.EmptyOutfitList())
      local ok, err = ns.RenameLibraryOutfit("other", "boylane 3")
      assert.is_false(ok)
      -- Names the STORED entry, so the refusal points at a look the user can actually find.
      assert.is_truthy(err:find("\"Boylane 3\" is already in the library", 1, true))
      assert.equal("other", ns.LibraryOutfits()[2].name)
    end)

    it("reports an unknown source name", function()
      local ok, err = ns.RenameLibraryOutfit("nope", "x")
      assert.is_false(ok)
      assert.is_truthy(err:find("nope", 1, true))
    end)
  end)

  describe("DeleteLibraryOutfit", function()
    it("removes the entry and closes the gap", function()
      for _, n in ipairs({ "one", "two", "three" }) do ns.SaveLibraryOutfit(n, ns.EmptyOutfitList()) end
      assert.is_true(ns.DeleteLibraryOutfit("two"))
      local names = {}
      for i, o in ipairs(ns.LibraryOutfits()) do names[i] = o.name end
      assert.same({ "one", "three" }, names)
    end)

    it("is false for an unknown name", function()
      assert.is_false(ns.DeleteLibraryOutfit("nope"))
    end)
  end)

  -- The change notification (#727). The two surfaces that show the library — the dressing room's
  -- outfit row and the library window — used to be refreshed by whichever caller happened to know
  -- about one of them, and neither ever refreshed the other, so one sat listing a look the other
  -- had just deleted.
  describe("change notification", function()
    ---Count the notifications `ns` fires from here on.
    ---@return fun(): number
    local function counting(n)
      local fired = 0
      n.OnLibraryChanged(function() fired = fired + 1 end)
      return function() return fired end
    end

    it("fires on a save, a rename and a delete alike", function()
      local fired = counting(ns)
      ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList())
      assert.equal(1, fired())
      ns.RenameLibraryOutfit("mog", "renamed")
      assert.equal(2, fired())
      ns.DeleteLibraryOutfit("renamed")
      assert.equal(3, fired())
    end)

    -- Only a write that HAPPENED is announced: a refused save or a delete that found nothing left
    -- the library exactly as it was, and refreshing on it would repaint both windows for nothing.
    it("stays quiet when nothing changed", function()
      local fired = counting(ns)
      ns.SaveLibraryOutfit("", ns.EmptyOutfitList())
      ns.DeleteLibraryOutfit("nope")
      ns.RenameLibraryOutfit("nope", "x")
      assert.equal(0, fired())
      ns.SaveLibraryOutfit("a", ns.EmptyOutfitList())
      ns.SaveLibraryOutfit("b", ns.EmptyOutfitList())
      assert.is_false((ns.RenameLibraryOutfit("a", "b")))   -- the name is taken
      assert.equal(2, fired())
    end)

    it("tells every subscriber, so a second surface needs no wiring of its own", function()
      local one, two = counting(ns), counting(ns)
      ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList())
      assert.equal(1, one())
      assert.equal(1, two())
    end)

    -- What `ImportCharacterSets` needs: up to 25 writes in one loop, and a refresh per write would
    -- rebuild both surfaces — and re-dress the library window's preview model — 25 times over.
    it("collapses a batch into one notification, fired after the batch closes", function()
      local fired = counting(ns)
      ns.LibraryBatch(function()
        for _, n in ipairs({ "one", "two", "three" }) do
          ns.SaveLibraryOutfit(n, ns.EmptyOutfitList())
        end
        assert.equal(0, fired(), "the batch must not notify while it is still writing")
      end)
      assert.equal(1, fired())
      assert.equal(3, #ns.LibraryOutfits())
    end)

    it("says nothing for a batch that changed nothing", function()
      local fired = counting(ns)
      ns.LibraryBatch(function() ns.DeleteLibraryOutfit("nope") end)
      assert.equal(0, fired())
    end)

    -- A batch that lands inside another still fires once, at the OUTER close — so nesting can't
    -- announce a half-finished library.
    it("nests", function()
      local fired = counting(ns)
      ns.LibraryBatch(function()
        ns.SaveLibraryOutfit("a", ns.EmptyOutfitList())
        ns.LibraryBatch(function() ns.SaveLibraryOutfit("b", ns.EmptyOutfitList()) end)
        assert.equal(0, fired())
      end)
      assert.equal(1, fired())
    end)
  end)

  -- Importing the game's own per-character transmog sets (#663). The names come from the game,
  -- not the user, so they collide across characters — and the import is expected to be re-run on
  -- a character already done.
  describe("ImportLibraryOutfit", function()
    it("saves under the set's own name when the library has no such entry", function()
      local n = collected.load()
      local status, name = n.ImportLibraryOutfit("TWW 1", lookWith(n, 7019), { armor = "Plate" })
      assert.equal("saved", status)
      assert.equal("TWW 1", name)
      assert.equal("Plate", n.LibraryOutfit("TWW 1").armor)
    end)

    -- Re-running the import on a character already done must be a no-op, not a pile of suffixes.
    it("skips a name already holding the identical look", function()
      local n = collected.load()
      n.ImportLibraryOutfit("TWW 1", lookWith(n, 7019))
      local status, name = n.ImportLibraryOutfit("TWW 1", lookWith(n, 7019))
      assert.equal("skipped", status)
      assert.equal("TWW 1", name)
      assert.equal(1, #n.LibraryOutfits())
    end)

    -- The case the issue names: two characters that each called a different look "TWW 1".
    it("suffixes when the name is taken by a DIFFERENT look", function()
      local n = collected.load()
      n.ImportLibraryOutfit("TWW 1", lookWith(n, 7019))
      local status, name = n.ImportLibraryOutfit("TWW 1", lookWith(n, 1234))
      assert.equal("renamed", status)
      assert.equal("TWW 1 (2)", name)
      assert.equal(2, #n.LibraryOutfits())
    end)

    it("never modifies the entry it collided with", function()
      local n = collected.load()
      n.ImportLibraryOutfit("TWW 1", lookWith(n, 7019), { char = "First-Realm" })
      n.ImportLibraryOutfit("TWW 1", lookWith(n, 1234), { char = "Second-Realm" })
      local original = n.LibraryOutfit("TWW 1")
      assert.equal(7019, n.DecodeOutfit(original.look)[INVSLOT_HEAD].appearanceID)
      assert.equal("First-Realm", original.char)
    end)

    -- Idempotent even once a collision has already renamed it: the suffix scan applies the same
    -- same-look test, so a third pass finds the (2) entry rather than creating a (3).
    it("stays idempotent after a collision has been suffixed", function()
      local n = collected.load()
      n.ImportLibraryOutfit("TWW 1", lookWith(n, 7019))
      n.ImportLibraryOutfit("TWW 1", lookWith(n, 1234))
      local status, name = n.ImportLibraryOutfit("TWW 1", lookWith(n, 1234))
      assert.equal("skipped", status)
      assert.equal("TWW 1 (2)", name)
      assert.equal(2, #n.LibraryOutfits())
    end)

    it("walks past occupied suffixes to the first free one", function()
      local n = collected.load()
      n.ImportLibraryOutfit("TWW 1", lookWith(n, 1))
      n.ImportLibraryOutfit("TWW 1", lookWith(n, 2))   -- takes (2)
      n.ImportLibraryOutfit("TWW 1", lookWith(n, 3))   -- takes (3)
      local _, name = n.ImportLibraryOutfit("TWW 1", lookWith(n, 4))
      assert.equal("TWW 1 (4)", name)
    end)

    -- forClass is unrecoverable from a stored set (appearance ids, no memory of whose set it was),
    -- so it stays nil — and `FilterOutfits` must therefore let an import through every class filter.
    it("records provenance without forClass, and the entry survives every filter", function()
      local n = collected.load()
      n.ImportLibraryOutfit("TWW 1", lookWith(n, 7019),
        { char = "Keshan-Silvermoon", class = "ROGUE", armor = "Leather" })
      local entry = n.LibraryOutfit("TWW 1")
      assert.equal("Keshan-Silvermoon", entry.char)
      assert.equal("ROGUE", entry.class)
      assert.is_nil(entry.forClass)
      for _, filter in ipairs({ { class = "WARRIOR" }, { class = "ROGUE" }, { armor = "Leather" } }) do
        assert.equal(1, #n.FilterOutfits(n.LibraryOutfits(), filter))
      end
    end)
  end)
end)
