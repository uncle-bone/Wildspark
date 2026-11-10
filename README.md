# WildSpark

> **[Download WildSpark 1.4.7](https://github.com/uncle-bone/Wildspark/releases/latest/download/WildSpark-1.4.7.zip)**

**Current build: 1.4.7 for WoW Forever 1.60.1.** The release workflow packages the installable `WildSpark` addon folder and verifies its version metadata.

WildSpark highlights nearby gathering nodes and useful world objects. It includes WildBuffs, leash helpers, the integrated Camping Kit rebranded as **Wildfire Kit**, WildAuctions, **WildResources**, and the background **ForeverLootRollMover** module. WildAuctions loads an item into Blizzard's Sell form and never posts it automatically.

## Install

Download and extract the ZIP. Place the included `WildSpark` folder in your Forever client's `Interface/AddOns` directory. Disable Lueur, separate buff helpers, and standalone Camping Kit to avoid overlapping features.

Full addon notes and credits are in [WildSpark/README.txt](Wildspark/README.txt).

## WildResources

WildResources is a movable class resource and cooldown tracker. It enumerates power types the running client exposes, watches learned active spellbook entries, and displays the active specialization name when the client API makes it available. Unrecognized resource IDs are shown numerically instead of being assigned an assumed Retail or Classic name. Open its settings under Options > AddOns > WildResources, or use `/wildresources` (`/wr`) in game. It does not cast spells or edit action bars.

The module is designed for all classes and follows live spellbook, power, and talent changes. WoW Forever-specific power IDs and specialization APIs still need in-client verification; this build does not claim a client test has been completed.

## ForeverLootRollMover

ForeverLootRollMover runs as a background module with its default Edit Mode positioning behavior and the existing `/flrm` commands. Its SavedVariables name is preserved.

## Existing WildSpark features

WildSpark highlights gathering nodes and interactable objects, shows tracked herbs and ore on the minimap, and retains WildBuffs, leash helpers, Wildfire Kit, and WildAuctions. WildAuctions never posts an auction automatically.

Newly learned active spells are queued for manual placement. The WoW Forever API research available to this build does not establish a safe addon method for editing action bars.

WildBuffs and Wildfire Kit minimap buttons remain hidden by default; the main WildSpark minimap button remains visible. Existing SavedVariables names and the map-pin combat deferral fix are preserved.
