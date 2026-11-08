# Wildspark

> **[Download Latest Stable — v1.3.5](https://github.com/uncle-bone/Wildspark/archive/refs/tags/v1.3.5.zip)**

**Stable release: 1.3.5 for WoW Forever 1.60.1.**

**Current build: 1.3.5 for WoW Forever 1.60.1**

Wildspark highlights nearby gathering nodes and useful world objects. It includes WildBuffs, leash helpers, and the integrated Camping Kit rebranded as **Wildfire Kit**.

## Install

1. Download the [Wildspark 1.3.5 source archive](https://github.com/uncle-bone/Wildspark/archive/refs/tags/v1.3.5.zip).
2. Extract the archive and copy its `Wildspark/Wildspark` folder into your Forever client's `Interface/AddOns` directory.
3. Disable Lueur, the separate buff helper, and standalone Camping Kit to avoid overlapping features.
4. Enable Wildspark and reload the UI.

Full addon notes and credits are in [Wildspark/README.txt](Wildspark/README.txt).

## New spell notifications

Wildspark records the character's known spells on first login. Later learned active spells are detected and queued with a reminder. WoW Forever API research available to this build does not establish a safe addon method for editing action bars, so place new spells manually by dragging them from the spellbook to an empty action slot. Wildspark does not overwrite existing actions.

Separate WildBuffs and Wildfire Kit minimap buttons are hidden by default. The main Wildspark minimap button remains visible; existing saved visibility choices are preserved.

## Herb and ore minimap icons

WoW Forever build 70862 and later no longer returns gathering-node tooltip names for simulated cursor positions. Wildspark reports this instead of running empty scans. The game's native tracking dots still work; custom replacement icons require the client to restore addon-readable simulated hover data.

## World Map camp pins

Camp pin refreshes are deferred to the next frame, outside Blizzard's secure map-provider refresh callback. The pin rebuild also waits until combat has ended before removing or acquiring pins.

## Preserved character data

Wildspark retains its existing SavedVariables names and Wildfire Kit branding.
