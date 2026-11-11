# WildSpark

> **[Download WildSpark 2.0.2 — Latest Stable](https://github.com/uncle-bone/Wildspark/releases/download/v2.0.2/WildSpark-2.0.2.zip)**

**Current stable release: 2.0.2 for WoW Forever 1.60.1.** The installable ZIP contains one `WildSpark` addon folder.

WildSpark is a modular WoW Forever utility suite for gathering highlights, buffs, creature leash tracking, WildFire camping, auctions, group finding, and layer hopping. Its major modules have dedicated settings tabs, and can be enabled or disabled independently.

## What's new in 2.0.2

- Bake circular transparency into every tent icon size so the tent artwork stays round even when the runtime mask is unavailable.

## What's new in 2.0.1

- Fix the WildFire tent button artwork so it is clipped and framed within its circular button.

## What's new in 2.0.0

- Update the gathering base with Lueur 1.7 ignore behavior: unnamed objects can be ignored, and removing an ignore takes a second request within 10 seconds.
- Update WildLayer to AutoLayer 1.9.14 behavior, including filtering failed invites only for recent layer requests.
- Prevent WildAuctions startup errors when saved faction history, search favorites, or account data is missing.
- Anchor actual Blizzard group-loot frames instead of the managed container. The Wild Loot Rolls tab now has a draggable preview, saved placement, scale, and roll-spacing controls.
- Preserve the Blizzard Auction House layout fix, the 24-hour WildAuctions post default, WildFire artwork, and the saved layer-hop preference.

## Features

- Highlight nearby herbs, ore, quest objects, chests, and fishing bobbers with configurable glow effects, colors, labels, and visibility rules.
- Show gathering icons on the minimap, learn node names and profession skill requirements, and optionally alternate herb and ore tracking.
- Use the optional minimap ping when a new target is recognized, with separate visual and sound controls.
- Use WildBuffs' rotating or individual spell buttons for supported classes. Buffs are cast only on click or keybind.
- Track creature leashes with timers and combat-event details.
- Use **WildFire** for camping objects, camp effects, food and Well Fed timers, camp tracking, sharing, and map pins.
- Use **WildAuctions** for auction-house tools, including selecting bag items while the auction house is open. It does not post auctions automatically.
- Use **WildGroups** from its own tab in Blizzard's Looking For Group pane.
- Use **WildLayer** from its own WildSpark tab or minimap button to request layer hops. Automatic invites for players requesting your layer are off by default.
- Adjust Blizzard group-loot position, scale, and spacing from WildSpark's Wild Loot Rolls tab.
- Open settings with `/wildspark` or `/ws`.

The main WildSpark minimap button is visible by default. Separate WildBuffs and WildFire buttons are hidden by default.

## Layer ID note

On WoW Forever, WildLayer reads the `zoneUID` field from nearby creature or vehicle GUIDs and shows the observed value as an **ID**, not an official numbered layer. The displayed ID is not used as a destination number for hop requests. If no compatible layer list is available, you can still request any layer.

## Install

Download the ZIP, extract it, and place the included `WildSpark` folder in the Forever client's `Interface/AddOns` directory. Disable standalone copies of integrated modules such as WildBuffs, Camping Kit, WildAuctions, or LFGForever to avoid running duplicate copies.

## Third-party notices

WildSpark retains the license and attribution files for its embedded components in their respective folders. The original Camping Kit artwork is excluded; WildFire uses replacement artwork with its own license notice.
