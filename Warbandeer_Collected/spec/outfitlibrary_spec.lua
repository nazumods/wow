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
end)
