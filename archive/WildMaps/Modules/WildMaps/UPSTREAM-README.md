# HiddenMaps — WoW Forever

Version: **1.2.2-dev3**. Client Interface: **16001**.

Private compatibility test build for HiddenMaps alone, with Leatrix Maps,
with Questie, or with both. A single controller temporarily suppresses native
map content, coordinate readouts and independently managed native tooltips
while HiddenMaps is shown. Explicit external navigation returns to the native
map until the World Map is closed. Foreign providers, settings and minimap pins
remain owned by their original addons. Real client acceptance is still required;
Questie's pre-existing waypoint-line GlowUpdate error is outside this patch.

This build also tests OpenMap v0.7.5-beta and v0.8.0-beta for WoW Forever, alone or together
with Questie and Leatrix Maps. OpenMap artwork, icons and coordinate labels are
leased only while a HiddenMap is displayed. Wheel/drag input stays with the
HiddenMaps shield; explicit parent navigation yields before forwarding, so
OpenMap does not zoom HiddenMaps artwork or move its entrance markers. The
OpenMap adapter validates these two source signatures; other versions are untested.
The OpenMap vertical tab/favourites rail is also leased while HiddenMaps is shown,
with its latest visibility request restored on yield, close or deactivation.

The 1.2.0 feature milestone adds the four calibrated Blackrock Mountain markers:
Blackrock Depths, the shared Blackrock Spire entrance, and the outdoor exits to
Searing Gorge and Burning Steppes. The two outdoor exits use the approved exit
icon. Final in-game acceptance and release regression testing remain pending.

HiddenMaps shows local approach and dungeon maps inside the World Map. Maps
appear automatically in supported areas; open the World Map as usual.

To browse Blizzard's maps, right-click the artwork or choose a higher-level
World Map breadcrumb. After native navigation reaches a parent or ancestor map,
HiddenMaps stays hidden until you close the World Map. Reopen it to restore the
applicable HiddenMap. Automatic detection and manual map selections continue
normally; this temporary display bypass does not change saved settings.

Live player position and facing are supported on seven approach maps:
Wailing Caverns, Razorfen Downs, Scarlet Monastery Grounds, Deadmines,
Blackfathom Deeps, Gnomeregan, and Uldaman. Their tracking geometry is unchanged.
The player chevron grows proportionally with the fitted approach artwork when
maximized and returns to its normal size on restore. Entrance icons keep their
existing size; Wailing Caverns now includes its calibrated entrance marker.

This development build also enables Maraudon Approach tracking from its exported
WMO placement, including its 1-degree tilt, and adds three calibrated entrance
icons. Maraudon requires valid outdoor Kalimdor `UnitPosition` coordinates with
altitude; there is no alive/dead restriction or 2D fallback. Its corrected artwork
orientation and permanent crop are retained. This addition is ready for in-game
testing; position, facing, ghost movement and the three tooltips await confirmation.

Sunken Temple Approach now uses the supplied Forever WMO 21140 artwork and
placement (FileDataID 7962739), rotated exactly 77.5 degrees counterclockwise
from its previous display. Live position/facing and existing spatial detection
are enabled. Transparent margins are trimmed without cutting visible art.
This is 2D coverage: test outside/above the structure for false positives,
as well as entry, exit, ghost movement, facing and instance transitions.

Other included approach maps and dungeon interiors provide static artwork.
Interior player tracking is not included. Available floor buttons select
the configured map pages. Scholomance uses four native Forever minimap navigation
sections: 1 Main Halls, 2 Cellar, 3 Upper Vaults, 4 Lower Vaults. The existing
numbered buttons select these sections from the lower-right blank area inside
the map canvas; they are not measured horizontal Z floors.
Candidate A's clean masters are baked exactly 90 degrees clockwise with alpha
and the Lower Vaults cyan pixels preserved. Group 19 placement and the group 15
upper cutout/lower context retain the accepted reconstruction limitations.

Dire Maul Approach uses the approved 1536x1536 Kalimdor composite with the four
restored WMO 21065 corridor groups: Passage01, Passage02, Passage03 and EntRuins02.
The locked dev6 presentation crop is left 373, right 195, top 281, bottom 320,
retaining a 968x935 area. Its source dimensions, orientation, tracking transform, approach padding
and continuous-texture rendering are unchanged. Existing spatial detection
follows the visible cropped area without detector-code changes. Ghost form
is supported when valid coordinates are available. No entrance markers are added.
Use `/hm dev on`, then `/hmcrop dire_maul_exterior` to measure a new crop. Select
LEFT, RIGHT, TOP, BOTTOM and Lock; the existing tool records the result in
`HiddenMapsDB.cropCalibrationLog` without permanently applying it. `/reload`
or logout saves the log for a later build. Manual overrides retain their existing
behavior; use `/hmmap off` when testing automatic entry and exit. The added
corridor artwork and final crop require in-game verification.

Three additional static instance maps use complete artwork by Santiago Reyes
from **Atlas de Azeroth: Forever**: The Hall of Thanes, Ruins of Lordaeron, and
Excavation Site: Wetlands. Each retains its embedded watermark and displays an
additional credit below the artwork. These are artist-created maps, not official
Blizzard artwork. They have no player tracking, POIs, or floor selection.

Automatic selection of these three maps uses the English dungeon name reported
by `GetInstanceInfo`, only while inside a party instance. Their numeric runtime
instance IDs remain unconfirmed; Map.db2 and UiMap IDs are not used as substitutes.
Other client locales require name confirmation. Manual display is available with
`/hmmap hall_of_thanes`, `/hmmap ruins_of_lordaeron`, and
`/hmmap excavation_site_wetlands`.

## Installation and upgrades

1. Exit the game. Keep a backup of your previous addon if you want to roll back.
2. For an upgrade, replace the old `Interface/AddOns/HiddenMaps` folder with the
   `HiddenMaps` folder from this ZIP. Replacing the folder avoids leaving old
   files behind. Do not remove your WTF folder or saved settings.
3. Confirm that `Interface/AddOns/HiddenMaps/HiddenMaps.toc` exists directly at
   that path, without an extra nested `HiddenMaps` folder.
4. Enable HiddenMaps on the character-selection addon screen and log in.

This package targets WoW Forever. It is not the Classic Era release.

## Support commands

| Command | Purpose |
|---|---|
| `/hm` or `/hm status` | Version, detected map, and position diagnostics |
| `/hm maps` | Registered maps and any registration errors |
| `/hm debug` | Toggle diagnostic chat output |
| `/hmmap list` | List maps available for manual display |
| `/hmmap <map ID/name> [minutes]` | Temporarily display a map; default 30 minutes, maximum 120 |
| `/hmmap status` | Show the override and automatic detector result |
| `/hmmap off` | Return to automatic map detection |

`/hiddenmaps` and `/hiddenmapsmap` are equivalent long command names. Manual
map overrides clear on a new area/world transition, reload, expiry, or `off`.

New installations start quietly with debug output off. Upgrades preserve your
existing debug preference; use `/hm debug` if an earlier development build left
it on. Error messages and explicitly requested command results remain visible.
Advanced calibration tools are disabled by default, and existing calibration
logs are retained without changing packaged maps.

For a bug report, include the client build, addon version, `/hm status`,
`/hmmap status`, any Lua error text, and steps or a screenshot showing the issue.
Check once with other addons disabled to help identify a conflict.

RFD Approach uses the approved CLEANED tiles in
`Media/Maps/RazorfenDownsApproach/`. This is the only packaged RFD Approach
artwork set; the temporary developer comparison feature has been removed.

## Release status and credits

This development build retains the calibrated maps, tracking, chevron sizing, entrance
markers, and native-navigation behavior of the tested development build.
Support for untested clients and locales has not been established.
See `CHANGELOG.md` and `ASSET-NOTICES.md` for the
changes, known artwork origins, and outstanding license information.
