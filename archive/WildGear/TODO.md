# To do

Promised on the CurseForge comments (2026-11-14/15).

## 1.3.1

Everything below is committed and checked in game (11-15), except the real dual talent swap. Not in
the changelog yet: `/release` writes it.

- [x] **Dungeon quests switch** (Settings > Sources > Quest): off = rewards of quests the game files as
  Dungeon quests count no more.
- [x] **What's new restyle**: wider, emblem heading, a card per note.
- [x] **Dual talent: spec follows the talent set** (user_czlc9zm0s01uo50g, promised "next update").
  Settings > Specs gives each line (main + off specs) a Talents row (None / Primary / Secondary, active
  one dotted) once `GetNumSpecGroups()` is 2; the line linked to `C_SpecializationInfo.GetActiveSpecGroup()`
  is the main spec (Tooltip.lua `Tip.SyncTalents`). Checked in game with the dev addon's fake swap
  (`/wildgear talents`) only: no level 40 character yet. The swap event isn't confirmed on Forever, so we sync
  on all three talent events and at login: Blizzard's own Camelot talent window (extracted from the client,
  `Blizzard_PlayerSpells/Camelot/ClassTalents` on the shared `ClassTalents/Blizzard_ClassTalentsFrame.lua`)
  ends a swap on `ACTIVE_COMBAT_CONFIG_CHANGED` and refreshes on `PLAYER_TALENT_UPDATE`, and never
  listens for `ACTIVE_TALENT_GROUP_CHANGED` (documented in the client's API docs, never seen fire).
- [x] **Dialogue UI support** (user_7agp7nq3d6d5soay, promised "next update"): DialogueUI.lua makes
  Dialogue UI's own reward arrow go by our verdict (we're its item evaluator, ahead of its Pawn plugin;
  its mixin hooked too, as 1.0.7 ignores a late evaluator) and adds the block as text to its tooltip.
  Not done: best-pick outline and gold coin on its buttons (later, if asked).
- [x] **All suffixes of an item** (user_5pvhkqpdoewdsgzo): the slot lists show a line per suffix that
  adds something for the spec (`ns.SuffixRows`), each with its own score, worn mark and star. Rankings,
  Equip best and upgrades keep the best suffix. The wish list holds a line per suffix too.

### After 1.3.1 ships

- [ ] **A real dual talent swap at 40**: learn dual talent, link both sets, swap, and check the main spec
  follows and "Main spec: ..." prints once. If it doesn't, `/etrace` the swap for the event that fires.
  Ask user_czlc9zm0s01uo50g to try it when replying that it shipped.

## 1.3.2

Everything checked below is committed and checked in game (11-16), as are the Modern theme refresh,
DaylightUI support and the lazy tooltip rankings. Not in the changelog yet: `/release` writes it.

- [x] **Expertise as a flat %, like hit and crit** (CurseForge question, 11-15). Confirmed in game 11-15:
  the Dwarven Tree Chopper's 6 expertise rating shows "Equip: Reduces chance to be Dodged or Parried by
  0.6%" below 60 (the client's `TOOLTIP_ITEM_STAT_EXPERTISE_PCT_INCREASE`), so it's 10 rating = 1% at every
  level. `exprtng` stayed a rating and the model scaled it like TBC (`rating_per_pct`, x(level-8)/52),
  overvaluing it below 60: about 4x at 20, 2x at 35 (only 9 items: Dwarven Tree Chopper, Expert
  Goldminer's Helmet, Supreme Smasher, Tuskblade Halberd...). Done 11-16: an `expPct` key at 10 rating per
  1% (scrape.py `GP_RATING_PCT`, tooltip.py, devscan.py `GAME_PCT`, Equipped.lua for worn gear), "+1%
  expertise" on the Stat weights panel and in the tooltip's "includes" lines, the statmodel specs on
  `model.gear_expertise_pct`, Data and ModelWeights rebuilt (with the 70888 item-scan shift). Saved
  profiles and old FLB1 strings turn `exprtng` into `expPct` x10 (they rank as before, so a snapshot made
  below 60 keeps its high expertise until Reset); Pawn's `ExpertiseRating` is ours / 10.
- [x] **Wish list on the window** (user, 11-16; answers the Wish list tab request under Maybe). While the
  window is open the list is on a side panel under My gear (in My gear's place while that is closed):
  WishList.lua `CreateDock`, placed by `UI.DockSides`. As many lines as fit above the screen's bottom,
  then "+N"; click the title to fold it (`wishDockFolded`); shows even with the tracker switched off.
  It moves there and back with its stars flying across (`WL.Window`; timings: the `DOCK_*` values).
  Modern has its own title icon (`PanelWish.tga`, `tools/panelicons.py`). Checked in game in all three themes (11-16).
- [x] **Wish for all, Clear all, the tracker's limit** (user, 11-16). A star after the "Upgrades now" title
  on the Dungeon loot and Quests tab Summary pages wishes for every pick under it, and takes them off
  again once all are wished (`WL.SetStarAll` / `WL.ToggleAll`, `Draw.section`'s `wish`). The window's
  panel has Clear all at its foot, which asks first (`WL.Clear`). The on-screen tracker shows 8 lines at
  most, then "+N" (`TRACKER_LINES`). Smoke test lines "wish list dock" and "wish for all" pass in the three
  themes and zhCN; checked in game (11-16). 11-17: click "+N" for all of them (as many as fit on the
  screen, `wishExpanded`), the minus sign in its place to go back; smoke test "wish list expand" passes.
- [ ] **Wish list on the My gear panel** (CharacterPanel.lua, the Character frame's My gear): show the
  wish list there too, beside your gear. Goes with the request for a Wish list tab in the main window
  (user_zxe352zar01gmtgt1371, under Maybe).
- [x] **Wish list size setting** (user, 11-16: "too small"): Settings > Display > Wish list size, 80-200%
  by 10% (display key `wishScale`, Theme.lua; Reset to defaults clears it). The tracker `SetScale`s at once
  about its saved corner (`wishPos` converted, WishList.lua `ApplyScale`); Got it leaves grow with it.
  Smoketest line "wish list size"; checked in game (11-16).

## 1.3.3

- [x] **DaylightUI quest windows** (user 11-17): DaylightUI draws its own NPC quest window
  (`DaylightUINpc`) and quest journal on the map (`DaylightUIQuestJournal`), so the reward marks never
  showed there. QuestWindow.lua's DaylightUI section now marks its reward tiles (upgrade arrow, best
  pick outline and tint, gold pick for its price, tooltip line) and its journal list (upgrade mark after
  the title). DaylightUI asks addons not to hook its functions and has no API for these windows, so it
  looks at them five times a second while they show and marks again when their tiles change. The
  journal page doesn't say which quest it shows: it's the log quest whose rewards are exactly its tiles'
  items. Smoke test lines "DaylightUI: ..." pass. To check in game: NPC window on offer and on turn-in
  (outline gives way once you pick a choice; our arrow sits left of DaylightUI's own coin), journal
  quest page and list. Checked in game (11-18).

## 1.4.0

- [ ] **BoE explorer** (big feature, user 11-16): a place to browse every BoE that's useful to you,
  not only the few that win a slot. Today BoEs show up only as rows in Best in slot (the `boe` source,
  Settings > Sources > BoE with Rare / Epic / Dungeon drops), so an upgrade that isn't the best never
  shows. Likely a 5th tab beside Best in slot, Dungeon loot, Crafting patterns and Quests, using the BoE
  data we already ship (`s.type == "boe"` in Items.lua, best suffix per item via `ns.SuffixRows`).
  To settle before building (mock it first, as for the Quests tab):
  - "Useful to you": upgrades over worn gear for the main spec (and off specs?), within the look-ahead
    levels, items you can wear and use (armor type, weapon skills, class/race limits).
  - Layout: by slot, or one list sorted by gain; columns for item level, required level, gain, where it
    drops (world drop, rare mob, dungeon), quality.
  - Filters: slot, quality, level range, source (world / rare / dungeon), maybe "show downgrades too".
  - Actions: wish list star per row (and per suffix), shift-click to link, tooltip with our block;
    an Auction House search button would help, but check what Forever's AH allows first.
  - Respect the BoE switches, or ignore them here (the explorer could stay usable with BoE off in
    rankings)?
- [ ] **Gamepad support like Questie's** (samogas_1199, promised "in the next few updates"; moved from
  1.3.2 on 11-16). Done in 1.2.8: Options page and a key binding that takes pad buttons. Still to do:
  moving around the window with the pad, more bindings (Equip best, per tab), the bound key shown in
  hints, ConsolePort registration, right-stick list scrolling.

## Maybe

- [ ] Hide downgrades, and dungeons with no upgrades, from the lists (noonien).
- [ ] CSV text box for copy and paste (crookedjay), "not guaranteed".
- [ ] Wish list tab in the main window (user_zxe352zar01gmtgt1371, no reply yet).
- [ ] Azure Silk Hood missing for a Frost Mage at look-ahead +4 (user_ed3w548jnee9yo1f, no reply yet; check).
