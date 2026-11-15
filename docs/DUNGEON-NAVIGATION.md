# Dungeon navigation companion

WildSpark's dungeon navigation bundle includes **HiddenMaps 1.2.2 by Lichdom** as a companion addon. HiddenMaps remains a separate addon folder so its own saved variables, namespace, and asset paths work as authored.

## Install

Extract the bundle into `Interface/AddOns` and enable both `WildSpark` and `HiddenMaps` at character select. WildSpark declares HiddenMaps as an optional dependency for load ordering; WildSpark still loads if HiddenMaps is absent.

## Coverage

The supplied HiddenMaps release registers 40 map definitions: static maps for the classic dungeon set, their configured wings and floors, supported dungeon approaches, Blackrock Mountain interior, and Forever's Hall of Thanes, Ruins of Lordaeron, and Excavation Site: Wetlands. Open the World Map in a supported area to show the corresponding map and its configured floor selector, entrance markers, and boss markers.

## Position limits

The player marker is best-effort and approximate. HiddenMaps documents live position and facing on supported outdoor approaches when the client returns usable coordinates. Most dungeon interiors have static artwork; the supplied release does not track player position inside them. WoW Forever may withhold dungeon coordinates, and encounter or room events do not provide a reliable substitute for continuous location. When coordinates are unavailable, the static map, floor or wing selection, entrance and boss markers, and detected dungeon name remain available. The addon does not claim exact live GPS.

Verify map detection, floor changes, markers, and any available player marker in a live Forever session. The upstream release notes identify several approach maps and the three Forever maps as needing in-game acceptance or locale confirmation.

## Attribution and notices

HiddenMaps is by **Lichdom** and is included in WildSpark with the author's permission. Preserve its `ASSET-NOTICES.md`, `README.md`, `CHANGELOG.md`, embedded Santiago Reyes watermarks, and displayed artwork credits. The three Forever map artworks Hall of Thanes, Ruins of Lordaeron, and Excavation Site: Wetlands credit **Santiago Reyes — Atlas de Azeroth: Forever**. Blizzard-derived imagery remains Blizzard's property. The upstream notice states that the package has no standalone code license and that some inherited asset permissions are undocumented; this inclusion does not grant additional rights to third-party artwork.

Upstream release: [HiddenMaps 1.2.2 for WoW Forever](https://www.curseforge.com/wow/addons/hiddenmaps/files/9496110).
