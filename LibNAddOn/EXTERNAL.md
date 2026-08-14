[**Part of Nazuraki's WoW AddOn Suite**](https://github.com/nazumods/wow) — free & open source on GitHub.

![LibNAddOn](https://raw.githubusercontent.com/nazumods/wow/main/LibNAddOn/logo.jpg)

# LibNAddOn

**A shared library, not a standalone addon.** LibNAddOn is the bootstrapping foundation the rest of Nazuraki's WoW AddOn Suite is built on — you don't need to install it by hand; the addons that require it list it as a dependency and your addon manager pulls it in automatically.

It gives every addon in the suite a common backbone: one-call addon setup, event handling, a saved-variable database with versioned migrations, settings panels, slash-command registration, an in-game changelog viewer, and a large kit of Lua helpers (colours, coin formatting, action-bar reading, list/map/set utilities, and a publish/subscribe signal type).

It also registers a few suite-wide convenience commands that are always available: `/rl` (reload UI), `/fs` (toggle the frame stack), and `/etc` (open Edit Mode).

## Developers

Full API documentation lives in the [README on GitHub](https://github.com/nazumods/wow/tree/main/LibNAddOn). The whole suite is open source — issues and pull requests welcome.

## Found a bug / Have a suggestion?

LibNAddOn is developed in the open as part of **[Nazuraki's WoW AddOn Suite](https://github.com/nazumods/wow)**. Please report bugs and request features on the **[GitHub issue tracker](https://github.com/nazumods/wow/issues)**.
