# Bot Ops module

## Purpose

The purpose of this module is to be the single place the operator-only Bot Ops panel is
maintained. Two separate Tauri apps ship that panel — `warbandeer-desktop` here, and
`roshne/wow-companion` — and before this module existed each carried its own near-identical copy
of the backend, the wire types and the editable-key whitelist. A change to the bot's env contract
had to be made twice, and the two copies had already started to drift.

It is deliberately **not** a UI component. The two apps render different frameworks (Svelte and
React), so what lives here is everything below the view: the Tauri commands, the SSH plumbing, the
config gate, and the field list. Each app keeps its own thin panel.
