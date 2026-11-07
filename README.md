# Wildspark

**Current build: 1.3.3 for WoW Forever 1.60.1**

Wildspark highlights nearby gathering nodes and useful world objects. It includes WildBuffs, leash helpers, and the integrated Camping Kit rebranded as **Wildfire Kit**.

## Install

1. Download the [Wildspark 1.3.3 source archive](https://github.com/uncle-bone/Wildspark/archive/refs/heads/main.zip).
2. Extract the archive and copy its `Wildspark/Wildspark` folder into your Forever client's `Interface/AddOns` directory.
3. Disable Lueur, the separate buff helper, and standalone Camping Kit to avoid overlapping features.
4. Enable Wildspark and reload the UI.

Full addon notes and credits are in [Wildspark/README.txt](Wildspark/README.txt).

## New spell notifications

Wildspark records the character's known spells on first login. Later learned active spells are detected and queued with a reminder. WoW Forever API research available to this build does not establish a safe addon method for editing action bars, so place new spells manually by dragging them from the spellbook to an empty action slot. Wildspark does not overwrite existing actions.

## World Map camp pins

Camp pin refreshes are deferred to the next frame, outside Blizzard's secure map-provider refresh callback. The pin rebuild also waits until combat has ended before removing or acquiring pins.

## Preserved character data

Wildspark retains its existing SavedVariables names and Wildfire Kit branding.
