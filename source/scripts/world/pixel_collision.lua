-- pixel_collision.lua
-- Handles pixel-perfect collision detection for tiles

local pd <const> = playdate
local gfx <const> = pd.graphics

local PixelCollision = {}

-- Cache for tile images to avoid reloading
local tileImageCache = {}

-- Helper function to get a tile image from cache or load it
function PixelCollision.getTileImage(tileset, tileId)
    local cacheKey = tostring(tileset) .. "_" .. tostring(tileId)
    
    if not tileImageCache[cacheKey] then
        -- Load the tile image and cache it
        tileImageCache[cacheKey] = tileset:getImage(tileId)
    end
    
    return tileImageCache[cacheKey]
end

-- Check if a point collides with an opaque pixel in a tile
function PixelCollision.checkPixelCollision(tileset, tileId, localX, localY)
    if not tileset or not tileId or tileId <= 0 then
        print("PixelCollision: Invalid parameters - tileset:", tileset, "tileId:", tileId)
        return false
    end
    
    -- Get the tile image
    local tileImage = PixelCollision.getTileImage(tileset, tileId)
    if not tileImage then
        print("PixelCollision: Failed to get tile image for tileId:", tileId)
        return false
    end
    
    -- Make sure coordinates are within bounds
    if localX < 0 or localX >= tileImage:getSize() or
       localY < 0 or localY >= tileImage:getSize() then
        print("PixelCollision: Coordinates out of bounds - localX:", localX, "localY:", localY, "size:", tileImage:getSize())
        return false
    end
    
    -- On Playdate, we can use the sample method to check if a pixel is opaque
    local alpha = tileImage:sample(localX, localY)
    
    -- In Playdate 1-bit graphics, alpha is either 0 (transparent) or 1 (opaque)
    local result = alpha > 0
    if result then
        print("PixelCollision: Collision detected at", localX, localY, "in tile", tileId)
    end
    return result
end

-- Check collision between a sensor point and a tile with pixel precision
function PixelCollision.checkSensorPixelCollision(tileset, tileId, sensorX, sensorY, tileX, tileY, tileSize)
    -- Calculate local coordinates within the tile
    local localX = math.floor(sensorX - tileX * tileSize)
    local localY = math.floor(sensorY - tileY * tileSize)
    
    print("Checking sensor collision at:", sensorX, sensorY, "tile:", tileX, tileY, 
          "local coords:", localX, localY)
    
    -- Check if the local coordinates are within the tile bounds
    if localX < 0 or localX >= tileSize or localY < 0 or localY >= tileSize then
        print("Sensor coords outside tile bounds")
        return false
    end
    
    -- Check pixel collision
    return PixelCollision.checkPixelCollision(tileset, tileId, localX, localY)
end

return PixelCollision
