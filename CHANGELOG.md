# WildSpark Changelog

## 1.4.7 — 2026-11-10

- Fix tracker mouse pass-through when locked and refresh spell/spec data after specialization changes.


## 1.4.6 — 2026-11-10

- Add WildResources, a movable all-class tracker that discovers exposed player powers and learned active spellbook cooldowns at runtime.
- Add per-resource visibility, module enable/disable, cooldown visibility, combat-only visibility, position lock/reset, and scale controls under Options > AddOns > WildResources.
- Integrate ForeverLootRollMover as a background module, preserving its Edit Mode behavior, commands, and SavedVariables.
- Preserve WildSpark's existing modules, SavedVariables, Wildfire Kit branding, minimap-button defaults, and map-pin combat deferral behavior.
- Add a GitHub release workflow that packages the correctly rooted addon folder and checks ZIP contents and TOC version metadata.
- Client limitation: power-name/spec API coverage and the full display still require validation in the WoW Forever 1.60.1 client.
