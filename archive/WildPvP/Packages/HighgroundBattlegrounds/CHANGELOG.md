# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## [0.8.1] - 2026-11-08

- Fix full-name matching for players with surnames on WoW Forever, including identifying your team from the scoreboard and targeting or focusing visible players.
- Keep panel cogwheels reachable while locked and in Frameless mode, with lock/unlock, arrangement and settings in one menu. Compact battleground columns share one cogwheel on the first visible panel.
- Restart WoW after updating; this release adds panel-control files, so `/reload` is not enough.

## [0.8.0] - 2026-11-04

- **Enemy destination callouts:** choose another area, then click **1**, **2** or **3+** to report enemies heading there, such as `2 enemies going to Farm` while at Lumber Mill.
- **EFC route callouts:** **Ramp**, **Graveyard** and **Tunnel** in Warsong Gulch; **Ramp**, **Graveyard** and **Water** in Twin Peaks. One click sends the selected route, including from midfield and during combat.
- Both new switches start off. Standalone Battlegrounds: `/hgbg config` → **Quick callout panel**. Enable the panel and the desired options; existing local help calls stay available, and all sends share the same brief cooldown. Previews cannot send messages.
- Destination selections reset between matches. Gilneas **Mine/Mines** appears once, using the game's observed name when available.
- Restart WoW after updating; this release adds an addon file, so `/reload` is not enough.

## [0.7.2] - 2026-11-04

- Maintenance release alongside Highground's marker update. This addon's features and saved settings are unchanged.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.7.1] - 2026-11-01

- Class Colors is now the default theme. Explicit saved theme choices are preserved; Highground, Ember, Parchment and Azeroth remain selectable.
- Updating from the previous release needs only `/reload`. Restart WoW if your installed version predates Class Colors.

## [0.7.0] - 2026-11-01

- New optional **Class Colors** theme: choose it in settings or use `/hgbg theme classcolors`.
- The Class Colors theme adds darker panels and readable text to the battleground tools.
- Existing themes and saved layout, text-size and opacity settings remain available. The theme switches immediately, including in combat.
- Restart WoW after updating; this release adds a theme file, so `/reload` is not enough.

## [0.6.0] - 2026-11-01

- **Enemy stealth alerts:** observed opponents entering and leaving stealth in active battlegrounds now produce chat notices and distinct versions of the in-game stealth sound: lower-pitched on entry, higher-pitched on exit.
- Use `/hgbg alerts` → **Customize categories** → **Enemy stealth** to control text and sound. Existing sound settings, alert presets and battleground scope are respected; Vanish followed by Stealth produces one enter alert.
- Cataclysm Classic reads applications and removals from the combat log. Retail and WoW Forever use readable enemy casts and reappearance.
- Restart WoW after updating; this release adds addon files, so `/reload` is not enough.

## [0.5.2] - 2026-11-01

- Stronger standard class colors make Rogue yellow easier to distinguish from Priest white.
- Class-colored text keeps its hue when adjusted for contrast, including on the Parchment theme. Custom class colors remain respected.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.5.1] - 2026-10-31

- Fixed blank rows in match history, including empty lists and enlarged text sizes. Only available records are shown.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.5.0] - 2026-10-30

- **Quick callouts:** a separate movable panel shows your current named battleground area with **Help**, **1**, **2**, **3+** and **All clear** buttons. Click to send a help request and the chosen enemy count directly to battleground chat, including during combat. **All clear** tells teammates everything is okay at your location.
- The panel starts off. Enable **Quick callout panel** in `/hgbg config`. Positions are saved per character, and the panel stays separate in Compact layout. Use **Preview windows** outside a match to place it with sending disabled.
- Existing chat drafts stay intact; a brief cooldown prevents accidental double sends.
- Restart the game after updating; this release adds a new file, so `/reload` is not enough.

## [0.4.0] - 2026-10-30

- **All battlegrounds:** ordinary matches, including Seething Shore, activate the tools by default. Existing installations receive a one-time upgrade to include unrated matches; later scope choices are kept.
- **Quieter first use:** Essentials alerts, with sap calls, quest-tracker hiding, objective overview and resurrection reminders optional. Main switches appear first in /hgbg config; More settings reveals details.
- Clearer graveyard estimates, carrier tooltips and resurrection-reminder wording.
- **Match history:** Undo delete restores a removed match. Clear search and paging adapt to larger text.
- Restart the game after updating; the settings now include an additional file.

## [0.3.0] - 2026-10-30

- **Objective overview:** base ownership, recent enemy sightings and resource-map plans where available. Cart and epic maps show visible status and recent objective announcements.
- `/hgbg calls` prepares incoming/help/clear/escort messages. Choose a count and location, then press Enter to send.
- `/hgbg history` saves observed results, available personal stats and objective timelines. `/hgbg alerts` opens alert presets and category controls.
- Recognized localized battleground announcements update node assaults, ownership and flag state, using live node names where available. Unsupported or custom messages can still leave gaps.
- Flag and orb carriers no longer receive death-timing advice from the resurrection alert.
- Refreshed Highground, Ember and Parchment themes, plus the new Azeroth theme. Text size, clearer focus and status labels, and Reduced motion apply across the interface.
- New files: after updating, restart the game instead of `/reload`.

## [0.2.0] - 2026-10-29

- Map: enemies with no known position are no longer lined up at the left edge. Without even a rough spot, they are left off the map instead of guessed.
- Map: enemy pins turn greyer, fainter and smaller the longer it has been since they were seen there, fastest in the first half minute.
- Silvershard Mines (Retail): both graveyards are on the map with resurrection timers. The enemy's comes from their spirit guide, a shared clock, or enemies seen alive again after dying.
- Enemies seen alive again after dying now estimate the enemy wave on maps with one graveyard per faction, even without a position. A player's resurrection, Reincarnation or Feign Death is not counted.

## [0.1.2] - 2026-10-28

- Shared code updated with Highground 2.29.1; no change in this addon.

## [0.1.1] - 2026-10-28

- Shared code updated with Highground 2.29.0; no change in this addon.

## [0.1.0] - 2026-10-28

- First version on its own: Highground's battleground tools without the kill order. `/hgbg` shows its status, `/hgbg config` its settings.
- Runs on Retail, WoW Forever and Cataclysm Classic.
- **Resurrection timers** for both teams' graveyards and the resurrection alert, with its health and timing thresholds on the settings page.
- **Captures and win prediction** in the objective panel; on Cataclysm Classic, the capture alert and capture bars over nameplates.
- **Flag carrier panel** (target and focus in combat) and Blizzard's carrier frames hidden while it shows.
- **Enemy positions on the map** and sharing with teammates who run Highground or Highground Battlegrounds.
- Sap calls for rogues, the quest tracker hidden in battlegrounds, and switches for each battleground size.
- `/hgbg test` previews the windows so you can place them outside a battleground.
