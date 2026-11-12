# WildInfo notices

WildDrops is an Uncle Bone integration of the mob-tooltip feature from Questionable Drops 1.4.0, included and modified with permission from its original author. The integration keeps the tooltip lookup and its required mob, quest, item, and drop-chance database; it omits the standalone browser, nameplate markers, reminders, reports, minimap button, and related UI.

The included database identifies QuestieDB Forever and Wowhead as its sources. See the source comments in Data.lua and ManualData.lua for dataset versions and per-entry notes. WildDrops uses WildSpark's own icon artwork.

WildDrops displays drop chances as percentages when the source data has a numeric chance. Rows without a recorded chance display “drop chance unknown.” Rare recorded drops are shown by default. Quest, race/class, completed-quest, and already-owned-item filters are retained from the supplied addon.


## Respawn reference data

WildInfo includes respawn records derived from RareScanner 12.1.5.6's `NpcSpawnInfoTables.lua`, with permission. The 75 records include fixed intervals, ranges, and event-triggered spawns. They are labeled in game as RareScanner reference data and have not been verified for WoW Forever. Source project: https://www.curseforge.com/wow/addons/rarescanner.
