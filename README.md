# Wildspark

**Current build: 1.3.2 for WoW Forever 1.60.1**

Wildspark highlights nearby gathering nodes and useful world objects. It includes WildBuffs, leash helpers, and the integrated Camping Kit rebranded as **Wildfire Kit**.

## Install

1. Download the [Wildspark 1.3.2 package](https://github.com/uncle-bone/Wildspark/archive/refs/heads/main.zip).
2. Extract the archive and copy its `Wildspark/Wildspark` folder into your Forever client's `Interface/AddOns` directory.
3. Disable Lueur, the separate buff helper, and standalone Camping Kit to avoid overlapping features.
4. Enable Wildspark and reload the UI.

The full addon notes and credits are in [Wildspark/README.txt](Wildspark/README.txt).

## New spell notifications

Wildspark records the character's known spells on first login. Later learned active spells are detected and queued with a reminder. WoW Forever API research available to this build does not establish a safe addon method for editing action bars, so place new spells manually by dragging them from the spellbook to an empty action slot. Wildspark does not overwrite existing actions.

## Preserved character data

The addon retains its existing SavedVariables names and the 1.3.1 World Map camp-pin combat deferral fix. Camping Kit remains branded **Wildfire Kit** in the interface.
