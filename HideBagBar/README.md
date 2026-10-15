# HideBagBar

Hides the bag bar: the backpack button, the four bag slots, the reagent bag slot, and
the expand/collapse toggle. On WoW Forever it also hides the key ring button. Nothing
else — no settings, no database, no dependencies.

Your bags still work exactly as before (`B`, individual bag keybinds, etc.); only the
buttons are hidden. To get the bag bar back, disable the addon and `/reload`.

The key ring button exists only on Forever's bag bar; on Retail there is nothing to hide
and the addon does what it always did. Hiding the key ring is an assumption, pending roshne's
confirmation.

## Dependencies

None — HideBagBar uses only the base WoW API (no LibNAddOn, no LibNUI).
