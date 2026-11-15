# WildMaps dungeon navigation

WildMaps is an integrated WildSpark module adapted from HiddenMaps 1.2.2 by Lichdom with the author's permission. The original release media is fetched by the stable build workflow using the exact CurseForge file ID and a SHA-256 check; map code and the original asset notice are kept in this repository.

## In the WildSpark pane

Open `/wildspark` and select the **WildMaps** tab, identified by its map icon. The tab has an enable switch and an **Open World Map** button. In supported areas, WildMaps selects a map automatically and offers configured floor/wing controls, boss markers, entrance markers, and a room/subzone label when the client reports one.

## Coverage and location

The supplied source registers 40 map definitions spanning the classic dungeon set, configured wings/floors, supported approaches, Blackrock Mountain interior, and the Forever maps Hall of Thanes, Ruins of Lordaeron, and Excavation Site: Wetlands.

Player positioning is best-effort and approximate. Supported approaches can show a player marker when Forever returns usable coordinates. Most dungeon interiors have static maps and no live player tracking. The room label is the client's reported subzone/minimap name; WildMaps does not turn that label into a guessed coordinate or claim exact GPS. Map selection, room labels, floor controls, markers, and any position marker need in-game verification on Forever 1.60.1.

## Attribution

Keep `Wildspark/Modules/WildMaps/ASSET-NOTICES.md`, upstream credits, displayed Santiago Reyes credits, and embedded artwork watermarks. Blizzard-derived imagery remains Blizzard's property. The upstream notice states that no standalone code license is supplied and some inherited asset permissions are undocumented; permission to adapt HiddenMaps for WildSpark does not grant additional rights to third-party artwork. See the module's `README.md` and `UPSTREAM-README.md` for retained detail.
