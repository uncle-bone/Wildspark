-- LFGForever -- core/blizzardlisting.lua
-- Deliberately leave post-listing behavior to Blizzard. The user prefers to
-- keep the group finder in its normal state after creating/updating an LFG
-- listing, without WildGroups opening its panel or closing Blizzard's window.
-- Keep this load-order placeholder so the integrated module and release checks
-- continue to include the expected file.
local _, root = ...
root.WildGroups = root.WildGroups or {}
