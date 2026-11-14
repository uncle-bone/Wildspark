# WildInfo notices

WildDrops is an Uncle Bone integration of the mob-tooltip feature from Questionable Drops 1.4.0, included and modified with permission from its original author. The integration keeps the tooltip lookup and its required mob, quest, item, and drop-chance database; it omits the standalone browser, nameplate markers, reminders, reports, minimap button, and related UI.

The included database identifies QuestieDB Forever and Wowhead as its sources. See the source comments in Data.lua and ManualData.lua for dataset versions and per-entry notes. WildDrops uses WildSpark's own icon artwork.

WildDrops displays drop chances as percentages when the source data has a numeric chance. Rows without a recorded chance display “drop chance unknown.” Rare recorded drops are shown by default. Quest, race/class, completed-quest, and already-owned-item filters are retained from the supplied addon.



WildInfo also includes a generated Classic respawn reference table for ordinary creatures and rares. For each NPC ID it uses the most common minimum/maximum spawn-time pair in the CMaNGOS Classic world database. These are Classic references only and are not verified for WoW Forever; local and peer observations are kept separately and take precedence. The database is redistributed under its GPL-3.0 terms with its copyright notice; see CMANGOS_LICENSE.txt and CMANGOS_COPYRIGHT.txt. The generator is in the repository's .github/scripts directory and reads the current CMaNGOS SQLite release.
