# Highground Battlegrounds

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Highground's battleground tools as their own addon, for players who want the timers and carriers without the kill order. Retail, WoW Forever and Cataclysm Classic.

- **Resurrection timers** for known graveyards on both teams, with an optional low-health reminder of an upcoming wave. Unknown countdowns stay marked as unknown.
- **Captures and win prediction:** base assaults with their countdown, who wins at the current pace, and how many bases the trailing team needs. Cataclysm Classic adds a sound when an enemy starts capping near you and countdown bars over the capper's nameplate.
- **Flag carrier panel:** both carriers with health, Focused Assault stacks and time held. Left-click targets, right-click focuses, also in combat. Blizzard's carrier frames can hide while it shows.
- **Enemy positions on the map**, from what you and your teammates see. Teammates running Highground or Highground Battlegrounds share sightings and timers.
- Optional **Quick callout panel:** movable **Help**, **1**, **2**, **3+** and **All clear** buttons in named areas. A click sends a message such as `Need help — Farm (3+ enemies)` or `All clear — Farm` directly to battleground chat. Enable it in `/hgbg config`; it starts off. **Preview windows** lets you position it outside a match, with sending disabled. Positions are saved per character, and the panel stays separate in Compact layout.
- Optional **Enemy destination callouts:** with the Quick callout panel enabled, choose another area, then click **1**, **2** or **3+** to send, for example, `2 enemies going to Farm` while at Lumber Mill. Destinations use the current map's bases and landmarks; selections reset between matches. This switch starts off in `/hgbg config`.
- Optional **EFC route callouts:** add **Ramp / Graveyard / Tunnel** in Warsong Gulch and **Ramp / Graveyard / Water** in Twin Peaks. A click sends `EFC going tunnel`, for example, including from midfield and without carrier tracking. This switch starts off in `/hgbg config` and requires the Quick callout panel. All callout buttons work in combat, share a cooldown, are disabled in previews.
- Optional **Sap calls** for rogues and an option to hide the quest tracker; both start off on new installations.
- **Enemy stealth alerts:** lower- and higher-pitched versions of the game's stealth sound mark entering and leaving stealth. Cata uses combat-log events; Retail and Forever use readable enemy casts and reappearance. Control these through **Enemy stealth** in `/hgbg alerts`.

**Objective overview** adds a goal summary, base ownership and recent enemy sightings. Cart and epic maps show visible objective status and recent announcements. `/hgbg calls` prepares incoming/help/clear/escort messages for you to send. `/hgbg history` keeps recent match results and observed timelines. Flag and orb carriers do not receive low-health resurrection reminders.

## Install

Install **Highground Battlegrounds** from [CurseForge](https://www.curseforge.com/projects/1770535), or extract its ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases) into `Interface/AddOns/`, then restart the game. The folder must be named `HighgroundBattlegrounds`. When Highground is loaded, this addon stays inactive and directs you to `/hg`. For a source checkout, follow [source installation](../../docs/monorepo.md#source-installation).

Settings are saved per account in `HighgroundBattlegroundsDB`, window positions per character in `HighgroundBattlegroundsCharDB`.

New installations work in ordinary battlegrounds and use **Essentials** alerts. Upgrades also enable unrated battlegrounds once; other preferences and later scope choices are kept. `/hgbg config` starts with the main panel choices; **More settings** reveals detailed controls and appearance.

## Commands

| Command | What it does |
| --- | --- |
| `/hgbg` | Status. `/hgbattlegrounds` works too |
| `/hgbg on`, `/hgbg off` | Turn the battleground tools on or off |
| `/hgbg test` | Preview the resurrection, objective and flag carrier windows to place them |
| `/hgbg reset` | Windows back to their default spots |
| `/hgbg timers`, `/hgbg intel` | What the timers and the map have seen this match |
| `/hgbg config` | Settings: which battlegrounds, each panel and alert, sharing, sounds |
| `/hgbg calls [incoming\|help\|clear\|escort] [COUNT] [LOCATION]` | Prepare a callout; press Enter to send |
| `/hgbg history` | Saved match results, stats and observed timelines |
| `/hgbg alerts` | Alert presets and category controls |
| `/hgbg theme NAME` | Highground, Ember, Parchment, Azeroth or Class Colors (`classcolors`) |
| `/hgbg help` | Command help in chat |

## Documentation and development

Its code is in `src/`; `libs/` links to the HighgroundKit library (packages get copies). Highground imports `src/` too. See [monorepo](../../docs/monorepo.md), the [user guide](../Highground/docs/user-guide.md#battleground-panels), [battleground coverage](../Highground/docs/battlegrounds.md), [observations and timers](../Highground/docs/observations.md) and the [changelog](CHANGELOG.md).

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/); game-audio attribution is in [libs/sounds/stealth.txt](libs/sounds/stealth.txt).
