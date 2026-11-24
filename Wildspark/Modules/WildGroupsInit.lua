-- Create WildGroups' shared namespace before its files load.
-- Every file in Modules/WildGroups/core reads root.WildGroups immediately.
local _, root = ...
root.WildGroups = root.WildGroups or {}
