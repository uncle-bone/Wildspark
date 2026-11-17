local _, ns = ...
local C = ns.ThemeColor

-- A persistent class surface under enemy health and content. Its strength
-- is bounded by text contrast in ui/Contrast.lua, including custom colours.
ns.DefineTheme("classcolors", {
  label = "Class Colors",
  description = "Full-row class colors for arena, nearby and battleground enemies.",
  color = {
    bg = C("0b0f14"),
    surface = C("0f141b"),
    surfaceRaised = C("1b232e"),
    well = C("080c11"),
    chipBg = C("0b0f14"),
    onAccent = C("0b0f14"),
  },
  alpha = { classRow = 0.55, healthFill = 0.08, topTint = 0.025, zebraEven = 0.01, zebraOdd = 0.015 },
})
