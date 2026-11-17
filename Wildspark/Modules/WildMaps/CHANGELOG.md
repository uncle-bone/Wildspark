# Changelog

## 1.3.0 — Compact Zone Map
- Restored WildMaps to the stable WildSpark build.
- Added movable compact dungeon-map window with size, zoom, map and floor controls.

## 1.2.2-dev3 — 7 November 2026 (OpenMap 0.7.5 compatibility)

- Recognize the supplied Forever OpenMap v0.7.5-beta source without requiring its absent Client field or Root getter.
- Read and cache its validated artwork/icon root pair through the existing IsBuilt/Parts accessors.
- Preserve the v0.8.0-beta adapter, rail visibility leases, Questie/Leatrix handling and all map data.
- Runtime rail suppression on v0.7.5 still requires in-game acceptance.

## 1.2.2-dev2 — 7 November 2026 (private OpenMap control follow-up)

- Temporarily suppress OpenMap’s validated vertical tab/favourites rail through the existing compatibility lease.
- Preserve later OpenMap visibility requests, including drag-end refresh while acquiring the rail.
- Leave native map chrome, artwork ownership, tracking, map data and Questie/Leatrix adapters unchanged.
- Prior artwork/reopen fix was physically confirmed by the owner; control suppression awaits in-game acceptance.

## 1.2.2-dev1 — 7 November 2026 (private OpenMap compatibility test)

- Keep HiddenMaps presentation frames private to avoid OpenMap acquiring them by name.
- Extend the existing compatibility coordinator with reversible, validated OpenMap surface leases and explicit navigation handoff.
- Block native map zoom input while HiddenMaps is displayed; release it on close, yield, or deactivation.
- Preserve all map artwork, data, tracking, detection, and Questie/Leatrix adapters.
- Static and simulated validation only; real-client acceptance remains pending.

## 1.2.1-dev5 — 18 October 2026 (Scholomance selector position)

- Anchor Scholomance's existing four buttons inside the lower-right blank area
  of the live map canvas, with a 20-unit inset on both sides.
- Preserve section artwork, fitting, selection, compatibility layering and
  every other map's control placement.

## 1.2.1-dev4 — 18 October 2026 (Scholomance integration test)

- Replace only the Scholomance WMO placeholder with Candidate A's four native
  Forever minimap sections: Main Halls, Cellar, Upper Vaults and Lower Vaults.
- Bake one lossless 90-degree clockwise rotation into 256x256 RGBA TGA tiles.
  Preserve source pixels, alpha, existing margins and the cyan Lower Vaults art.
- Retire the three unreferenced Scholomance placeholder textures. Reuse the
  existing numbered selector, contain fitting and instance detection unchanged.
- Preserve all other maps, tracking, markers, navigation and compatibility code.
  Accepted reconstruction uncertainties and real-client acceptance remain.

## 1.2.1-dev1 — 15 October 2026 (private compatibility test)

- Add one unified Leatrix Maps / Questie compatibility controller with reversible
  native-canvas visibility, native-coordinate visibility and separate tooltip
  alpha leases. Preserve foreign providers, current visibility intent and settings.
- Keep the full HiddenMaps input shield, entrance tooltips and all floor controls
  usable. Hand off validated external navigation and changed NavBar destinations;
  ordinary SetMapID refreshes do not dismiss HiddenMaps.
- Preserve all v1.2.0 maps, calibration, artwork, tracking and detection. Interface
  16001 and the SavedVariables declaration remain unchanged. Private testing only;
  native rendering, hit testing, callback timing and combat/taint need WoW testing.
- Leave the independently reproduced Questie waypoint-line GlowUpdate error
  unchanged; this build does not repair Questie internals.

## 1.2.0 — 15 October 2026

- Add the four permanent Blackrock Mountain markers from the locked dev15
  calibration: Blackrock Depths, one shared Blackrock Spire entrance, and the
  outdoor exits to Burning Steppes and Searing Gorge.
- Keep the standard instance-entrance icon for both dungeon entrances. Use the
  supplied exit artwork only for the two outdoor exits, through existing
  per-marker texture support.
- Preserve dev15 map artwork, crop, rotation, tracking, detection and all other
  maps. Retain Interface 16001 and the existing SavedVariables format.
- Advance to the numbered feature milestone; final in-game acceptance and
  release regression testing remain pending.

## 1.1.0-dev10 — 14 October 2026

- Replace Sunken Temple Approach art with the verified Forever WMO 21140 export.
- Bake the exact 77.5-degree counterclockwise correction into one continuous TGA.
- Enable existing WMO live tracking, facing and spatial detection using the supplied placement.
- Replace the old crop with transparent-margin trimming; retain all visible art and source files.
- No shared code, other map definitions or unrelated artwork changed.

## 1.1.0-dev8 — 13 October 2026

- Remove the obsolete Dire Maul exclusion from entrance calibration, enabling
  `/hmentrance dire_maul_exterior` and its entry in `/hmentrance list`.
- Reuse the existing single/multiple entrance preview and logging workflow.
  Map definitions, crop, artwork, tracking and marker rendering are unchanged.

## 1.1.0-dev7 — 13 October 2026

- Apply only the locked dev6 Dire Maul presentation crop: left 373, right 195,
  top 281, bottom 320; retain a 968x935 area of the unchanged 1536x1536 source.
- Keep the approved artwork, tracking transform, orientation, padding, shared
  renderer and detector code, commands, markers and all other maps unchanged.

## 1.1.0-dev6 — 13 October 2026

- Integrate the approved Dire Maul composite with Passage01, Passage02,
  Passage03 and EntRuins02, rendered from WMO 21065 and the supplied textures.
- Reset only Dire Maul's four presentation-crop values to zero for in-game
  recropping. Keep the full 1536x1536 source, approach padding and continuous
  2048x2048 texture storage. Existing spatial detection follows the visible area.
- Preserve source coordinates, orientation, tracking, facing, commands, markers,
  shared renderer and detector code, all other artwork and all other maps.
- Development build for physical corridor-artwork review and crop calibration.

## 1.1.0-dev5 — 12 October 2026

- Apply Dire Maul's locked dev4 presentation crop exactly: left 710, right 238,
  top 274, bottom 320. Retain the full artwork and original source coordinates.
- Enable the existing spatial detector for Dire Maul's visible cropped coverage;
  area aliases no longer activate it outside that coverage. Existing movement
  polling handles entry and exit without requiring a zone-name change.
- Keep dev4's continuous texture, tracking, facing, outdoor guards, instance
  selection, manual overrides, all shared code and every other map unchanged.
- Development build for physical crop and automatic-transition verification.

## 1.1.0-dev4 — 12 October 2026

- Remove Dire Maul Approach's internal artwork joins by packaging its unchanged
  1536x1536 pixels in one 2048x2048 TGA instead of 36 separate textures.
- Use the existing renderer's texture bounds to exclude unused storage. Keep
  source/display dimensions, orientation, tracking, crop and padding unchanged.
- No shared code, detection, markers, commands or other maps changed.
- Development build; seam removal at normal/maximized sizes awaits in-game check.

## 1.1.0-dev3 — 12 October 2026

- Replace Dire Maul's experimental WMO preview with the complete supplied
  1536x1536 Kalimdor minimap composite, preserving native pixels and orientation.
- Enable Dire Maul live tracking through the existing world-minimap-tile path,
  with grid origin and scale derived from the matching geographic JSON.
- Let this map opt into existing validated outdoor world-position acquisition;
  tolerate only floating-point roundoff at its source-image bounds. Existing
  maps retain their original acquisition and projection behavior.
- Preserve detection, manual overrides, calibration tools, all other maps and
  shared presentation. No permanent crop, padding, entrances or spatial detection.
- Development build for physical artwork, movement and facing verification.

## 1.1.0-dev2 — 12 October 2026

- Replace only Dire Maul Approach artwork with the supplied complete 823x803
  WoWExport 3D-preview PNG, converted losslessly into 16 existing-format TGA tiles.
- Use the supplied orientation with no rotation, crop or new padding. Remove
  obsolete Dire Maul minimap provenance/bounds that do not describe this preview.
- Keep `dire_maul_exterior`, its detection and manual override, all other maps,
  and all shared systems unchanged. No tracking, markers or calibration added.
- Experimental artwork test for physical review in the Forever beta.

## 1.1.0-dev1 — 11 October 2026

- Add Maraudon Approach tracking using verified WMO placement and minimap data,
  including the exported tilt and live altitude; retain ghost-form support.
- Add the three locked Maraudon entrance markers and exact hover labels. Recover
  stable source coordinates from the post-orientation-fix calibration record.
- Align Maraudon overlays with its existing crop-relative 180-degree display turn.
- Retain the orientation-corrected 1.0.0 baseline artwork, crop, detection, sizing,
  commands, calibration module, and every other map. No assets added or changed.
- Development build for in-game confirmation, not a new public release.

## 1.0.0 — 7 October 2026

- Adopt version 1.0.0 for the first public release of HiddenMaps for WoW Forever.
- Update version metadata and documentation only. Runtime Lua/XML, artwork,
  maps, tracking, and all other behavior are unchanged from beta2 RC1.

## 0.2.0-forever-beta2 — 7 October 2026

- Retain the approved CLEANED RFD Approach tiles as the only production set.
- Remove the temporary artwork-comparison command, module, and original-tile
  archive from the installable addon. Old saved artwork choices are ignored.
- Preserve all map definitions, tracking, presentation, markers, and the
  developer-tool defaults established during the previous cleanup.
- Update public-beta metadata and clarify the Blizzard-derived asset notice.

## 0.2.0-forever-dev13 — 7 October 2026

- Use the 12 supplied CLEANED RFD Approach tiles as the default artwork.
- Preserve the exact 12 dev12 ORIGINAL tiles in the packaged Media/Archive folder.
- Add temporary developer artwork comparison, with immediate refresh of a
  displayed RFD Approach and a saved preference; removed in beta2.
- Keep one RFD Approach registration and leave its geometry, crop, orientation,
  tracking, chevron, entrance marker, and renderer unchanged.

## 0.2.0-forever-dev12 — 6 October 2026

- Scale the live approach chevron with fitted artwork when the World Map is
  maximized; retain its 24-unit normal size and restore it on minimize.
- Handle first-open-maximized using the native minimized frame dimensions and
  measured viewport insets; retain the normal reference while maximized.
- Add the Wailing Caverns entrance from the locked dev11 calibration log,
  retaining its exact source coordinates, tooltip, texture, and existing size.
- Leave entrance-icon sizing, tracking geometry, crops, padding, detection,
  calibration tools, static maps, and dev11 native navigation unchanged.

## 0.2.0-forever-dev11 — 6 October 2026

- Let native right-click parent navigation and higher-level World Map breadcrumbs
  reveal Blizzard's map for the remainder of the current open-map session.
- Reset the temporary display bypass when the World Map closes, retaining normal
  detection, manual selections, and all map content and tracking calculations.
- Forward shield and marker right-clicks to Blizzard's parent-map action while
  continuing to block interaction with hidden pins. Ordinary internal map changes
  alone do not activate bypass.

## 0.2.0-forever-dev10 — 6 October 2026

- Add static Santiago Reyes maps for The Hall of Thanes, Ruins of Lordaeron,
  and Excavation Site: Wetlands, retaining all original pixels and watermarks.
- Add a small credit footer below these maps, with proportional artwork fitting
  and space reserved for the complete credit text.
- Select these maps using the reported English instance name only while inside
  a party instance. Numeric runtime IDs and other locales await confirmation.
- Preserve beta1's developer-tool controls and all existing map definitions,
  transforms, tiles, floor controls, and World Map integration.

The next numbered development build is based on beta1, not a restart from dev9.

## 0.2.0-forever-beta1 — 5 October 2026

- Default diagnostic chat to off for new installations; preserve saved
  preferences and keep the startup message available when debug is enabled.
- Require explicit session enablement for crop and entrance calibration.
  Reload disables calibration access. Existing calibration records are retained.
- Remove polling of the inactive debug badge and clarify diagnostic labels.
- Archive eight unused decorative faction-strip textures outside the installable
  addon and remove their unused theme lookup/helper. Retain the layout frames.
- Correct stale comments and add installation, support, and asset notices.

All map definitions, tracking transforms, artwork still in use, permanent crops,
padding, entrance positions and tooltips, floor controls, and map registration
order are inherited unchanged from dev9. The dormant WC research bundle remains
included and disabled by default.

This is a cleanup candidate; final in-game acceptance of this package is pending.
