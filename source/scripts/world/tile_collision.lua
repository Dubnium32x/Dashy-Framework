-- tile_collision.lua
-- Ported from Presto-Framework D code to Playdate Lua

local TileCollision = {}

-- Tile flip constants
TileCollision.FLIPPED_HORIZONTALLY_FLAG = 0x80000000
TileCollision.FLIPPED_VERTICALLY_FLAG = 0x40000000
TileCollision.FLIPPED_DIAGONALLY_FLAG = 0x20000000
TileCollision.FLIPPED_ALL_FLAGS_MASK = (
    TileCollision.FLIPPED_HORIZONTALLY_FLAG
    | TileCollision.FLIPPED_VERTICALLY_FLAG
    | TileCollision.FLIPPED_DIAGONALLY_FLAG
)
-- Define the TileHeightProfile class (struct equivalent)
TileCollision.TileHeightProfile = {}
TileCollision.TileHeightProfile.__index = TileCollision.TileHeightProfile

function TileCollision.TileHeightProfile.new(heights, solid, platform)
    local self = setmetatable({}, TileCollision.TileHeightProfile)
    self.groundHeights = heights or {} -- Array of 16 height values
    self.isFullySolidBlock = solid or false
    self.isPlatform = platform or false
    return self
end

-- Static factory for an empty/non-collidable tile profile
function TileCollision.TileHeightProfile.empty()
    local heights = {}
    for i = 1, 16 do
        heights[i] = -1 -- No ground
    end
    return TileCollision.TileHeightProfile.new(heights, false, false)
end

-- Static factory for a full solid block
function TileCollision.TileHeightProfile.solidBlock()
    local heights = {}
    for i = 1, 16 do
        heights[i] = 15 -- Max height (full block)
    end
    return TileCollision.TileHeightProfile.new(heights, true, false)
end

-- Static factory for a custom height array
function TileCollision.TileHeightProfile.custom(heights, platform)
    platform = platform or false
    -- Determine if it's a full block based on custom heights
    local solid = true
    for _, h in ipairs(heights) do
        if h ~= 15 then
            solid = false
            break
        end
    end
    return TileCollision.TileHeightProfile.new(heights, solid, platform)
end

-- Extract the actual tile ID from a raw tile ID by removing flip/rotation flags
function TileCollision.getActualTileId(rawTileId)
    if rawTileId == -1 then return -1 end -- Empty tile
    return rawTileId & (~TileCollision.FLIPPED_ALL_FLAGS_MASK)
end
-- Check if a tile is empty (either -1 or 0)
function TileCollision.isEmptyTile(tileId)
    return tileId == -1 or tileId == 0
end

-- Function to get the height profile for a given tile ID and layer
function TileCollision.getTileHeightProfile(rawTileId, layerName)
    layerName = layerName or ""
    local actualTileId = TileCollision.getActualTileId(rawTileId)
    
    -- Only tile IDs -1 and 0 are non-collidable
    if actualTileId == -1 or actualTileId == 0 then
        return TileCollision.TileHeightProfile.empty()
    end

    -- For semi-solid layers, all non-empty tiles are platforms
    local isSemiSolidLayer = string.sub(layerName, 1, 9) == "SemiSolid"
    if isSemiSolidLayer then
        local platformHeights = {15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15}
        return TileCollision.TileHeightProfile.new(platformHeights, false, true)
    end

    -- Define specific tile types with special collision profiles
    -- Note: Adjust these tile IDs based on your actual tileset
    if actualTileId == 4 then
        -- 45° slope rising from left to right (/)
        return TileCollision.TileHeightProfile.custom({0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15})
    elseif actualTileId == 5 then
        -- 45° slope rising from right to left (\)
        return TileCollision.TileHeightProfile.custom({15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0})
    elseif actualTileId == 6 then
        -- Gentle up-slope from left to right
        return TileCollision.TileHeightProfile.custom({0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7})
    elseif actualTileId == 7 then
        -- Gentle up-slope from right to left
        return TileCollision.TileHeightProfile.custom({7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 0, 0})
    else
        -- ALL other tile IDs (except -1 and 0) are collidable by default as solid blocks
        return TileCollision.TileHeightProfile.solidBlock()
    end
end

-- Checks if a tile position can be a semi-solid top
function TileCollision.isSemiSolidTop(rawTileId, rawTileIdAbove, layerName)
    -- Only process SemiSolid layers
    local isSemiSolidLayer = string.sub(layerName or "", 1, 9) == "SemiSolid"
    if not isSemiSolidLayer then return false end
    
    local actualTileId = TileCollision.getActualTileId(rawTileId)
    local actualTileIdAbove = TileCollision.getActualTileId(rawTileIdAbove)
    
    -- If the current tile is not empty and the one above is empty, it's a semi-solid top
    return not TileCollision.isEmptyTile(actualTileId) and TileCollision.isEmptyTile(actualTileIdAbove)
end

return TileCollision