local collected = require("Warbandeer_Collected.spec.collected")

-- The `/collected outfit push` command surface (outfitcommands.lua). The command had reimplemented
-- the push with its own EXACT-match existing-set scan, so pushing a case-mismatched name created a
-- SECOND character set where the UI path would have replaced (#922). The fix routes the command
-- through the shared, case-insensitive `ns.PushLookToCharacter` (#770 step 8), which is itself covered
-- by outfitverbs_spec — so this pins only that the command DELEGATES rather than re-scanning.

describe("/collected outfit push (#922 delegation)", function()
  local ns, handler, calls, printed

  before_each(function()
    ns = collected.load()
    handler = collected.loadOutfitCommands(ns)
    calls, printed = {}, nil
    -- withLook resolves the typed name to the stored entry (case-insensitive, #728) and every caller
    -- takes entry.name back — so a lower-case "boylane 3" resolves to the stored "Boylane 3".
    ns.LibraryOutfit = function(_) return { name = "Boylane 3" } end
    ns.PushLookToCharacter = function(name, confirmed)
      calls[#calls + 1] = { name = name, confirmed = confirmed }
      return { message = "pushed" }
    end
    ns.Print = function(msg) printed = msg end
  end)

  it("routes push through the shared case-insensitive rule with the stored spelling", function()
    handler(nil, "push boylane 3")
    assert.equal(1, #calls)
    assert.equal("Boylane 3", calls[1].name) -- the stored spelling from withLook, not what was typed
    assert.is_true(calls[1].confirmed)         -- replace-without-prompt: a typed verb is explicit intent
    assert.equal("pushed", printed)            -- the rule's own message is surfaced verbatim
  end)

  it("does not re-scan the custom sets itself (delegation, not a private exact match)", function()
    -- If the command reverted to its own scan it would call these instead of the shared rule; making
    -- them explode proves the exercised path never touches them.
    ns.CustomSets = function() error("command must not scan CustomSets directly") end
    ns.SaveCustomSet = function() error("command must not call SaveCustomSet directly") end
    handler(nil, "push Boylane 3")
    assert.equal(1, #calls)
  end)
end)
