# WildSpark

> **[Download WildSpark 1.5.6 — Latest Stable](https://github.com/uncle-bone/Wildspark/releases/download/v1.5.6/WildSpark-1.5.6.zip)**

**Current stable release: 1.5.6 for WoW Forever 1.60.1.** The installable ZIP contains one `WildSpark` addon folder.

WildSpark brings nearby resource highlighting, buffs, leash helpers, camping, auction tools, and group finding together under one addon. Each major module has its own settings tab and can be disabled separately.

## Features

- Highlight nearby herbs, ore, quest objects, chests, and fishing bobbers with configurable glow effects, colors, labels, and visibility rules.
- Show gathering icons on the minimap, learn node labels and profession skill requirements, and optionally alternate herb and ore tracking.
- Use the optional minimap ping when a new target is recognized. Version 1.5.6 adds separate visual and sound toggles, visual strength, sound volume, and a larger two-ring pulse.
- Use WildBuffs' rotating or individual spell buttons for supported classes. Buff casts happen only on a click or keybind.
- Track creature leashes with timers and combat-event details.
- Use the integrated **Wildfire Kit** for camping objects, camp effects, food and Well Fed timers, camp tracking, sharing, and map pins.
- Use **WildAuctions** for auction house tools, including selecting bag items from the Auction House interface. It does not post auctions automatically.
- Use **WildGroups** from its own tab in Blizzard's Looking For Group pane.
- Get reminders for newly learned spells. WildSpark does not modify action bars automatically.
- Open settings with `/wildspark` or `/ws`.

The main WildSpark minimap button is visible by default. Separate WildBuffs and Wildfire Kit buttons are hidden by default. Existing SavedVariables, Wildfire Kit branding, and the map-pin combat deferral behavior are preserved.

## Install

Download the ZIP above, extract it, and place the included `WildSpark` folder in the Forever client's `Interface/AddOns` directory. Disable the separate WildBuffs, Camping Kit, WildAuctions, or LFGForever addons if you use their integrated WildSpark versions.

## Verification

The 1.5.6 ZIP structure, version metadata, and included sound assets were checked. The new minimap ping sound and visual options still need in-client verification in WoW Forever.