# WildSpark

> **[Download WildSpark 2.2.40 - Latest Stable](https://github.com/uncle-bone/Wildspark/releases/download/v2.2.40/WildSpark-2.2.40.zip)**

**Current stable release: 2.2.40 for WoW Forever 1.60.1.** The installable ZIP contains one `WildSpark` addon folder. QuestDB, the latest QuestieDB Forever data, and WildInfo's quest-drop datasets are embedded and load automatically with WildSpark.

WildSpark is a modular WoW Forever utility suite for gathering highlights, quest-drop tooltips, buffs, creature leash tracking, WildFire camping, auctions, group finding, and layer hopping. Its major modules have dedicated settings tabs, and can be enabled or disabled independently.

## What's new in 2.2.40

- Remove WildFishing's post-loot reminder because WoW does not expose the bobber-bite event to addons.

- Embed QuestDB and QuestieDB v1.1.1 Forever data inside WildSpark's own folder; install and enable only WildSpark.
- Expand WildInfo tooltips across known quests, including objective items even when the quest is not in your log.
- Combine repeated items into one tooltip row, cap the visible list at eight unique drops, and provide separate default-on switches for quest and ordinary drops.
- Combine QuestionableDrops' quest-starter database, QuestDropRates' static item rates, QuestDB NPC drop rates, and the current QuestieDB quest/item links. Unknown rates remain labeled as unknown.

## What's new in 2.2.29

- Fix duplicate minimap profession rows, recolor the node name by gather-skill difficulty, and scan native WorldCursor tooltips after Blizzard and EllesmereUI finish building them.
- Include Classic reference respawn ranges for 7,000+ ordinary NPCs and rares, with local and peer observations taking precedence. Classic references are labeled unverified for WoW Forever; a monthly workflow refreshes the source table.
- Mark WildGroups listings with a green check after you ask to join, matching the newer upstream behavior.

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
- Temporarily remove the rare-only reference table; local respawn timing continues to be learned for NPCs you encounter.

## What's new in 2.2.3

- Originally bundled RareScanner's 75-entry respawn reference table in WildInfo; it was later removed and is restored in 2.2.29.

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
- Use **WildInfo** to see known quest-starter and quest-objective item drop chances, plus locally or peer-learned NPC respawn estimates, when mousing over creatures. Timer sharing uses the hidden Camping Kit addon channel, not visible world-chat messages.
- Use **WildMaps** from its own icon tab in the WildSpark pane to open Forever dungeon maps. The map shows a reported room name where available; player positioning is approximate and often unavailable inside instances. See [WildMaps details](Wildspark/Modules/WildMaps/README.md).
- Use the separate **HiddenMaps** companion addon for dungeon and approach maps. It provides static maps, floor/wing controls, and boss/entrance markers; player location is best-effort on supported approaches, and most dungeon interiors do not expose live tracking. See [Dungeon Navigation](docs/DUNGEON-NAVIGATION.md) for installation, coverage, attribution, and limits.
- Adjust Blizzard group-loot position, scale, and spacing from WildSpark's Wild Loot Rolls tab.
- Open settings with `/wildspark` or `/ws`.

The main WildSpark minimap button is visible by default. Separate WildBuffs and WildFire buttons are hidden by default.

## Layer ID note

On WoW Forever, WildLayer reads the `zoneUID` field from nearby creature or vehicle GUIDs and shows the observed value as an **ID**, not an official numbered layer. The displayed ID is not used as a destination number for hop requests. If no compatible layer list is available, you can still request any layer.

## Install

Download the ZIP, extract it, and place the included `WildSpark` folder in the Forever client's `Interface/AddOns` directory. Enable WildSpark; its embedded quest databases load with it. Disable standalone copies of integrated modules such as WildBuffs, Camping Kit, WildAuctions, or LFGForever to avoid running duplicate copies.

## Third-party notices

WildSpark retains license and attribution files for its embedded components in their respective folders. The original Camping Kit artwork is excluded; WildFire uses replacement artwork with its own license notice. WildInfo (formerly WildDrops) is included and modified with permission from the Questionable Drops author. WildMaps adapts HiddenMaps 1.2.2 by Lichdom with the author's permission. Its upstream asset notices, credits, and watermarks are retained; see `Wildspark/Modules/WildMaps/ASSET-NOTICES.md`. Its data combines QuestieDB Forever, QuestDropRates, QuestDB, Wowhead, and existing WildSpark rows. Respawn estimates use local and peer-shared observations first, then a clearly labeled Classic respawn reference table for ordinary NPCs and rares. Reference times are not verified for WoW Forever.