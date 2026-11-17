# WildMaps

WildMaps is WildSpark's integrated dungeon-map module, adapted from HiddenMaps 1.2.2 by Lichdom with the author's permission. It loads as part of the single `WildSpark` addon folder. Open WildSpark's side pane and select **WildMaps** to enable or disable the module or open the World Map.

## Coverage

The source release registers 40 maps covering the classic dungeon set, configured wings and floors, supported dungeon approaches, Blackrock Mountain interior, and the Forever maps Hall of Thanes, Ruins of Lordaeron, and Excavation Site: Wetlands. Boss and entrance markers and floor selectors are included where configured.

## Position limits and manual fallback

The player marker is best-effort and approximate. HiddenMaps documents position and facing on selected approaches when usable client coordinates are available. Most dungeon interiors have static maps: WoW Forever does not expose a usable player coordinate or room signal there, so WildMaps cannot track movement or claim exact live GPS.

When automatic detection cannot identify a dungeon wing, choose its map from the WildMaps pane. On a static indoor map, click **Set Approximate Entry Marker**, then click the approximate point where you enter. WildMaps saves an amber fixed marker for that map as a starting reference; it does not move with the player. You can click the control again to replace it. The marker should be calibrated in game for each map where it is needed.

When available, the client-reported subzone or minimap area name remains descriptive text; it is never converted into a guessed coordinate.

Manual selection, entry-marker placement, floor controls, artwork, and any live player marker still need in-game verification on WoW Forever 1.60.1.

## Attribution

The source notice in `ASSET-NOTICES.md` is retained unchanged. Keep all upstream notices and the embedded watermarks and displayed credits. Hall of Thanes, Ruins of Lordaeron, and Excavation Site: Wetlands credit Santiago Reyes — Atlas de Azeroth: Forever. Blizzard-derived imagery remains Blizzard's property. The upstream notice says there is no standalone code license and some inherited asset permissions are undocumented; the author's permission to use HiddenMaps in WildSpark does not grant additional rights to third-party artwork.


## Compact zone map
Use `/wildmaps zone` to open the movable compact map. Use `/wildmaps size` to cycle three window sizes. Zoom with the plus/minus buttons or mouse wheel, browse catalog maps with the arrow buttons, and switch floors where available.
