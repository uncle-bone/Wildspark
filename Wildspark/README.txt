WildSpark 1.5.15
1.5.9: Adds a Forever GUID-based local layer identifier observer to WildLayer and shows the latest observed ID below the minimap. The display marks raw GUID IDs as unverified, keeps NovaWorldBuffs integration optional, and avoids Forever's restricted IsAddOnLoaded query. NovaWorldBuffs 3.49 disables its own layer detector on Forever, so WildLayer can still show an observed ID after targeting or mousing over an NPC; it does not claim that ID is an official layer number.

WildSpark 1.5.8
1.5.8: Adds WildLayer's own minimap button and icon, plus keeps WildSpark panel tabs within the visible panel edge.

WildSpark 1.5.7
1.5.7: Integrates the WTFPL-licensed AutoLayer 1.9.13 as WildLayer, with a WildSpark panel tab, layer request tools, automatic invite toggle (off by default), and delayed safe channel joining. AutoLayerDB remains supported.

WildSpark 1.5.6
1.5.6: Adds separate minimap ping visual and sound toggles, visual strength and sound volume controls. The ping is a brighter, larger two-ring local pulse. Sound volume uses bundled 10% audio levels and does not change game sound settings.

WildSpark 1.5.5
1.5.5: Moves minimap pulse logic into its own Lua file to stay below the client chunk local limit, and adds the /ws shortcut for the WildSpark settings window.

WildSpark 1.5.4
1.5.4: Adds an optional one-shot minimap pulse for each newly recognized tracked object. The pulse is a local visual effect and does not call the protected native ping API.

WildSpark 1.5.3
1.5.3: Shows Herbalism and Mining requirements on recognized minimap node tooltips at every skill level, including when the newer Forever client blocks WildSpark custom pin scanning.

WildSpark 1.5.2
1.5.2: Enables WildAuctions by default on new installations while preserving an existing explicit module disable setting.

WildSpark 1.5.1
1.5.1: Replaces the nonfunctional LFG row enhancer with the full LFGForever 1.3.0 module. Adds a real launcher tab to Blizzard's Looking For Group pane, a WildGroups open button, a working enable switch, and a matching group-finder icon in WildSpark settings.

WildSpark 1.4.9
1.4.9: Fixes WildAuctions settings callbacks used when opening the menu.

1.4.8: Embeds the full WildAuctions auction house module as WildAuctions inside WildSpark.

WildSpark 1.4.8

1.4.7: Fixes WildAuctions bag clicks by validating either supported ItemLocation constructor form and confirming that the returned location points to the exact clicked bag slot before passing it to Blizzard's Sell form. The bag-panel selection approach is informed by the open-source WildAuctions Forever addon (Tyler Hampton; MIT-licensed Forever adaptation), especially WildAuctions/util/info.lua. No auctions are posted automatically.

1.4.5: WildAuctions now follows AuctionMaster's Sell-panel item selection flow: it uses the ItemLocation method constructor, fills the available post quantity, and refreshes Blizzard's post state after selection. It remains a Sell-tab bag selector only, with no AH scanning, price display, or automatic posting. Removed AH scanning, scan buttons, price cache display, and custom AH price tooltips. The bag list includes unbound BoE gear even when Forever IsSellItemValid rejects it; bound items remain excluded. Clicking an item loads it into Blizzard Sell form and never posts an auction.

1.4.3: Adds independent WildBuffs button controls (rotating, individual, both, or neither) and module enable switches for WildBuffs, WildAuctions, and WildFire. Module switches preserve saved settings and caches.

1.4.2: Adds a WildBuffs setting to hide individual spell buttons and keep only the rotating all-buffs button visible. Selecting it keeps the rotating button enabled.

1.3.6-test3: Improves WildAuctions readability and suppresses sell-validation warnings for filtered soulbound items. Adds WildAuctions, an Auction House Sell-tab bag list and its own full listing scan/cache. Click a bag item to load it into Blizzard's sell form; this never posts an auction. Lowest per-unit buyouts and listed quantities are saved per realm and faction and added to item tooltips. If no local price exists, prices exposed by Auctionator or Auctioneer can be shown when installed. A stack total is estimated from the per-item price multiplied by the bag stack size. Full scans obey the client throttle and 15-minute scan cooldown. Also capitalizes the addon folder and display name as WildSpark while retaining all existing SavedVariables names.

1.3.5: Detects Forever build 70862 and later's simulated-cursor minimap tooltip
regression. The addon stops futile node sweeps and explains that native tracking
dots remain available while custom herb/ore replacement icons cannot be placed.

1.3.4: Keeps only the main WildSpark minimap button visible by default.
WildBuffs and WildFire's separate minimap buttons start hidden; existing
saved visibility choices are preserved and can still be changed in settings.
1.3.3: Defers World Map camp-pin removal and acquisition to the next frame,
outside Blizzard's secure map-data-provider refresh callback. This addresses
SetPassThroughButtons action-blocked errors while opening or refreshing the map.
1.3.2: Adds queued notifications for newly learned spells. Available local Forever
API research does not establish a safe addon method for changing action slots,
so WildSpark reminds the player to drag each spell from the spellbook.
1.3.1: Prevents World Map camp-pin refreshes during combat lockdown, avoiding
Blizzard's protected SetPassThroughButtons call. Deferred pins refresh when
combat ends while the World Map is open.
WoW Forever 1.60.1

WildSpark highlights nearby gathering and useful world objects. It is based on
Lueur 1.4.0 by Armytille, with upstream source changes credited in LICENSE.txt.
WildSpark has its own addon name and keeps its established SavedVariables.

Included features
- Glow effects, colors, size, silhouette, preview, and object labels.
- Nearby herb, ore, quest object, chest, and fishing bobber highlighting.
- Herb and ore minimap icons, learned node data, and optional alternating tracking.
- Range, arc, combat/instance, locked-object, and untrained-profession settings.
- Settings panel, minimap button, slash commands, diagnostics, and localization.
- Optional spell helper for spells learned after installation.
- LeashHelperForever integrated into Wildspark, with per-mob timer display,
  combat-event tracking, preview, debug panel, and full settings.
- WildBuffs integrated as its own tab, with class-specific spell choices,
  keybind, settings, stats, and stacked full-size spell buttons.
- WildFire, based on Camping Kit v1.8, integrated as its own tab, including
  the tent, profession objects, camp benefit and Well Fed timers, camp tracking,
  sharing, and map pins.

WildAuctions
- Full WildAuctions Forever auction house source integrated as the WildAuctions module, loaded from WildSpark’s single addon folder and TOC. Its MIT license and upstream attribution are included.
Open the Auction House Sell tab to see unbound items in your bags. Click an
item to load it into Blizzard Sell form. WildAuctions does not scan listings,
show AH price tooltips, or post auctions. Bound items are omitted. The list refreshes when bags change; use Refresh if it is stale.
Bag-to-sell selection is informed by WildAuctions: https://github.com/TylerHampton/aux-forever (MIT-licensed Forever adaptation).

WildBuffs never changes friendly nameplate CVars. Finding nearby strangers by
nameplate depends on friendly player nameplates already being enabled by the
player. It scans only friendly player units.

New-spell helper
The first login records the spells already known, without changing any bars.
After that, newly learned active spells are detected and queued with a chat
notification and a small reminder. Drag each new spell from the spellbook to
an empty action-bar slot. The Forever client API findings available for this
build do not verify a safe addon-driven placement method, so Wildspark does not
pick up spells or change action slots. The reminder can be moved with Shift-drag.
Toggle the helper under Settings > General > Notify me about new spells.
WildBuffs
Open /wildspark and select the WildBuffs tab for button visibility, minimap icon,
dungeon, combat, and glow settings. The minimap icon is hidden by default; turn on
Show minimap icon in this tab if you want it. The full settings window includes class
choices, refresh timing, button size, stats, and keybind.

The rotating all-buffs button picks the next nearby player who needs any enabled
buff. The rotating button and individual spell buttons have separate toggles: use
both, either one alone, or turn both off. The same WildBuffs tab includes an
independent module enable switch. WildAuctions and WildFire have enable
switches in their own module tabs; disabling them preserves their saved data. Each spell button shows its icon, the next player's
name, a pulsing glow, and +N for additional nearby players who need that same
spell. Clicking a spell button buffs the named player. Shift-drag a visible
button to move the group. The default and reset position is screen center.
WildBuffs casts only when you press a button or its keybind.

WildFire
Open /wildspark and select the WildFire tab to show or hide the tent, manage
its minimap button (hidden by default), open or close the tent, and reach
WildFire's full settings. Its camp pins on the map remain enabled.
The tent contains camping objects, profession tools, food and drink slots, camp
benefit timers, and nearby camp details. Disable the standalone Camping Kit
addon when using this integrated copy, so the game does not create two tents.

Druids can enable Thorns in the class settings; its separate spell button then
appears alongside Mark of the Wild. Other supported classes are Mage, Paladin,
and Priest. Use /wildbuffs (or /wb) for settings and /wildspark buffs to open the
WildBuffs settings window.

Install
1. Extract the WildSpark folder into World of Warcraft\\_classic_beta_\\Interface\\AddOns.
2. Disable Lueur before enabling WildSpark; both addons manage some game CVars.
3. Disable the older separate buff-helper addon and standalone Camping Kit while
   using the integrated copies.
4. Reload the UI and enable WildSpark in the AddOns list if needed.

Commands
/wildspark             Open or close settings
/wildspark help        Show commands
/wildspark status      Show detected target and CVar status
/wildspark on|off      Enable or disable Wildspark
/wildspark preview     Open or close the effect preview
/wildspark leash       Open the integrated leash timer settings
/wildspark leash test  Show a sample mob timer
/wildspark buffs       Open WildBuffs settings
/wildfirekit           Open or close WildFire settings
/wildfire              Open or close WildFire settings
/wildbuffs             Open WildBuffs settings
/wb                   Alias for /wildbuffs
/leash                 Open the leash timer settings
/leash debug           Open its copyable diagnostic report

Leash timer note
The embedded LeashHelperForever source is version 1.0.12 from public GitHub
commit fbd3a5e0616f61189d5fc78a1c8775555f198711. It uses public combat events,
refreshes linked packs on qualifying hits, and pauses timers during recognized
crowd control. The timer estimates chase time since a qualifying action; it is
not a promise that a mob will reset after that many seconds of running. Forever
does not expose the server's exact leash distance or reset state. Disable the
separate LeashHelperForever addon while using Wildspark's integrated timer.

Credits
Made by Uncle Bone.
Bundled components retain their original copyright and license notices in their included license files.

1.5.15: Fixes the Blizzard Auction House window layout, brands the auction module WildAuctions, and credits Uncle Bone in the module UI.
