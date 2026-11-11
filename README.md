# WildSpark

> **[Download WildSpark 1.5.10 — Latest Stable](https://github.com/uncle-bone/Wildspark/releases/download/v1.5.10/WildSpark-1.5.10.zip)**

**Current stable release: 1.5.10 for WoW Forever 1.60.1.** The installable ZIP contains one `WildSpark` addon folder.

WildSpark brings nearby resource highlighting, buffs, leash helpers, camping, auction tools, group finding, and layer hopping together under one addon. Each major module has its own settings tab and can be disabled separately.

## Features

- Fix the Blizzard Auction House window layout when switching from WildAuctions to Blizzard UI; credits show Uncle Bone.

- Fix the Blizzard Auction House window layout when switching from WildAuctions to Blizzard UI; credits show Uncle Bone.

- Highlight nearby herbs, ore, quest objects, chests, and fishing bobbers with configurable glow effects, colors, labels, and visibility rules.
- Show gathering icons on the minimap, learn node labels and profession skill requirements, and optionally alternate herb and ore tracking.
- Use the optional minimap ping when a new target is recognized. Version 1.5.6 adds separate visual and sound toggles, visual strength, sound volume, and a larger two-ring pulse.
- Use WildBuffs' rotating or individual spell buttons for supported classes. Buff casts happen only on a click or keybind.
- Track creature leashes with timers and combat-event details.
- Use the integrated **WildFire** for camping objects, camp effects, food and Well Fed timers, camp tracking, sharing, and map pins.
- Use **WildAuctions** for auction house tools, including selecting bag items from the Auction House interface. It does not post auctions automatically.
- Use **WildGroups** from its own tab in Blizzard's Looking For Group pane.
- Use **WildLayer** from its own WildSpark tab or minimap button to request layer hops. Automatic invites to players requesting your layer are off by default and can be enabled in the WildLayer tab.
- See WildLayer's observed raw GUID identifier under the minimap after targeting or mousing over a creature, or when a nearby nameplate appears.
- Get reminders for newly learned spells. WildSpark does not modify action bars automatically.
- Open settings with `/wildspark` or `/ws`.

The main WildSpark minimap button is visible by default. Separate WildBuffs and WildFire buttons are hidden by default. Existing SavedVariables and map-pin combat deferral behavior are preserved.

## Layer ID note

On WoW Forever, WildLayer reads the `zoneUID` field from nearby creature or vehicle GUIDs and shows the observed value as an **ID**, not an official numbered layer. Blizzard obfuscates GUID fields used for cross-session comparison, and the displayed ID needs in-game validation. It is not used as a destination number for hop requests. NovaWorldBuffs 3.49 disables its own layer detector on Forever, so WildLayer's own observer supplies this display. If no compatible layer list is available, you can still request any layer.

## Install

Download the ZIP above, extract it, and place the included `WildSpark` folder in the Forever client's `Interface/AddOns` directory. Disable separate WildBuffs, Camping Kit, WildAuctions, or LFGForever addons if you use their integrated WildSpark versions.

## Verification

The 1.5.10 ZIP contains the WildLayer detector, minimap label, WildLayer tab and minimap button. The observed GUID identifier still needs validation in the WoW Forever client; it is not presented as an official layer number.
