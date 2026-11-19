# WildGear module

WildGear is WildSpark's integrated leveling gear planner, built from ForeverLevelingBiS v1.3.5 with the permission provided by its author. It retains item scoring, quest/dungeon/crafted gear lists, equipment comparisons, wishlists, bag upgrade marks, character-panel gear, and stat-weight profiles.

This code runs as part of the WildSpark addon under a private `WildGear` namespace. WildGear does not create a second addon installation. The former standalone database is migrated to `WildGearDB` on first load when available.

Upstream attribution and copyright are retained in `LICENSE`. The author granted permission to use and adapt this source in WildSpark.


## Forever enhancement reference data

WildGear's enhancement guide compiles publicly available Forever game-data reference details: the by-slot permanent enchant list (slot, skill thresholds, materials and formula), and item/consumable level requirements. These facts are presented as an in-addon lookup; they are not claims about drop sources or live server availability.

- Forever Classes, *Every enchant in WoW Forever by gear slot* (178 entries; updated 2026-11-10): https://wowforeverclasses.com/articles/enchants-by-slot-wow-forever
- WoW Forever, *Consumables catalog* (stones/oils and minimum-level listing; build 1.60.1.70790): https://wowforever.kickegg.net/articles/forever-consumables-catalog?lang=en
- SenseOS, *Item Enhancements* (Forever item-level and character-level requirements): https://senseos.gg/wiki/wow-forever/items/item-enhancements/
- Wowhead Forever item and spell pages/guides, for enhancement effects and applicable target-item levels: https://www.wowhead.com/forever/items/consumables/item-enhancements-permanent

The linked guides note that data-side minimum levels, item restrictions, and actual in-game behavior may differ; verify server-side availability and target-item requirements in game.
