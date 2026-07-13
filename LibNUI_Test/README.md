# LibNUI_Test

A **visual test gallery for LibNUI** — for addon developers, not players. It is
LoadOnDemand and only loads when you run:

```
/nui test          -- list available tests
/nui test <key>    -- launch a specific widget test
```

Each test opens a window exercising one LibNUI widget (tables, tabs, buttons,
tooltips, themes, …) so rendering and behavior can be verified in-game.

See `LibNUI/CLAUDE.md` for how to add a test for a new widget.

## Dependencies

- **LibNUI** (pulls in LibNAddOn transitively)
