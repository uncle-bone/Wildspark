# Changelog

## 1.3.0

- New: a "Report a bug" button at the top right of the LFG Forever window, under the title. Click it to get the Discord link, the same one the Discord button in the settings opens. Translated in every language pack.

## 1.2.0

- Fixed: scrolling up in the Whispers tab to read older whispers no longer jumps back to the newest one when a whisper arrives. Scroll back down to the bottom and the list follows new whispers again. Switching to the Filters tab, or closing LFG Forever, brings the list back to the newest whisper.

## 1.1.0

- New: hover the Groups or Players header in the list to see what a click does: "Collapse the Groups list" or "Collapse the Players list" while the list is open, "Expand the Groups list" or "Expand the Players list" while it is collapsed. Translated in every language pack.
- Changed: on a player's row, the level now sits right after the name, without the gap there was before.
- Changed: long names in the list are cut a little shorter, as Blizzard's own Group Finder now does, and shorter still on a listing that shows the newcomer icon, so the icon keeps its room.

## 0.33.0 (beta)

- New: a Simplified Chinese language pack, "LFG Forever - Language Pack Chinese Simplified". It works like the other language packs: install and enable it, and LFG Forever is in Simplified Chinese after the next reload.
- New: the settings page now says where to get LFG Forever in other languages: each language is a separate addon on CurseForge, for example "LFG Forever - Language Pack Korean". You'll find it under Miscellaneous, above the Discord link.

## 0.32.0 (beta)

- New: a Traditional Chinese language pack, "LFG Forever - Language Pack Chinese Traditional". It works like the other language packs: install and enable it, and LFG Forever is in Traditional Chinese after the next reload.

## 0.31.0 (beta)

- New: a French language pack, "LFG Forever - Language Pack French". It works like the other language packs: install and enable it, and LFG Forever is in French after the next reload.

## 0.30.0 (beta)

- New: a German language pack, "LFG Forever - Language Pack German". It works like the other language packs: install and enable it, and LFG Forever is in German after the next reload.

## 0.29.0 (beta)

- New: a class filter for groups, in the last spot of "Find groups by role". Pick classes in its dropdown, for example Mage and Warlock, and click Search: groups that already have a player of one of those classes are hidden. Players listed on their own and your own group are not affected. It is saved with your filters and in My filters, and Reset filters clears it.
- Changed: the Languages dropdown's first two rows now read "Select all" and "Unselect all", the same words as the class filter's links. They said "Check All" and "Uncheck All" before.

## 0.28.0 (beta)

- Fixed: after you opened LFG Forever's settings, changing any key in Blizzard's Keybindings during combat was blocked ("Interface action failed because of an AddOn") until you reloaded.
- Fixed: after you typed in the Options search box, changing any key in Blizzard's Keybindings during combat was blocked until you reloaded.
- Changed: "Open LFG Forever" in LFG Forever's settings is now a Keybindings button. It opens Blizzard's Keybindings page at the LFG Forever section, where you set the key.
- Changed: the Options search box no longer finds LFG Forever's "Found a bug or have an idea?", "Window position and size" and "Open LFG Forever" rows by their names. This keeps LFG Forever's text out of Blizzard's settings search, which could cause the same kind of error.

## 0.27.0 (beta)

- New: a "Sort players by" setting, under Search in LFG Forever's settings (Options > AddOns > LFG Forever), chooses the order of the Players list: newest listings first (as before), oldest listings first, highest level, lowest level, or by class. Your own listing still comes first, then guild members and friends. The Groups list stays newest first.

## 0.26.0 (beta)

- New: a Spanish language pack, "LFG Forever - Language Pack Spanish", in Spanish as written in Spain. It works like the Ukrainian and Czech ones: install and enable it, and LFG Forever is in Spanish after the next reload.
- New: a Korean language pack, "LFG Forever - Language Pack Korean". It works the same way: install and enable it, and LFG Forever is in Korean after the next reload.
- Fixed: the players list's "No groups found" notice, and the Whispers tab's "No whispers yet", wrap onto a second line when a language pack makes them longer, instead of running out of the list.

## 0.25.0 (beta)

- New: a Languages filter in the Filters tab's Miscellaneous section, beside Playstyle. Until now LFG Forever, like Blizzard's Group Finder, only ever found groups and players in your game's language. Tick more languages, or Check All, and click Search to find theirs too; your own language is always included. It is saved with your filters and in My filters.
- Changed: if a search gets no answer within 15 seconds, LFG Forever gives up so you can search again, and the list says "Search Failed. Please wait a moment and try again." It now says this too when the game reports a failed search; it said "No groups found" before.

## 0.24.0 (beta)

- Fixed: the minimap button no longer misplaces itself if its saved position is corrupt.
- Changed: internal cleanup; nothing else should look or behave differently.

## 0.23.0 (beta)

- Changed: players and groups are listed newest first, so the list stays steady between searches. Your own listing still comes first, then guildmates and friends.
- Fixed: a group you report from the players list now disappears from it, as it does in Blizzard's Group Finder.

## 0.22.0 (beta)

- New: a Playstyle filter in the Filters tab's Miscellaneous section. Tick the playstyles you want (Learning, Relaxed, Competitive, Carry Offered) and click Search: players and groups with other playstyles are hidden. It says All while every playstyle (or none) is ticked, and is saved with your filters and in My filters. Listings with no playstyle are always shown.
- New: click a filter section's title to collapse or expand it; the + or - at its left shows which. A collapsed section's filters still apply, and LFG Forever remembers which sections you collapsed. Defaults (Options > AddOns > LFG Forever) expands them all again.
- New: a collapsed filter section shows a warning icon beside its title when its filters are changed from the defaults; they still apply to your search. Hover it for details.
- Changed: the window is a little taller to make room for a new Miscellaneous section on the Filters tab, where upcoming filters will go. If you had made the window taller than before but not as tall as the new size, it opens at the new height and keeps your width.
- Changed: the tooltips that say why Role Check, Save new filter or the save popup's Okay is unavailable now have a title, matching LFG Forever's other tooltips.

## 0.21.0 (beta)

- Fixed: a rare Lua error in the activity dropdown when the game stopped describing the one activity you had ticked. The dropdown now shows "1 activity selected" instead.
- Fixed: a rare Lua error when hovering a players-list row whose leader the game had not named yet.
- Changed: "Mark friends" is no longer experimental: it is confirmed working, and it is now on for new installs. If you already had it off, tick it under Options > AddOns > LFG Forever > Search to see your WoW and Battle.net friends marked.

## 0.20.0 (beta)

- New: %role% in the Ask to Join message becomes the roles you selected in Blizzard's Group Finder: "tank", "heal", "dps", or "tank or dps" for two. Add it to your message yourself, for example "Hi! I am a %talents% %role% %class%, %level%. Inv please"; the default message is unchanged.
- New: a "?" beside each Message box in the settings lists the placeholders that message understands.
- New: a key binding, "Open LFG Forever", opens and closes the window like /lfg. Set it in Options > Keybindings, in the LFG Forever section, or in LFG Forever's own settings (Options > AddOns > LFG Forever > Miscellaneous). No key is bound until you pick one.

## 0.19.0 (beta)

- New: a gear at the right end of the search row, after Role Check, opens LFG Forever's settings (Options > AddOns > LFG Forever). In combat the game does not allow it, and a chat line says so.
- New: the Search button shows "Search Again" when you hover it, as the search button on Blizzard's Group Finder does.

## 0.18.0 (beta)

- The Czech language pack is written without diacritics, so every word shows (some letters were drawn as boxes).

## 0.17.0 (beta)

- New: a Czech language pack, "LFG Forever - Language Pack Czech". It works like the Ukrainian one: install and enable it, and LFG Forever is in Czech after the next reload.

## 0.16.0 (beta)

- New: LFG Forever can be translated by language packs, separate addons such as "LFG Forever - Language Pack Ukrainian". Install and enable a pack, and LFG Forever shows its words after the next reload; disable it to go back to English. If more than one pack is enabled, the first one in the AddOns list is used. Nothing changes without a pack: every word is the same as before. Whispers sent to other players stay in English in every language, and dungeon, zone and category names stay in your game's language.
- Changed: the filters column gets wider by itself if a language pack's words would not fit. In English it is the same as before.

## 0.15.0 (beta)

- New: the LFG Forever window can be made bigger. Drag the grip in its bottom-right corner; the top-left corner stays where it is. The players list gets all the extra room, and the filters keep their width. The window cannot be made smaller than it opens by default. The size is remembered for all your characters. On a smaller screen, a big window is scaled down to fit. Reset window position and size in the settings (Options > AddOns > LFG Forever) puts it back.
- Changed: the invite whisper now names a dungeon even when you have no listing. With no listing, %dungeon% becomes the activities ticked in the activity filter, all of them, as with a listing ("Deadmines", "Deadmines or Wailing Caverns"). You don't need to click Search first. With nothing ticked, the player is only invited, as before. Your listing, when you have one, still comes first, whatever is ticked. As before, only a player in no group or a group leader whispers; an assistant only invites.

## 0.14.0 (beta)

- Changed: the activity dropdown lists dungeons in the order of Blizzard's own Listing tab (where you post a group), rather than its Browse tab's. Within each group, higher-level dungeons now come first: by the game's own order, then the highest level cap (dungeons with no cap first), then the highest minimum level, then by name. The groups themselves keep their order, and so does the invite whisper's list of dungeons.
- Changed: LFG Forever no longer copies the Ask to Join message you had before 0.11.0 (when it was shared by all your characters) to a character that has none yet. Characters that already logged in on 0.11.0 or later keep their own message; a character logging in for the first time now starts with the default message. The old shared message is removed from your saved settings.

## 0.13.0 (beta)

- New: the players list shows each listing's playstyle (Learning, Relaxed, Competitive or Carry Offered), which Blizzard's Group Finder now asks for when you post a listing. It is the last word of the activity line, in the same colour: "Deadmines | Westfall | Relaxed" for a player, "Deadmines | Relaxed" for a group. Listings without a playstyle show none. In dungeons and raids it is not shown, because the game hides it from addons there.
- Changed: a player's zone in the players list now takes only the room its name needs, so the playstyle follows right after it.

## 0.12.0 (beta)

- New: inviting a player with the invite (+) button in the players list also whispers them "Hey! Want to join %dungeon%?". %dungeon% becomes the dungeon of your own listing, or all of them if it has several ("Deadmines, Wailing Caverns or Shadowfang Keep"), with the names the list shows. Turn it off, or write your own message, with "Auto-whisper on Invite" in the settings, under the Ask to Join message. The message is saved for each character. Nothing is whispered (the player is only invited) when you have no listing, when you are in a group you don't lead, when the message is empty, or when the whisper would be longer than 255 characters (a line in chat says so). The Invite link in the Whispers tab and Blizzard's right-click "Group Invite" only invite, as before.

## 0.11.0 (beta)

- New: My filters. Click "Save new filter" on the Filters tab, next to "Reset filters", to keep the role, class and group checkboxes and the player level range under a name of up to 20 letters. The "My filters" dropdown (the words and the small arrow after them) lists your saved filters; click a name to put its filters back (then click Search to use them). Hover a name and click the X to delete it. You can keep up to 20, and they are shared by all your characters. Blizzard's "Defaults" button deletes them.
- New: LFG Forever remembers your filters. The role, class and group checkboxes and the player level range are saved when you click Search or Reset filters or pick one of My filters, and are back when you next log in or reload, on all your characters. The players list uses them from the start. A change you don't search with is kept while you play, but not after a reload. Category and activity are not saved. Blizzard's "Defaults" button on the LFG Forever settings page resets them too.
- Changed: the Ask to Join message is now saved for each character, so every character can have its own. All other settings are still shared by all your characters. The first time each character logs in, it starts with the message you had before (or the default message, if you had none). Blizzard's "Defaults" button resets it to the default message.

## 0.10.0 (beta)

- New: filter players by level. "Find players by role" is now "Find players by role and level", with a "Player level range" row holding a min and a max box. Leave min empty for no lower limit and max empty for no upper limit. It applies when you click Search, like the other filters, and only to players, not groups. If min is above max, Search lowers min to max. Reset filters empties both boxes.
- Changed: clicking the LFG Forever tab on Blizzard's Group Finder now closes Blizzard's Group Finder as it opens LFG Forever. In combat Blizzard does not let addons close its windows, so there both stay open. /lfg, the minimap button and the AddOns menu entry don't close it.
- Fixed: the minimap button now follows a square minimap, running along its edge like other addons' minimap buttons. This works with EnhanceQoL, Leatrix Plus and other minimap addons that report their shape.
- Removed: the line "You can configure the addon and report bugs in LFG Forever settings" under the search row, to make room for the new row. The settings page is still a right-click on the minimap button or on LFG Forever in the AddOns menu by the minimap, or in Options > AddOns.

## 0.9.0 (beta)

- New: %talents% in the Ask to Join message becomes your main talent tree, e.g. "Hi! I am a %talents% %class%, %level%." sends "Hi! I am a prot warrior, 60.". It is the tree you have spent the most points in, in your active spec (the leftmost one on a tie), read when you open the LFG Forever window, and it is left empty when you have no points spent. The default message now uses it (see below).
- Changed: the default Ask to Join message is now "Hi! I am a %talents% %class%, %level%. Inv please", e.g. "Hi! I am a prot warrior, 60. Inv please". If you never changed your message, you get the new one; a message you wrote yourself is kept.
- Changed: %class% in the Ask to Join message is now always the English class name in lower case ("warrior", "druid", ...), whatever language your game is in. It used to be your game's translated name with a capital letter ("Warrior", "Krieger").
- Changed: the "Show All Level Ranges" setting is now "Show all level activities", and its tooltip says it shows activities (not groups) for every dungeon and raid.
- Changed: the "Show activity level ranges" setting is now called "Show suggested level ranges".

## 0.8.0 (beta)

- New: the LFG Forever window can be moved. Drag it by its title bar, and it opens where you left it next time, on every character. The first time, it opens centred across the screen, with its top level with Blizzard's Group Finder.
- New: "Reset" beside "Window position" in the settings moves the window back to where it first opened. Blizzard's "Defaults" button at the bottom of the settings does the same.
- Changed: LFG Forever now opens and closes in combat too.
- The settings page can't be opened in combat: the settings link, and right-clicking the minimap button or the AddOns menu entry, now say so instead of causing an "action blocked" error.
- Changed: LFG Forever no longer closes other windows when it opens, and they no longer close it. Blizzard's Group Finder, your character sheet and other addons' windows can be open at the same time.
- The window stays on the screen, including its side tabs, and still shrinks to fit a small screen.
- Changed: the settings page has two sections now. "Mark guild members" and "Mark friends" moved into "Search", and "Show minimap button", "Report a bug" and the new window reset are together under "Miscellaneous".
- Changed: the default Ask to Join message now ends "Inv please." instead of "Want to join group.". If you never changed your message, you get the new one; a message you wrote yourself is kept.

## 0.7.0 (beta)

- New: a "Role Check" button at the right end of the Search row, on both tabs, a little smaller than Search. It asks everyone in your group to confirm their role, like the one in Blizzard's Group Finder. Only a group leader or assistant can use it, and after a click it rests for 2 seconds.
- New: the activity dropdown shows each dungeon's and raid's suggested level range after its name, for example "Deadmines (17 - 24)", with the same numbers as the level column in Blizzard's Group Finder. You can turn this off with "Show activity level ranges" in the Search section of the settings.
- Changed: "Reset filters" is now a link at the right end of the "Find groups by role" heading. It resets only the checkboxes; your category and activity stay as they are.
- Changed: the Whispers tab has a "Messages from players" heading, with a "Clear chat" link at its right end, in the same place as "Reset filters" on the Filters tab.

## 0.6.0 (beta)

- New: a minimap button. Left-click opens or closes LFG Forever, right-click opens its settings. Drag it to move it around the minimap; it remembers where you put it. You can hide it with "Show minimap button" in the new "Minimap" section of the settings.
- New: LFG Forever is in the AddOns menu by the minimap (the addon compartment), with the same left- and right-click actions as the button. It stays there even when the minimap button is hidden.
- Fixed: LFG Forever showed only dungeons and raids suggested for your level, both in its dropdowns and in its searches, so groups for other levels never appeared. There is now a "Show All Level Ranges" setting under Options → AddOns → LFG Forever, in the new "Search" section. Tick it to see groups for every level. It is off by default, like Blizzard's.
- The setting is separate from "Show All Level Ranges" in Blizzard's Group Finder: changing one does not change the other.

## 0.5.0 (beta)

- Changed: Location in the Whispers tab now opens the chat box with `/who "Name"` typed in; press Enter to look the player up. It no longer opens Blizzard's Who List, and it keeps the LFG Forever window open and works in combat.
- Fixed: after using Location, Blizzard's Group Finder could not be opened in combat ("Interface action failed because of an AddOn").
- Fixed: in the players list, a player's or a group leader's name sometimes showed blank until you searched again. It now fills in as soon as the game sends it. A listing withdrawn while you are looking at it is also greyed out straight away.
- Fixed: in a dungeon or in combat, the players list and the Whispers tab could raise a Lua error ("attempt to compare a secret number value") while drawing a player's name.
- Improved: while the LFG Forever window is closed, it no longer redraws the players list for searches and updates it cannot show; the list is brought up to date when you open the window.
- Fixed: the Report a bug popup could cut the Discord link short if another popup with a short text limit (for example a rename box) had been open before it. The popup now sets its own limit, long enough for the whole link.

## 0.4.0 (beta)

- Guild members are marked with a guild icon, in the players list and the Whispers tab. In the players list they are also moved to the top. For a group, the icon means its leader is in your guild. Hover the icon to see what it means.
- Friends (WoW and Battle.net) can be marked the same way, with a friends icon. This is experimental and off by default: the friend list is disabled in the Forever beta, so it has not been tested yet.
- New settings under Options → AddOns → LFG Forever, in the "Guild and friends" section: "Mark guild members" (on by default) and "Mark friends (Experimental)" (off by default). When one is off, LFG Forever does not look up that list at all. A change applies from your next search, and to new whispers.

## 0.3.0 (beta)

- New settings page under Options → AddOns → LFG Forever. Its first setting, "Whisper log size" (50–500, default 200), sets how many received whispers the Whispers tab keeps; the oldest are removed first.
- New setting "Auto-whisper on Ask to Join" (on by default), with the message it sends. Edit the message on the settings page; %class% and %level% are filled in with your class and level. Turn it off, or empty the message, and Ask to Join opens a whisper for you to type in instead, with no cooldown.
- The settings page has a "Report a bug" section. Its Discord button shows the invite link, ready to copy.
- The beta notice under the search filters is replaced by a link to the settings page: "You can configure the addon and report bugs in LFG Forever settings".
- The Listing, Browse and Who List tabs on the LFG Forever window use Blizzard's new Group Finder tab icons, so they match Blizzard's window again.

## 0.2.0 (beta)

- The Whispers tab now lists only whispers you receive. Whispers you send, and the << / >> markers, are gone.
- Player listings now show the zone the player is in, after their activity (for example, "Deadmines | Westfall").
- Whispers you receive now have a "Remove | Location | Invite" line under them, aligned to the right. Remove takes that whisper out of the list. Location opens the Who List with the player's name already in the search box; press Enter or Search to see where they are. Invite replaces the plus button on whisper rows.

## 0.1.0 (beta)

First public release.

- `/lfg` opens the group finder window. There is also a new tab on Blizzard's Group Finder that opens it.
- Filter players by role (tank, healer, damage) and by class.
- Filter groups by what they still need, or by what they already have.
- Groups and players are shown in separate lists that you can collapse. Collapsed lists stay collapsed when you search again.
- One-click invite for solo players, and one-click "ask to join" whisper to a group's leader.
- Whispers tab: every whisper sent and received this session, with a one-click invite. The tab lights up when a new whisper arrives.
- Right-click menus and listing tooltips come from Blizzard's own UI.
