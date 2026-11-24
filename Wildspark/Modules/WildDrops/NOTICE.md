# WildInfo notices

WildDrops is an Uncle Bone integration of the mob-tooltip feature from Questionable Drops 1.4.0, included and modified with permission from its original author. The integration keeps the tooltip lookup and its required mob, quest, item, and drop-chance database; it omits the standalone browser, nameplate markers, reminders, reports, minimap button, and related UI.

WildInfo combines the QuestionableDrops starter database with QuestieDB Forever v1.1.6, LibQuestDB v0.2.0, QuestDropData 1.0 (from QuestDropRates 1.5.3), and a legacy QuestDropRates v1.3.3 name-based fallback. QuestDropData's per-mob rates come from WoW Forever data and QuestLuck player observations; its quest, mob, and spawn relationships are generated from QuestieDB. QuestDropData and QuestieDB are GPL-3.0; LibQuestDB is MIT; the legacy QuestDropRates table is MIT. License and credit files are kept in the package beside their adapted or embedded sources. QuestDB's generated data is derived from CMaNGOS Classic DB under GPL-3.0. See `QuestDropData/LICENSE.txt`, `QuestDropData/CREDITS.txt`, `QuestDropRates-LICENSE.txt`, `CMANGOS_LICENSE.txt`, and `CMANGOS_COPYRIGHT.txt`.

The generated WildInfo database also identifies Wowhead as a source. See the source comments in Data.lua and ManualData.lua for dataset versions and per-entry notes. WildInfo uses WildSpark's own icon artwork.

WildDrops displays drop chances as percentages when the source data has a numeric chance. Rows without a recorded chance display “drop chance unknown.” Rare recorded drops are shown by default. Quest, race/class, completed-quest, and already-owned-item filters are retained from the supplied addon.



WildInfo also includes a generated Classic respawn reference table for ordinary creatures and rares. For each NPC ID it uses the most common minimum/maximum spawn-time pair in the CMaNGOS Classic world database. These are Classic references only and are not verified for WoW Forever; local and peer observations are kept separately and take precedence. The database is redistributed under its GPL-3.0 terms with its copyright notice; see CMANGOS_LICENSE.txt and CMANGOS_COPYRIGHT.txt. The generator is in the repository's .github/scripts directory and reads the current CMaNGOS SQLite release.
