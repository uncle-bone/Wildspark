local _, addonNS = ...
local HM = addonNS.WildMaps

-- Source pixels are unrotated, uncropped minimap/mosaic pixels (top-left origin).
-- Render pixels address the packaged, oriented artwork, before presentation.
-- Keep this independent of world positioning and of temporary UI geometry.
HM.MapCoordinates = {}
local Coordinates = HM.MapCoordinates

local function finite(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Map-space presentation coverage, independent of frames, padding and scale.
-- Full-artwork mode is only for the existing forced crop-calibration preview.
function Coordinates:GetPresentationRect(map, fullArtwork)
    local data = map.render
    local crop = data.presentationCrop
    if not fullArtwork and data.tileNaming ~= "blizzard_sequential" and type(crop) == "table" then
        local l, r, t, b = crop.left, crop.right, crop.top, crop.bottom
        if finite(l) and finite(r) and finite(t) and finite(b)
            and l >= 0 and r >= 0 and t >= 0 and b >= 0
            and l + r < data.width and t + b < data.height then
            return l, t, data.width - l - r, data.height - t - b, true
        end
    end
    return 0, 0, data.width, data.height, false
end

-- The single coverage gate used by automatic spatial detection, chevrons and
-- POI projection. Fractions address the retained artwork, never screen pixels.
function Coordinates:RenderedToVisibleFraction(map, x, y, fullArtwork)
    local left, top, width, height = self:GetPresentationRect(map, fullArtwork)
    if not finite(x) or not finite(y) or x < left or y < top
        or x > left + width or y > top + height then return nil end
    local u, v = (x - left) / width, (y - top) / height
    -- Match Maraudon's existing renderer-only half turn AFTER its crop.
    -- Source pixels, baked artwork orientation and coverage stay unchanged.
    if map.id == "maraudon_approach" then return 1 - u, 1 - v end
    return u, v
end

local function geometry(map)
    local r = map and map.render
    if not r then return nil end
    local sw, sh, w, h = r.sourceWidth, r.sourceHeight, r.width, r.height
    local angle = r.displayRotationDegrees or 0
    if not finite(sw) or not finite(sh) or not finite(w) or not finite(h)
        or sw <= 0 or sh <= 0 or w <= 0 or h <= 0 or not finite(angle) then return nil end
    local crop = map.processing and map.processing.postRotationCrop or {}
    local l, t = crop.cropLeftPixels or 0, crop.cropTopPixels or 0
    local right, bottom = crop.cropRightPixels or 0, crop.cropBottomPixels or 0
    if not finite(l) or not finite(t) or not finite(right) or not finite(bottom) then return nil end
    return sw, sh, w, h, angle % 360, l, t, right, bottom
end

function Coordinates:SourceToRendered(map, x, y)
    local sw, sh, w, h, angle, l, t, right, bottom = geometry(map)
    if not sw or not finite(x) or not finite(y) then return nil end
    local rx, ry
    -- Exact existing POI transforms at right angles; arbitrary angles follow
    -- Position:GetRenderedMapPixel's centered screen-space rotation (WC: 96).
    if angle == 0 then rx, ry = x, y
    elseif angle == 90 then rx, ry = y, sw - x
    elseif angle == 180 then rx, ry = sw - x, sh - y
    elseif angle == 270 then rx, ry = sh - y, x
    else
        local c, s = math.cos(math.rad(angle)), math.sin(math.rad(angle))
        local dx, dy = x - sw / 2, y - sh / 2
        rx = c * dx + s * dy + (w + l + right) / 2
        ry = -s * dx + c * dy + (h + t + bottom) / 2
    end
    rx, ry = rx - l, ry - t
    if rx < 0 or ry < 0 or rx > w or ry > h then return nil end
    return rx, ry, w, h
end

function Coordinates:RenderedToSource(map, x, y)
    local sw, sh, w, h, angle, l, t, right, bottom = geometry(map)
    if not sw or not finite(x) or not finite(y) or x < 0 or y < 0 or x > w or y > h then return nil end
    local rx, ry = x + l, y + t
    local sx, sy
    if angle == 0 then sx, sy = rx, ry
    elseif angle == 90 then sx, sy = sw - ry, rx
    elseif angle == 180 then sx, sy = sw - rx, sh - ry
    elseif angle == 270 then sx, sy = ry, sh - rx
    else
        local c, s = math.cos(math.rad(angle)), math.sin(math.rad(angle))
        local dx, dy = rx - (w + l + right) / 2, ry - (h + t + bottom) / 2
        sx = c * dx - s * dy + sw / 2
        sy = s * dx + c * dy + sh / 2
    end
    -- Reject empty corners introduced by expanded arbitrary-angle canvases.
    -- A small tolerance permits exact boundary round-trips through sin/cos.
    local epsilon = 0.000001
    if sx < -epsilon or sy < -epsilon or sx > sw + epsilon or sy > sh + epsilon then return nil end
    return math.max(0, math.min(sw, sx)), math.max(0, math.min(sh, sy))
end

-- u/v are normalized fractions of the actual fitted artwork frame. Its live
-- rect already includes maximum-contain scale, padding and centered offsets.
-- Restore permanent presentation offsets, then reverse artwork orientation.
function Coordinates:FrameFractionToSource(map, u, v)
    if not finite(u) or not finite(v) or u < 0 or v < 0 or u > 1 or v > 1 then return nil end
    -- Inverse of the same display-only turn; keep cursor/POI round trips in
    -- stable source space without changing the entrance-calibration tool.
    if map.id == "maraudon_approach" then u, v = 1 - u, 1 - v end
    local l, t, w, h = HM.Renderer:GetPresentationRect(map)
    return self:RenderedToSource(map, l + u * w, t + v * h)
end

function Coordinates:SourceToFrame(frame, map, x, y)
    local rx, ry = self:SourceToRendered(map, x, y)
    return HM.Renderer:RenderedPixelToFrame(frame, map, rx, ry)
end
