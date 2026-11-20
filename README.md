# WildSpark

> **[Download WildSpark 2.2.63 - Latest Published Stable](https://github.com/uncle-bone/Wildspark/releases/download/v2.2.63/WildSpark-2.2.63.zip)**

**Latest published stable release: 2.2.63 for WoW Forever 1.60.1.** The package contains one install folder, `WildSpark`. QuestDB, QuestieDB Forever data, and WildInfo's quest-drop datasets are embedded and load automatically with WildSpark.

WildSpark is a modular WoW Forever utility suite for gathering highlights, quest-drop tooltips, buffs, creature leash tracking, the WildMaps minimap lens, WildFire camping, auctions, group finding, and layer hopping.

Install the single `WildSpark` folder from the ZIP into `Interface/AddOns`. WildMaps keeps the integrated Minimap Lens based on the authorized Quantum Dungeon Tools lens source. The dungeon atlas and WildGear are saved on the GitHub archive branch `archive/wildgear-2.2.59` for possible future work.

WildMaps enlarges the current minimap in place and restores its original size, position, shape, tracking and zoom when closed. The separate dungeon atlas has been removed from the active package.

## What's new in 2.2.63

- Add Target and Focus tracking controls to WildMaps and Blizzard's minimap tracking menu; persist each character's choices.
- Include Forever Minimap Target v1.0.1 attribution and its GPL-3.0-or-later license.
- Remove WildGear from the active addon while preserving its source on the GitHub archive branch.
- Restore the WildMaps minimap-lens runtime so its magnifier and UI initialize correctly.
- Allow WildBuffs to consider friendly targets in battlegrounds and arenas even if PvP flags have not synchronized on a PvE realm.
- Keep the WildMaps minimap lens and settings tab; remove the dungeon atlas and tiles from the active package, with the full snapshot archived on GitHub.
- Local package contents checked; live in-game behavior and PvP targeting were not tested.

## What's new in 2.2.54

- Keep the WildSpark leash/proc timer over the game world but beneath standard dialogs such as the Auction House and WoW Settings.
- GitHub Actions package validation passed; the overlay ordering was not tested in a live client.

## What's new in 2.2.53

- Load WildInfo's respawn observer so local and shared spawn estimates can appear in creature tooltips.
- Require the respawn module in the release workflow's package checks to prevent it being omitted from the addon load list again.
- GitHub Actions package validation passed; live in-game timer display was not available for verification.

## What's new in 2.2.52

- Play the battleground queue-pop sound on incoming WildGroups group invites, with Blizzard's normal group-invite sound as a fallback.
- Use numeric sound-kit IDs with `PlaySound` so the invite cue is not silently ignored.
- GitHub Actions package validation passed; live-client audio playback was not available for verification.

## What's new in 2.2.51

- Always show the WildMaps settings tab in the WildSpark menu, even if the module has not initialized yet.
- Hold Ctrl and drag the WildMaps magnifier to reposition it around the minimap; the location is saved and can be reset from the WildMaps page.
- Use a built-in Classic-era spyglass icon for the WildMaps tab and button.
- GitHub Actions builds and checks the release package. Live in-game behavior was not validated.

## What's new in 2.2.50

- Add WildMaps as an integrated settings tab using Quantum Dungeon Tools' Minimap Lens module, adapted for WildSpark.
- Enlarge the current zone minimap in place, with size and opacity settings, drag positioning, a lock option, and safe restoration when closed or leaving the world.
- Keep the previous dungeon-catalog WildMaps implementation and WildPvP source archived in the repository.
- GitHub Actions builds and checks the release package. Live in-game behavior was not validated.

## What's new in 2.2.49

- Remove the previous WildMaps dungeon catalog and WildPvP from the active addon, load manifest, and settings tabs.
- Preserve both original modules' source, artwork, helper scripts, and notices in the repository archive.
- Reduce active addon memory use by not loading those archived modules; the live memory change has not been measured.

## What's new in 2.2.48

- Update WildLayer with AutoLayer 1.9.16's zone-scoped Forever requests and correlated wrong-zone invite handling.
- Update Spy Forever to 1.3.8-forever20. The other three supplied PvP components already match upstream.
- Make WildAuctions, WildMaps, WildGroups notifications, and WildLayer disable immediately without `/reload`.
- Keep WildMaps in its own movable, clipped Zone Map. Zoom stays inside the fixed viewport and cannot shrink below the fitted full-map view.
- Add clearly labeled local drop-rate estimates from looted-corpse observations when the database has no percentage; do not register the restricted combat-log event.
- Restore WildGroups chat notices for party/raid and guild invites, with the LFG ReadyCheck sound on incoming group invites.

## What's new in 2.2.46

- Add the WildMaps settings tab with a selectable dungeon catalog that opens only in its movable Zone Map; Shift+M toggles the Zone Map.
- Fix dragging the compact Zone Map window and stop opening or modifying Blizzard's World Map.
- Combine the four supplied PvP sources into the WildPvP module inside WildSpark, with one WildSpark install folder and its own tab.
- Keep required author credits and license notices in WildPvP's `LICENSES` folder.
- Restore WildGroups chat notices and the Blizzard invite sound for incoming and outgoing party/raid invitations.
- Keep the WildMaps dungeon catalog and the module tab rail inside their scrollable panels.

## What's new in 2.2.45

- Add the missing WildMaps settings tab with a selectable dungeon catalog, map launch controls, compact Zone Map size control, and an enable switch.
- Fix dragging the compact Zone Map window.
- Add a WildPvP tab and master switch as the home for a later PvP integration.

## What's new in 2.2.44

- Restore WildMaps with its full dungeon catalog and artwork.
- Add a movable compact dungeon map with three sizes, mouse wheel and button zoom, map browsing, and floor selection.

## What's new in 2.2.43

- Fix WildGroups crashing when opening the group finder: load the bundled whisper-log file from the addon manifest and verify it is included in the release ZIP.

## What's new in 2.2.39

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
- Adjust Blizzard group-loot position, scale, and spacing from WildSpark's Wild Loot Rolls tab.
- Open settings with `/wildspark` or `/ws`.

The main WildSpark minimap button is visible by default. Separate WildBuffs and WildFire buttons are hidden by default.

## Layer ID note

On WoW Forever, WildLayer reads the `zoneUID` field from nearby creature or vehicle GUIDs and shows the observed value as an **ID**, not an official numbered layer. The displayed ID is not used as a destination number for hop requests. If no compatible layer list is available, you can still request any layer.

## Install

Download the ZIP, extract it, and place the included `WildSpark` folder in the Forever client's `Interface/AddOns` directory. Enable WildSpark; its embedded quest databases load with it. Disable standalone copies of integrated modules such as WildBuffs, Camping Kit, WildAuctions, or LFGForever to avoid running duplicate copies.

## Third-party notices

WildSpark retains license and attribution files for its embedded components in their respective folders. The original Camping Kit artwork is excluded; WildFire uses replacement artwork with its own license notice. WildInfo (formerly WildDrops) is included and modified with permission from the Questionable Drops author. Its data combines QuestieDB Forever, QuestDropRates, QuestDB, Wowhead, and existing WildSpark rows. Respawn estimates use local and peer-shared observations first, then a clearly labeled Classic respawn reference table for ordinary NPCs and rares. Reference times are not verified for WoW Forever.
