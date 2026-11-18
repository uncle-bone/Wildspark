local _, ns = ...

-- Shared visual language for both clients. Positions remain per-character
-- saved settings; these values control the default panel proportions.
-- Colours come from the active theme (config/Theme.lua); these legacy names
-- are the same tables as the tokens, so they follow a theme switch.
local C = ns.ThemeTokens.color
ns.UIConfig = {
  colors = {
    panel = C.bg, surface = C.surface, border = C.border, text = C.text,
    muted = C.textMuted, accent = C.accent, warning = C.warning, danger = C.danger,
  },
  main = { width = 320, row = 34, gap = 3, padding = 8, header = 30,
    hero = 72, section = 22, footer = 22, rankWidth = 26 },
  scale = { default = 0.8, min = 0.5, max = 2, step = 0.05 },
  timers = { width = 264, row = 36, gap = 4, padding = 8, header = 30, spacing = 280 },
  flags = { row = 48 },
  -- Compact layout: one docked column, single-line rows.
  compact = {
    main = { width = 250, row = 20, gap = 1, padding = 4, header = 18, hero = 30, section = 4, footer = 4, rankWidth = 18 },
    timers = { row = 18, gap = 1, padding = 4, header = 16 },
    flags = { row = 22 },
    dockGap = 2,
  },
  -- Background opacity of every panel (Background opacity setting).
  opacity = { default = 1, min = 0, max = 1, step = 0.05 },
  map = { fontSize = 11 },
  -- Appearance settings (HighgroundDB.style). Layout values are kept per
  -- layout (normal / compact); every other choice applies to both.
  appearance = {
    panels = {
      { key = "main", label = "Main panel" },
      { key = "timers", label = "Resurrection and objectives" },
      { key = "flags", label = "Flag carriers" },
      { key = "arena", label = "Arena enemies" },
    },
    panelScale = { min = 0.5, max = 2, step = 0.05 },
    metrics = {
      { key = "width", label = "Main panel width", min = 200, max = 480, step = 10 },
      { key = "row", label = "Enemy row height", normal = { 28, 48 }, compact = { 16, 30 }, step = 1 },
      { key = "gap", label = "Row spacing", min = 0, max = 12, step = 1 },
      { key = "padding", label = "Panel padding", min = 0, max = 16, step = 1 },
      { key = "health", label = "Health bar height", min = 1, max = 12, step = 1 },
      { key = "timerWidth", label = "Timer panel width", min = 200, max = 420, step = 10, normalOnly = true },
      { key = "timerRow", label = "Timer row height", normal = { 24, 48 }, compact = { 14, 28 }, step = 1 },
      { key = "timerGap", label = "Timer row spacing", min = 0, max = 12, step = 1 },
    },
    elements = {
      { key = "rank", label = "Priority rank", desc = "1 is highest; ranks update even when rows stay in place" },
      { key = "icon", label = "Spec icon", desc = "class icon until the spec is known" },
      { key = "spec", label = "Spec text" },
      { key = "health", label = "Health bar" },
      { key = "healthText", label = "Health %", cata = true },
      { key = "mana", label = "Mana bar", desc = "mana users, once seen", cata = true },
      { key = "trinket", label = "PvP trinket", cata = true },
      { key = "status", label = "Status chip", desc = "IMMUNE, DEF, CC, BURST..." },
      { key = "distance", label = "Distance" },
      { key = "gap", label = "Priority tag", desc = "NOW: attack target; TOP: priority leader; DEAD (normal layout)" },
      { key = "allies", label = "Teammates on them", desc = "normal layout" },
    },
    fonts = {
      { key = "barlow", label = "Theme default" },
      { key = "friz", label = "Game default", file = "Fonts\\FRIZQT__.TTF" },
      { key = "arial", label = "Arial Narrow", file = "Fonts\\ARIALN.TTF" },
      { key = "skurri", label = "Skurri", file = "Fonts\\skurri.ttf" },
    },
    fontScale = { min = 0.7, max = 1.5, step = 0.05 },
    bars = {
      { key = "flat", label = "Flat", file = "Interface\\Buttons\\WHITE8x8" },
      { key = "blizzard", label = "Blizzard", file = "Interface\\TargetingFrame\\UI-StatusBar" },
      { key = "raid", label = "Raid frames", file = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    },
    -- Fill: health fills the whole enemy row, mana is a bar along its
    -- bottom. Line: thin health and mana lines along the bottom.
    healthStyles = {
      { key = "fill", label = "Fill the row" },
      { key = "line", label = "Thin line" },
    },
    barColors = {
      { key = "class", label = "Class colors" },
      { key = "faction", label = "Faction colors" },
      { key = "health", label = "Green to red" },
    },
    border = { default = 1, min = 0, max = 4, step = 1 },
    borderColors = {
      { key = "default", label = "Theme default" },
      { key = "accent", label = "Accent" },
      { key = "black", label = "Black", color = C.black },
      { key = "white", label = "White", color = C.white },
    },
  },
}
