local _, ns = ...
local C = ns.ThemeColor

-- Smoked charcoal and brushed copper. Red is reserved for danger, never
-- used as the frame or action colour. Body type stays the shared weight.
ns.DefineTheme("ember", {
  label = "Ember",
  description = "Smoked charcoal with soft copper highlights.",
  color = {
    bg = C("211c1b"),
    surface = C("2c2522"),
    surfaceRaised = C("372f2b"),
    well = C("191615"),
    chipBg = C("211c1b"),
    border = C("5c4d43"),
    borderAccent = C("8c7060"),
    controlBorder = C("a39486"),
    overlaySelected = C("d6ad8e", 0.12),
    text = C("eee5dd"),
    titleText = C("eee5dd"),
    textMuted = C("c5b8ad"),
    textDim = C("baad9f"),
    onAccent = C("211c1b"),
    accent = C("d6ad8e"),
    brand = C("d6ad8e"),
    gold = C("dbc395"),
    bounty = C("dbc395"),
    dead = C("baad9f"),
  },
})
