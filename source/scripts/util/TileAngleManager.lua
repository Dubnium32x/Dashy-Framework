-- TileAngleManager.lua
-- Manages tile angles for slope physics and collision detection
-- Uses Sonic-style angle system (0-255 hex values)

-- Try to import GamePhysics, but handle gracefully if it fails
local GamePhysics = nil
pcall(function()
    GamePhysics = import "scripts/player/game_physics"
end)

local TileAngleManager = {}

-- Tile angle definitions (in hex values, 0-255 range)
-- 0 = flat, 64 = 90 degrees, 128 = 180 degrees, 192 = 270 degrees
TileAngleManager.tileAngles = {
    [0] = 0,     -- Empty tile
    [1] = 0,     -- Half slab (bottom)
    [2] = 32,    -- 45° slope (1 by 1)
    [3] = 16,    -- 22.5° slope (2 by 1 - gentle part)
    [4] = 16,    -- 22.5° slope (2 by 1 - steep part)
    [5] = 0,     -- Full solid tile
    [6] = 48,    -- 67.5° slope (3 by 1 - steep)
    [7] = 32,    -- 45° slope (3 by 1 - medium)
    [8] = 16,    -- 22.5° slope (3 by 1 - gentle)
    [9] = 19,    -- 26.6° slope (1 by 2 - steep part, second half)
    [10] = 19,   -- 26.6° slope (1 by 2 - gentle part, first half)
    [11] = 51,   -- 71.6° slope (1 by 3 - steep)
    [12] = 32,   -- 45° slope (1 by 3 - medium)
    [13] = 13,   -- 18.4° slope (1 by 3 - gentle)
    [14] = 0,    -- Half slab (right)
    [15] = 0,    -- Half slab (bottom)
    [16] = 64,   -- Vertical wall (left side)
    [17] = 64,   -- Vertical wall (right side)
    [18] = 64,   -- Vertical wall (full)
}

-- Vertical wall definitions (for improved wall collision)
TileAngleManager.wallTiles = {
    [16] = "left",    -- Left-side vertical wall
    [17] = "right",   -- Right-side vertical wall  
    [18] = "full",    -- Full vertical wall
}

-- Height maps for different slope tiles (normalized to 16x16 tile)
TileAngleManager.heightMaps = {
    -- Tile 1: Half slab (bottom half)
    [1] = {
        8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8
    },
    
    -- Tile 2: 45° slope (1 by 1)
    [2] = {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    },
    
    -- Tile 3: 22.5° slope (2 by 1 - gentle part)
    [3] = {
        0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7
    },
    
    -- Tile 4: 22.5° slope (2 by 1 - steep part)
    [4] = {
        8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15
    },
    
    -- Tile 6: 67.5° slope (3 by 1 - steep)
    [6] = {
        0, 1, 3, 4, 6, 7, 9, 10, 12, 13, 15, 15, 15, 15, 15, 15
    },
    
    -- Tile 7: 45° slope (3 by 1 - medium) 
    [7] = {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    },
    
    -- Tile 8: 22.5° slope (3 by 1 - gentle)
    [8] = {
        0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5
    },
    
    -- Tile 9: 26.6° slope (1 by 2 - second half, rises from middle to top)
    [9] = {
        8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15
    },
    
    -- Tile 10: 26.6° slope (1 by 2 - first half, rises from bottom to middle)
    [10] = {
        0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7
    },
    
    -- Tile 11: 71.6° slope (1 by 3 - steep)
    [11] = {
        0, 1, 3, 4, 6, 7, 9, 10, 12, 13, 15, 15, 15, 15, 15, 15
    },
    
    -- Tile 12: 45° slope (1 by 3 - medium)
    [12] = {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    },
    
    -- Tile 13: 18.4° slope (1 by 3 - gentle)
    [13] = {
        0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5
    },
    
    -- Tile 14: Half slab (right side)
    [14] = {
        8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8
    },
    
    -- Tile 15: Half slab (bottom)
    [15] = {
        8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8
    },
    
    -- Vertical wall heightmaps (used for precise wall collision)
    -- Tile 16: Left-side vertical wall (right half is solid)
    [16] = {
        8, 8, 8, 8, 8, 8, 8, 8, 16, 16, 16, 16, 16, 16, 16, 16
    },
    
    -- Tile 17: Right-side vertical wall (left half is solid)  
    [17] = {
        16, 16, 16, 16, 16, 16, 16, 16, 8, 8, 8, 8, 8, 8, 8, 8
    },
    
    -- Tile 18: Full vertical wall
    [18] = {
        16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16
    },
    
    -- Add more height maps as needed for other slope tiles
}

-- Get the angle for a specific tile ID
function TileAngleManager.getTileAngle(tileId)
    return TileAngleManager.tileAngles[tileId] or 0
end

-- Get the angle in degrees for a specific tile ID
function TileAngleManager.getTileAngleDegrees(tileId)
    local hexAngle = TileAngleManager.getTileAngle(tileId)
    if hexAngle == 0 then
        return 0
    end
    
    -- Try multiple ways to access GamePhysics
    local physics = GamePhysics or _G.GamePhysics
    if physics then
        local physicsInstance = physics:new()
        return physicsInstance:angleHexToDegrees(hexAngle)
    end
    
    -- Fallback calculation if GamePhysics isn't available
    -- Convert hex angle (0-255) to degrees (0-360)
    return (hexAngle / 256) * 360
end

-- Check if a tile is a slope
function TileAngleManager.isSlope(tileId)
    local angle = TileAngleManager.getTileAngle(tileId)
    return angle ~= 0 and TileAngleManager.heightMaps[tileId] ~= nil
end

-- Check if a tile has heightmap data (slopes or partial blocks like half slabs)
function TileAngleManager.hasHeightMap(tileId)
    return TileAngleManager.heightMaps[tileId] ~= nil
end

-- Check if a tile is a vertical wall
function TileAngleManager.isWall(tileId)
    return TileAngleManager.wallTiles[tileId] ~= nil
end

-- Get wall type for a tile (left, right, full)
function TileAngleManager.getWallType(tileId)
    return TileAngleManager.wallTiles[tileId]
end

-- Check if a tile should block horizontal movement
function TileAngleManager.isHorizontalBarrier(tileId)
    -- Full tiles (ID 5), vertical walls, and any tile with full height
    return tileId == 5 or TileAngleManager.isWall(tileId) or TileAngleManager.isSteepSlope(tileId)
end

-- Check if a slope is steep enough to act like a wall (> 60 degrees)
function TileAngleManager.isSteepSlope(tileId)
    local angleDegrees = TileAngleManager.getTileAngleDegrees(tileId)
    return angleDegrees and math.abs(angleDegrees) > 60
end

-- Get slope direction (-1 for left-facing, 1 for right-facing, 0 for flat)
function TileAngleManager.getSlopeDirection(tileId)
    local angleDegrees = TileAngleManager.getTileAngleDegrees(tileId)
    if not angleDegrees or angleDegrees == 0 then
        return 0
    end
    return angleDegrees > 0 and 1 or -1
end

-- Check if a tile is a half-slab (partial height but not a slope)
function TileAngleManager.isHalfSlab(tileId)
    -- Half slabs are tiles 1, 14, and 15 in our system
    return tileId == 1 or tileId == 14 or tileId == 15
end

-- Get the effective collision height for a tile (useful for half slabs)
function TileAngleManager.getTileCollisionHeight(tileId)
    if TileAngleManager.isHalfSlab(tileId) then
        return 8 -- Half height (8 pixels out of 16)
    elseif TileAngleManager.hasHeightMap(tileId) then
        -- For slopes, return variable height (would need position)
        return 16 -- Full tile for now, use heightmap for precise collision
    elseif tileId == 5 or TileAngleManager.isWall(tileId) then
        return 16 -- Full height
    else
        return 0 -- Empty tile
    end
end

-- Get height at a specific X position within a tile
function TileAngleManager.getHeightAt(tileId, localX, tileSize)
    tileSize = tileSize or 16
    local heightMap = TileAngleManager.heightMaps[tileId]
    
    if not heightMap then
        -- Non-slope tile
        if TileAngleManager.tileAngles[tileId] == 0 then
            return tileSize - 1 -- Full height for solid tiles
        else
            return -1 -- No collision for empty tiles
        end
    end
    
    -- Clamp localX to valid range
    localX = math.max(0, math.min(tileSize - 1, math.floor(localX)))
    
    -- Scale the index for the height map (assuming 16-pixel resolution)
    local index = math.floor((localX / tileSize) * 16) + 1
    index = math.max(1, math.min(16, index))
    
    local height = heightMap[index]
    
    -- Debug output for 1x2 slopes
    if tileId == 9 or tileId == 10 then
        print("DEBUG getHeightAt: tileId:", tileId, "localX:", localX, "index:", index, "rawHeight:", height)
    end
    
    if height then
        -- Scale height back to tile size
        local scaledHeight = math.floor((height / 15) * (tileSize - 1))
        
        if tileId == 9 or tileId == 10 then
            print("DEBUG getHeightAt: scaledHeight:", scaledHeight)
        end
        
        return scaledHeight
    end
    
    return -1
end

-- Get the surface normal angle at a specific position on a slope
function TileAngleManager.getSurfaceAngle(tileId, localX)
    local baseAngle = TileAngleManager.getTileAngle(tileId)
    
    -- For now, return the base angle
    -- More sophisticated implementations could calculate varying angles
    -- based on the specific position on curved slopes
    return baseAngle
end

-- Check if player should be affected by slope physics
function TileAngleManager.shouldUseSlopePhysics(tileId, playerAngle)
    if not TileAngleManager.isSlope(tileId) then
        return false
    end
    
    local tileAngle = TileAngleManager.getTileAngle(tileId)
    local angleDiff = math.abs(tileAngle - playerAngle)
    
    -- Use slope physics if the angle difference is reasonable
    return angleDiff < 64 -- Within 90 degrees
end

-- Convert tile angle to surface normal vector
function TileAngleManager.angleToNormal(hexAngle)
    local physics = GamePhysics or _G.GamePhysics
    if physics then
        local physicsInstance = physics:new()
        
        -- Surface normal is perpendicular to the surface (add 64 to get 90 degrees)
        local normalAngle = (hexAngle + 64) % 256
        
        local normalX = physicsInstance:angleHexCos(normalAngle) / 256.0
        local normalY = physicsInstance:angleHexSin(normalAngle) / 256.0
        
        return normalX, normalY
    end
    
    -- Fallback calculation
    local radians = (hexAngle / 256) * 2 * math.pi
    return math.cos(radians), math.sin(radians)
end

-- Calculate slope force for physics
function TileAngleManager.getSlopeForce(tileId, gravityStrength)
    if not TileAngleManager.isSlope(tileId) then
        return 0, 0
    end
    
    local angle = TileAngleManager.getTileAngle(tileId)
    
    local physics = GamePhysics or _G.GamePhysics
    if physics then
        local physicsInstance = physics:new()
        
        -- Calculate the component of gravity along the slope
        local slopeForceX = physicsInstance:angleHexSin(angle) * gravityStrength / 256.0
        local slopeForceY = physicsInstance:angleHexCos(angle) * gravityStrength / 256.0
        
        return slopeForceX, slopeForceY
    end
    
    -- Fallback calculation using standard math
    local radians = (angle / 256) * 2 * math.pi
    local slopeForceX = math.sin(radians) * gravityStrength
    local slopeForceY = math.cos(radians) * gravityStrength
    return slopeForceX, slopeForceY
end

return TileAngleManager