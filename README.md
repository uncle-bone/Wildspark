# WildSpark

> **[Download WildSpark 2.2.9 — Latest Stable](https://github.com/uncle-bone/Wildspark/releases/download/v2.2.9/WildSpark-2.2.9.zip)**

**Current stable release: 2.2.9 for WoW Forever 1.60.1.** The installable ZIP contains one `WildSpark` addon folder.

WildSpark is a modular WoW Forever utility suite for gathering highlights, quest-drop tooltips, buffs, creature leash tracking, WildFire camping, auctions, group finding, and layer hopping. Its major modules have dedicated settings tabs, and can be enabled or disabled independently.

## What's new in 2.2.9

- Keep WildLayer's hidden coordination channels after the channels you already use, so they no longer take slots ahead of General, Trade, or Global.

## What's new in 2.2.8

- Add a default-on WildBuffs option to pause and stop target scanning in cities and inns (rested areas), reducing its background work where buffing is less useful.

## What's new in 2.2.7

- Share confirmed WildInfo respawn observations with other WildSpark clients through Camping Kit's hidden addon-message channel. Shared observations are saved, included in estimates, identified in tooltips, and refresh open tooltips.

## What's new in 2.2.6

- Wrap WildInfo respawn text inside creature tooltips and shorten the initial learning message.

## What's new in 2.2.5

- Use `/wa` for WildAuctions slash commands and update its help text and settings hints.

## What's new in 2.2.4

- Fix WildInfo local respawn learning for repeated identical NPCs: retain multiple pending deaths per NPC type and pair later nameplate appearances instead of discarding kills when several are visible.
- Also observe confirmed deaths from existing unit-health/flag events when available, and show a clear collection status when no local timer has been learned yet.
- Remove RareScanner's rare-only reference table; respawn timing is learned locally for the NPCs you actually encounter.

## What's new in 2.2.3

- Bundle RareScanner's 75-entry respawn reference table in WildInfo; matching creature tooltips show fixed/ranged reference values or event-spawn notes, clearly labeled as not verified for Forever.
- Keep locally learned respawn estimates as a fallback for NPCs absent from the reference table.

## What's new in 2.2.2

- Route WildInfo respawn tracking through WildSpark's existing events, fixing the ADDON_ACTION_FORBIDDEN error.
- Rename the quest-drop tooltip module to **WildInfo** while retaining existing settings.
- Add optional local NPC respawn estimates to creature tooltips. Estimates learn from observed deaths and later nameplate appearances and are approximate.
- Keep the auction-house session open when switching from WildAuctions to Blizzard UI.
- Normalize WildBuffs' bundled minimap icon path to match the `WildSpark` addon folder casing.

## Features

- Highlight nearby herbs, ore, quest objects, chests, and fishing bobbers with configurable glow effects, colors, labels, and visibility rules.
- Show gathering icons on the minimap, learn node names and profession skill requirements, and optionally alternate herb and ore tracking.
- Use the optional minimap ping when a new target is recognized, with separate visual and sound controls.
- Use WildBuffs' rotating or individual spell buttons for supported classes. Buffs are cast only on click or keybind.
- Track creature leashes with timers and combat-event details.
- Use **WildFire** for camping objects, camp effects, food and Well Fed timers, camp tracking, sharing, and map pins.
- Use **WildAuctions** for auction-house tools, including selecting bag items while the auction house is open. It does not post auctions automatically.
- Use **WildGroups** from its own tab in Blizzard's Looking For Group pane.
- Use **WildLayer** from its own WildSpark tab or minimap button to request layer hops. Automatic invites for people requesting your layer are off by default.
- Use **WildInfo** to see quest-starting item drop chances and locally or peer-learned NPC respawn estimates when mousing over creatures. Timer sharing uses the hidden Camping Kit addon channel, not visible world-chat messages.
- Adjust Blizzard group-loot position, scale, and spacing from WildSpark's Wild Loot Rolls tab.
- Open settings with `/wildspark` or `/ws`.

The main WildSpark minimap button is visible by default. Separate WildBuffs and WildFire buttons are hidden by default.

## Layer ID note

On WoW Forever, WildLayer reads the `zoneUID` field from nearby creature or vehicle GUIDs and shows the observed value as an **ID**, not an official numbered layer. The displayed ID is not used as a destination number for hop requests. If no compatible layer list is available, you can still request any layer.

## Install

Download the ZIP, extract it, and place the included `WildSpark` folder in the Forever client's `Interface/AddOns` directory. Disable standalone copies of integrated modules such as WildBuffs, Camping Kit, WildAuctions, or LFGForever to avoid running duplicate copies.

## Third-party notices

WildSpark retains the license and attribution files for its embedded components in their respective folders. The original Camping Kit artwork is excluded; WildFire uses replacement artwork with its own license notice. WildInfo (formerly WildDrops) is included and modified with permission from the original Questionable Drops author; its quest database credits QuestieDB Forever and Wowhead. Respawn estimates are learned locally; WildSpark does not bundle rare-only timer data.
