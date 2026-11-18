local _, ns = ...
local C = ns.ThemeColor

-- Obsidian, inset bronze and antique gold. Relief lives at panel edges,
-- leaving reading surfaces still and uniform. Friz is for window titles;
-- prose, controls and tactical numbers keep the shared type dimensions.
ns.DefineTheme("azeroth", {
  label = "Azeroth",
  description = "Obsidian panels, sculpted bronze edges and Warcraft-inspired titles.",
  color = {
    bg = C("1c1f23"),
    surface = C("262a2e"),
    surfaceRaised = C("30363b"),
    well = C("15191c"),
    chipBg = C("1c1f23"),
    border = C("5d564a"),
    borderAccent = C("918064"),
    controlBorder = C("a3977c"),
    overlaySelected = C("d4bc87", 0.12),
    text = C("eee6d6"),
    titleText = C("d4bc87"),
    textMuted = C("c3bdaf"),
    textDim = C("b6b3a7"),
    onAccent = C("1c1f23"),
    accent = C("d4bc87"),
    brand = C("d4bc87"),
    gold = C("d4bc87"),
    bounty = C("d4bc87"),
    dead = C("b6b3a7"),
  },
  type = {
    titleSmall = { "friz", 12 },
    title = { "friz", 16 },
    display = { "friz", 24 },
  },
  alpha = { band = 0.08, bevelLight = 0.075, bevelShade = 0.4 },
})
