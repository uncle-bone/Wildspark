# WildSpark

> **[Download Here](https://github.com/uncle-bone/Wildspark/releases/latest/download/WildSpark-1.4.5.zip)**

**Current build: 1.4.5 for WoW Forever 1.60.1.** (GitHub source sync; installable release ZIP is available in this conversation.)

WildSpark highlights nearby gathering nodes and useful world objects. It includes WildBuffs, leash helpers, the integrated Camping Kit rebranded as **Wildfire Kit**, and WildAuctions, a bag item selector attached to the Auction House Sell tab. WildAuctions loads an item into Blizzard's Sell form and never posts it automatically.

## Install

Download the latest release ZIP from the button above, extract it, and place the included `WildSpark` folder in your Forever client's `Interface/AddOns` directory. Disable Lueur, separate buff helpers, and standalone Camping Kit to avoid overlapping features.

Full addon notes and credits are in [WildSpark/README.txt](WildSpark/README.txt).

## WildAuctions

WildAuctions lists unbound items carried in bags while the Sell tab is open. Clicking an item selects it and fills the available quantity in Blizzard's sell form. It does not scan AH listings, display price tooltips, or post auctions.

## New spell notifications

WildSpark queues newly learned active spells with a reminder. WoW Forever API research available to this build does not establish a safe addon method for editing action bars, so place new spells manually from the spellbook. Existing actions are not overwritten.

WildBuffs and Wildfire Kit minimap buttons are hidden by default; the main WildSpark minimap button remains visible. Saved-variable names and Wildfire Kit branding are preserved.
