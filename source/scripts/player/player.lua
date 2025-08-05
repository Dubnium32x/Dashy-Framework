-- player.lua

-- Import the CoreLibs modules for essential functionalities
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "extensions/AnimatedSprite"

local pd <const> = playdate
local gfx <const> = pd.graphics

local GamePhysics = import "scripts/player/game_physics"
local var = import "scripts/player/var"
local TileCollision = import "scripts/world/tile_collision"
local TileAngleManager = import "scripts/util/TileAngleManager"
-- Import PixelCollision at the global level to prevent scope issues
_G.PixelCollision = import "scripts/world/pixel_collision"

-- Player state enums
local PlayerState = {
    IDLE = 1,
    IMPATIENT = 2,
    IDLE_BALANCE_F = 3,
    IDLE_BALANCE_B = 4,
    CROUCH = 5,
    LOOK_UP = 6,
    WALK = 7,
    RUN = 8,
    DASH = 9,
    PEELOUT = 10,
    SPINDASH_CHARGE = 11,
    ROLL = 12,
    JUMP = 13,
    JUMP_FALL = 14,
    FALLING = 15,
    HURT = 16,
    DEAD = 17,
    SPINNING = 18
}

local Character = {
    Sonic,
    Amy,
    Honey
}

local KeyDefine = {
    LEFT = playdate.kButtonLeft,
    RIGHT = playdate.kButtonRight,
    UP = playdate.kButtonUp,
    DOWN = playdate.kButtonDown,
    ACTION = playdate.kButtonA,
    ACTION2 = playdate.kButtonB
}

local Sensor = {
    BOTTOM_LEFT = 1,
    BOTTOM_RIGHT = 2,
    MIDDLE_LEFT = 3,
    MIDDLE_RIGHT = 4,
    TOP_LEFT = 5,
    TOP_RIGHT = 6
}

-- Shorthand for the graphics modules and playdate specific functions
local pd <const> = playdate
local gfx <const> = pd.graphics


local Player = {
    image = nil,
    x = 0,
    y = 0
}
Player.__index = Player


function Player:new(spriteSheetPath, frameWidth, frameHeight, startX, startY)
    local obj = setmetatable({}, self)
    self.__index = self
    -- Initialization code here
    self.var = var
    self.physics = GamePhysics:new()
    -- PixelCollision is available globally

    -- DEBUG
    print("Player.new() called with spriteSheetPath: " .. tostring(spriteSheetPath))

    -- Load the player static image
    self.image = gfx.image.new(tostring(spriteSheetPath))
    assert(self.image, "Failed to load player image! Check file path and format.")
    self.x = startX
    self.y = startY

    -- Initialize player state
    self.xspeed = 0
    self.yspeed = 0
    self.grounded = false
    self.rings = 0
    self.lives = 3
    self.score = 0
    self.facing = 1 -- 1 for right, -1 for left
    self.startTime = playdate.getCurrentTimeMilliseconds()

    -- Initialize player Character
    self.character = Character.Sonic -- Default character
    self.state = PlayerState.IDLE

    return obj
end

function Player:updateSensors()
    -- Initialize sensors array if needed
    if not self.sensors then
        self.sensors = {}
    end
    
    -- Make sure width and height radii are properly set
    self.widthrad = self.widthrad or 14  -- Default to half sprite width
    self.heightrad = self.heightrad or 20 -- Default to half sprite height
    
    -- Bottom sensors (for ground detection) - positioned at the feet
    self.sensors[Sensor.BOTTOM_LEFT] = {
        x = self.x - self.widthrad * 0.8,  -- Further out for better edge detection
        y = self.y + self.heightrad
    }
    self.sensors[Sensor.BOTTOM_RIGHT] = {
        x = self.x + self.widthrad * 0.8,  -- Further out for better edge detection
        y = self.y + self.heightrad
    }
    
    -- Middle sensors (for wall detection) - positioned at the center of the body sides
    self.sensors[Sensor.MIDDLE_LEFT] = {
        x = self.x - self.widthrad,
        y = self.y
    }
    self.sensors[Sensor.MIDDLE_RIGHT] = {
        x = self.x + self.widthrad,
        y = self.y
    }
    
    -- Top sensors (for ceiling detection) - positioned at the head
    self.sensors[Sensor.TOP_LEFT] = {
        x = self.x - self.widthrad * 0.7,  -- Adjusted for better ceiling detection
        y = self.y - self.heightrad
    }
    self.sensors[Sensor.TOP_RIGHT] = {
        x = self.x + self.widthrad * 0.7,  -- Adjusted for better ceiling detection
        y = self.y - self.heightrad
    }
end

function Player:checkCsvCollisions(level, tileSize)
    -- Pixel-perfect CSV collision logic
    -- Use sensors and tileset image for accurate collision checks
    local tilesetPath = "source/sprites/tileset/DF-Simple-Collision-table-16-16"
    if not self.collisionTileset then
        self.collisionTileset = gfx.imagetable.new(tilesetPath)
        if not self.collisionTileset then
            print("WARNING: Failed to load collision tileset at " .. tilesetPath)
            -- Try alternate paths
            self.collisionTileset = gfx.imagetable.new("sprites/tileset/DF-Simple-Collision-table-16-16")
            if not self.collisionTileset then
                self.collisionTileset = gfx.imagetable.new("DF-Simple-Collision-table-16-16")
            end
            if not self.collisionTileset then
                print("ERROR: Could not load tileset from any path!")
                return
            else
                print("SUCCESS: Loaded tileset from alternate path")
            end
        else
            print("SUCCESS: Loaded tileset from primary path")
        end
    end
    local tileset = self.collisionTileset

    local layersToCheck = {
        { data = level.csv_ground1, name = "Ground1" },
        { data = level.csv_ground2, name = "Ground2" },
        { data = level.csv_ground3, name = "Ground3" },
        { data = level.csv_semisolid1, name = "SemiSolid1" },
        { data = level.csv_semisolid2, name = "SemiSolid2" },
        { data = level.csv_semisolid3, name = "SemiSolid3" }
    }

    local px, py = self.x, self.y
    local vx, vy = self.xspeed, self.yspeed
    local wasGrounded = self.grounded
    local groundedThisFrame = false

    -- print("DEBUG: Player position:", px, py, "velocity:", vx, vy, "grounded:", self.grounded)

    -- Only check pixel-perfect collision for CSV layers
    for _, layer in ipairs(layersToCheck) do
        local tilemap = layer.data
        local layerName = layer.name
        if not tilemap then 
            -- print("DEBUG: Layer", layerName, "has no data")
            goto continue 
        end
        
        -- print("DEBUG: Checking layer", layerName, "with", #tilemap, "rows")
        local left = math.floor((px - self.widthrad - math.abs(vx)) / tileSize) + 1
        local right = math.floor((px + self.widthrad + math.abs(vx)) / tileSize) + 1
        local top = math.floor((py - self.heightrad - math.abs(vy)) / tileSize) + 1
        local bottom = math.floor((py + self.heightrad + math.abs(vy)) / tileSize) + 1
        left = math.max(1, left)
        top = math.max(1, top)
        local mapHeight = #tilemap
        local mapWidth = #tilemap[1]
        right = math.min(mapWidth, right)
        bottom = math.min(mapHeight, bottom)

        -- Wall collisions (left/right)
        for ty = top, bottom do
            if ty == top or ty == bottom then goto continue_walls end
            -- Left wall
            if self.sensors[Sensor.MIDDLE_LEFT] and tilemap[ty] then
                local tx = math.floor(self.sensors[Sensor.MIDDLE_LEFT].x / tileSize) + 1
                if tx >= 1 and tx <= mapWidth then
                    local tile = tilemap[ty][tx]
                    if tile and tonumber(tile) > 0 then
                        local tileId = tonumber(tile)
                        
                        -- Check if this tile should block horizontal movement
                        local isBarrier = TileAngleManager.isHorizontalBarrier(tileId)
                        local wallType = TileAngleManager.getWallType(tileId)
                        
                        -- Skip if it's a right-side wall and we're hitting from the left
                        if wallType == "right" then goto skip_left_wall end
                        
                        local hasPixelCollision = PixelCollision.checkSensorPixelCollision(
                            tileset,
                            tileId + 1,
                            self.sensors[Sensor.MIDDLE_LEFT].x,
                            self.sensors[Sensor.MIDDLE_LEFT].y,
                            tx - 1,
                            ty - 1,
                            tileSize
                        )
                        -- print("Left wall: tileId="..tostring(tileId).." barrier="..tostring(isBarrier).." pixelCollision="..tostring(hasPixelCollision))
                        
                        if (hasPixelCollision or isBarrier) and self.xspeed <= 0 then
                            self.x = tx * tileSize + self.widthrad + 0.1
                            self.xspeed = 0
                        end
                        ::skip_left_wall::
                    end
                end
            end
            -- Right wall
            if self.sensors[Sensor.MIDDLE_RIGHT] and tilemap[ty] then
                local tx = math.floor(self.sensors[Sensor.MIDDLE_RIGHT].x / tileSize) + 1
                if tx >= 1 and tx <= mapWidth then
                    local tile = tilemap[ty][tx]
                    if tile and tonumber(tile) > 0 then
                        local tileId = tonumber(tile)
                        
                        -- Check if this tile should block horizontal movement
                        local isBarrier = TileAngleManager.isHorizontalBarrier(tileId)
                        local wallType = TileAngleManager.getWallType(tileId)
                        
                        -- Skip if it's a left-side wall and we're hitting from the right
                        if wallType == "left" then goto skip_right_wall end
                        
                        local hasPixelCollision = PixelCollision.checkSensorPixelCollision(
                            tileset,
                            tileId + 1,
                            self.sensors[Sensor.MIDDLE_RIGHT].x,
                            self.sensors[Sensor.MIDDLE_RIGHT].y,
                            tx - 1,
                            ty - 1,
                            tileSize
                        )
                        -- print("Right wall: tileId="..tostring(tileId).." barrier="..tostring(isBarrier).." pixelCollision="..tostring(hasPixelCollision))
                        
                        if (hasPixelCollision or isBarrier) and self.xspeed >= 0 then
                            self.x = (tx - 1) * tileSize - self.widthrad - 0.1
                            self.xspeed = 0
                        end
                        ::skip_right_wall::
                    end
                end
            end
            ::continue_walls::
        end

        -- Ground/ceiling collisions with slope support
        -- Ground collision (falling onto ground or slopes)
        if vy >= 0 and self.sensors[1] and self.sensors[2] and tilemap[bottom] then
            local leftSensorX = math.floor(self.sensors[1].x / tileSize) + 1
            local rightSensorX = math.floor(self.sensors[2].x / tileSize) + 1
            
            -- print("DEBUG: Checking ground collision at bottom row", bottom)
            -- print("DEBUG: Left sensor X:", leftSensorX, "Right sensor X:", rightSensorX)
            
            local leftSensorTile = (leftSensorX >= 1 and leftSensorX <= mapWidth) and tilemap[bottom][leftSensorX] or nil
            local rightSensorTile = (rightSensorX >= 1 and rightSensorX <= mapWidth) and tilemap[bottom][rightSensorX] or nil
            
            -- print("DEBUG: Left tile:", leftSensorTile, "Right tile:", rightSensorTile)
            
            local leftTileCollision = leftSensorTile and tonumber(leftSensorTile) > 0
            local rightTileCollision = rightSensorTile and tonumber(rightSensorTile) > 0
            
            -- Check for slope collision using heightmaps
            local groundHeight = nil
            local groundTileId = nil
            local groundAngle = 0
            
            if leftTileCollision or rightTileCollision then
                -- Determine which sensor to use (prefer the one that's closer to collision)
                local primarySensor = nil
                local primaryTileId = nil
                local primaryTileX = nil
                
                if leftTileCollision and rightTileCollision then
                    -- Both sensors are on tiles, choose based on Y position or use left sensor
                    primarySensor = self.sensors[1]
                    primaryTileId = tonumber(leftSensorTile)
                    primaryTileX = leftSensorX
                elseif leftTileCollision then
                    primarySensor = self.sensors[1]
                    primaryTileId = tonumber(leftSensorTile)
                    primaryTileX = leftSensorX
                elseif rightTileCollision then
                    primarySensor = self.sensors[2]
                    primaryTileId = tonumber(rightSensorTile)
                    primaryTileX = rightSensorX
                end
                
                if primarySensor and primaryTileId then
                    -- Calculate local X position within the tile
                    local localX = primarySensor.x - ((primaryTileX - 1) * tileSize)
                    
                    -- Get height from heightmap if available, otherwise use tile-based collision
                    if TileAngleManager.hasHeightMap(primaryTileId) then
                        local isSlope = TileAngleManager.isSlope(primaryTileId)
                        
                        -- Debug output for 1x2 slopes specifically
                        if primaryTileId == 9 or primaryTileId == 10 then
                            print("DEBUG 1x2: Tile ID:", primaryTileId, "localX:", localX, "playerY:", self.y, "sensorY:", primarySensor.y)
                        end
                        
                        -- Store current tile for debug display
                        _G.debugTileId = primaryTileId
                        
                        groundHeight = TileAngleManager.getHeightAt(primaryTileId, localX, tileSize)
                        groundAngle = TileAngleManager.getTileAngle(primaryTileId)
                        
                        if groundHeight >= 0 then
                            -- Calculate precise Y position based on heightmap
                            local tileTopY = (bottom - 1) * tileSize
                            local preciseGroundY = tileTopY + (tileSize - 1 - groundHeight)
                            
                            -- More robust collision check - allow a larger tolerance for steep slopes
                            local tolerance = 8 -- pixels (increased further for 1x2 slope debugging)
                            
                            -- Debug output for 1x2 slopes specifically
                            if primaryTileId == 9 or primaryTileId == 10 then
                                print("DEBUG 1x2: groundHeight:", groundHeight, "tileTopY:", tileTopY, "preciseGroundY:", preciseGroundY, "tolerance:", tolerance)
                            end
                            
                            if primarySensor.y >= (preciseGroundY - tolerance) then
                                self.y = preciseGroundY - self.heightrad
                                self.yspeed = 0
                                self.grounded = true
                                groundedThisFrame = true
                                groundTileId = primaryTileId
                                
                                if primaryTileId == 9 or primaryTileId == 10 then
                                    print("DEBUG 1x2: COLLISION! New player Y:", self.y, "angle:", groundAngle)
                                end
                            else
                                if primaryTileId == 9 or primaryTileId == 10 then
                                    print("DEBUG 1x2: NO COLLISION - sensor too high. Sensor Y:", primarySensor.y, "needed:", (preciseGroundY - tolerance))
                                end
                            end
                        end
                    else
                        -- Regular flat tile collision
                        -- print("DEBUG: Flat tile collision")
                        self.y = (bottom - 1) * tileSize - self.heightrad - 0.1
                        self.yspeed = 0
                        self.grounded = true
                        groundedThisFrame = true
                        groundTileId = primaryTileId
                    end
                end
            end
            
            -- Store ground properties for physics
            self.groundAngle = groundAngle
            self.groundTileId = groundTileId
        end
        -- Ceiling collision (jumping and hitting ceiling)
        if vy < 0 and self.sensors[5] and self.sensors[6] and tilemap[top] then
            local leftSensorX = math.floor(self.sensors[5].x / tileSize) + 1
            local rightSensorX = math.floor(self.sensors[6].x / tileSize) + 1
            local leftSensorTile = tilemap[top][leftSensorX]
            local rightSensorTile = tilemap[top][rightSensorX]
            local leftTileCollision = leftSensorTile and tonumber(leftSensorTile) > 0
            local rightTileCollision = rightSensorTile and tonumber(rightSensorTile) > 0
            local hasPixelCollision = false
            if leftTileCollision then
                local leftTileId = tonumber(leftSensorTile)
                local leftPixelCollision = PixelCollision.checkSensorPixelCollision(
                    tileset,
                    leftTileId + 1,
                    self.sensors[5].x,
                    self.sensors[5].y,
                    leftSensorX - 1,
                    top - 1,
                    tileSize
                )
                print("Ceiling left: tileId="..tostring(leftTileId).." pixelCollision="..tostring(leftPixelCollision))
                if leftPixelCollision then hasPixelCollision = true end
            end
            if rightTileCollision then
                local rightTileId = tonumber(rightSensorTile)
                local rightPixelCollision = PixelCollision.checkSensorPixelCollision(
                    tileset,
                    rightTileId + 1,
                    self.sensors[6].x,
                    self.sensors[6].y,
                    rightSensorX - 1,
                    top - 1,
                    tileSize
                )
                print("Ceiling right: tileId="..tostring(rightTileId).." pixelCollision="..tostring(rightPixelCollision))
                if rightPixelCollision then hasPixelCollision = true end
            end
            if hasPixelCollision then
                self.y = top * tileSize + self.heightrad + 0.1
                self.yspeed = 0
            elseif leftTileCollision or rightTileCollision then
                -- Fallback: tile-based collision
                self.y = top * tileSize + self.heightrad + 0.1
                self.yspeed = 0
                print("Fallback: tile-based ceiling collision")
            end
        end
        ::continue::
    end

    -- Update grounded state and stability counter
    if groundedThisFrame then
        self.grounded = true
        self.framesNotGrounded = 0
        self.groundStabilityCounter = self.groundStabilityMax or 8
        self.yspeed = 0
        if math.abs(self.xspeed) > 3.0 then
            self.state = PlayerState.RUN
        elseif math.abs(self.xspeed) > 0.5 then
            self.state = PlayerState.WALK
        else
            self.state = PlayerState.IDLE
        end
    else
        if self.groundStabilityCounter > 0 then
            self.groundStabilityCounter = self.groundStabilityCounter - 1
            if self.groundStabilityCounter > 0 then
                self.grounded = true
            end
        else
            self.grounded = false
            -- Clear ground properties when airborne
            self.groundAngle = 0
            self.groundTileId = nil
        end
    end
    if wasGrounded and not self.grounded then
        self.framesNotGrounded = (self.framesNotGrounded or 0) + 1
        if self.framesNotGrounded <= self.groundedToleranceFrames then
            self.grounded = true
        else
            -- Clear ground properties when truly airborne
            self.groundAngle = 0
            self.groundTileId = nil
        end
    elseif self.grounded then
        self.framesNotGrounded = 0
    end
    self:updateSensors()
end

function Player:init()
    -- Initialize sprite with animations
    local states = {
        { name = "idle", frames = {1}, loop = true },
        { name = "walk", frames = {2,3,4,5}, loop = true },
        { name = "run", frames = {2,3,4,5}, loop = true }, -- Reuse walk frames for now
        { name = "jump", frames = {1}, loop = false },
        { name = "jump_fall", frames = {1}, loop = false },
        { name = "falling", frames = {1}, loop = false }
        -- Add other states as needed
    }
    self.sprite = AnimatedSprite:new(self.image, states)
    self.sprite:moveTo(self.x, self.y)
    self.sprite:setScale(1.0)
    
    -- Play the initial idle animation directly
    self.sprite:playAnimation("idle")
    
    -- Initialize sensors
    self.sensors = {}
    
    -- Set physics properties using GamePhysics
    if not self.physics then
        self.physics = GamePhysics:new()
    end
    
    -- Player dimensions - set to match sprite dimensions (29x40 divided by 2)
    self.widthrad = 14  -- Half of 29 (rounded down)
    self.heightrad = 20 -- Half of 40
    
    -- Physics constants (fallbacks if not in physics object)
    self.gravity = self.physics.gravity or 0.3125
    self.maxFallSpeed = self.physics.maxFallSpeed or 14.0
    self.jumpforce = 6.0 -- Consistent with var.jumpforce
    self.groundStabilityCounter = 0
    self.framesNotGrounded = 0
    
    -- Initialize player state for collision
    self.isRolling = false
    self.rollTimer = 0
    self.canExitRoll = false
    
    -- Initialize ground stability system - prevent single frame air states
    self.groundStabilityCounter = 0
    self.groundStabilityMax = 8 -- Increased to prevent "in air" flashes
    self.framesNotGrounded = 0
    self.groundedToleranceFrames = 3 -- Allow this many frames of being "ungrounded" before truly being in air
    
    -- Initialize slope/ground properties
    self.groundAngle = 0 -- Current ground angle (in hex format 0-255)
    self.groundTileId = nil -- Current ground tile ID for slope physics
    
    -- Initialize sensors manually
    self:updateSensors()
    
    print("Player initialized at position:", self.x, self.y)
    print("Physics settings: gravity =", self.gravity, "maxFall =", self.maxFallSpeed)
end

function Player:draw(cameraX, cameraY)
    cameraX = cameraX or 0
    cameraY = cameraY or 0
    if self.image then
        self.image:drawCentered(self.x - cameraX, self.y - cameraY)
    end
end

function Player:setSprite(sprite)
    if not sprite then
        print("Warning: setSprite called with nil sprite")
        return
    end

    -- Try to play animation based on state, with fallback
    local success = false
    
    if self.state == PlayerState.IDLE then 
        success = sprite:playAnimation("idle")
    elseif self.state == PlayerState.IMPATIENT then 
        success = sprite:playAnimation("impatient") 
    elseif self.state == PlayerState.IDLE_BALANCE_F then 
        success = sprite:playAnimation("idle_balance_f")
    elseif self.state == PlayerState.IDLE_BALANCE_B then 
        success = sprite:playAnimation("idle_balance_b")
    elseif self.state == PlayerState.CROUCH then 
        success = sprite:playAnimation("crouch")
    elseif self.state == PlayerState.LOOK_UP then 
        success = sprite:playAnimation("look_up")
    elseif self.state == PlayerState.WALK then 
        success = sprite:playAnimation("walk")
    elseif self.state == PlayerState.RUN then 
        success = sprite:playAnimation("run")
    elseif self.state == PlayerState.DASH then 
        success = sprite:playAnimation("dash")
    elseif self.state == PlayerState.PEELOUT then 
        success = sprite:playAnimation("peelout")
    elseif self.state == PlayerState.SPINDASH_CHARGE then 
        success = sprite:playAnimation("spindash_charge")
    elseif self.state == PlayerState.ROLL then 
        success = sprite:playAnimation("roll")
    elseif self.state == PlayerState.JUMP then 
        success = sprite:playAnimation("jump")
    elseif self.state == PlayerState.JUMP_FALL then 
        success = sprite:playAnimation("jump_fall")
    elseif self.state == PlayerState.FALLING then 
        success = sprite:playAnimation("falling")
    elseif self.state == PlayerState.HURT then 
        success = sprite:playAnimation("hurt")
    elseif self.state == PlayerState.DEAD then 
        success = sprite:playAnimation("dead")
    elseif self.state == PlayerState.SPINNING then 
        success = sprite:playAnimation("spinning")
    end
    
    -- Default to idle if no animation matched or if previous attempt failed
    if not success then
        sprite:playAnimation("idle")
    end
end

function Player:processInput()
    self.keyLeft = playdate.buttonIsPressed(KeyDefine.LEFT)
    self.keyRight = playdate.buttonIsPressed(KeyDefine.RIGHT)
    self.keyUp = playdate.buttonIsPressed(KeyDefine.UP)
    self.keyDown = playdate.buttonIsPressed(KeyDefine.DOWN)
    self.keyActionPressed = playdate.buttonJustPressed(KeyDefine.ACTION)
    self.keyActionHeld = playdate.buttonIsPressed(KeyDefine.ACTION)
    self.keyAction2Pressed = playdate.buttonJustPressed(KeyDefine.ACTION2)
end

function Player:update()
    self:processInput()
    
    -- Store previous position for collision
    local prevX, prevY = self.x, self.y
    
    -- Apply variable gravity based on jump state
    if not self.grounded then
        local gravityValue = self.physics.gravity or 0.3125
        
        -- Apply sonic-style jump physics
        if self.yspeed < 0 and self.keyActionHeld then
            -- Lower gravity when holding jump button during ascent (but less reduction)
            self.yspeed = self.yspeed + gravityValue * 0.85
        else
            -- Regular gravity otherwise
            self.yspeed = self.yspeed + gravityValue
        end
        
        -- Clamp maximum fall speed
        if self.yspeed > self.physics.maxFallSpeed then
            self.yspeed = self.physics.maxFallSpeed
        end
    end
    
    -- Handle jumping - use the jumpforce property
    if self.grounded and self.keyActionPressed then
        -- Apply jump force
        self.yspeed = -self.jumpforce
        self.grounded = false
        
        -- Change state to jumping
        self.state = PlayerState.JUMP
        
        -- Clear ground stability counter
        self.groundStabilityCounter = 0
        
        print("Jump initiated! yspeed =", self.yspeed, "jumpforce =", self.jumpforce)
    end
    
    -- Ground movement
    if self.grounded then
        -- Get physics values
        local acc = self.physics.acceleration or 0.046875
        local dec = self.physics.deceleration or 0.5
        local fric = self.physics.friction or 0.046875
        local top = self.physics.topspeed or 6.0
        
        if self.keyLeft and not self.keyRight then
            -- If moving right but trying to go left, apply deceleration (turn-around)
            if self.xspeed > 0 then
                self.xspeed = self.xspeed - dec
                -- If deceleration would reverse direction, stop at 0
                if self.xspeed < 0 then self.xspeed = 0 end
            -- Normal acceleration to the left
            else
                self.xspeed = self.xspeed - acc
                -- Cap maximum speed
                if self.xspeed < -top then
                    self.xspeed = -top
                end
            end
            
            -- Update state and facing
            if self.state ~= PlayerState.JUMP and self.state ~= PlayerState.JUMP_FALL then
                if math.abs(self.xspeed) > 3.0 then
                    self.state = PlayerState.RUN -- Higher speed = run
                else
                    self.state = PlayerState.WALK -- Lower speed = walk
                end
                self.facing = -1
            end
        elseif self.keyRight and not self.keyLeft then
            -- If moving left but trying to go right, apply deceleration (turn-around)
            if self.xspeed < 0 then
                self.xspeed = self.xspeed + dec
                -- If deceleration would reverse direction, stop at 0
                if self.xspeed > 0 then self.xspeed = 0 end
            -- Normal acceleration to the right
            else
                self.xspeed = self.xspeed + acc
                -- Cap maximum speed
                if self.xspeed > top then
                    self.xspeed = top
                end
            end
            
            -- Update state and facing
            if self.state ~= PlayerState.JUMP and self.state ~= PlayerState.JUMP_FALL then
                if math.abs(self.xspeed) > 3.0 then
                    self.state = PlayerState.RUN -- Higher speed = run
                else
                    self.state = PlayerState.WALK -- Lower speed = walk
                end
                self.facing = 1
            end
        else
            -- No input - apply friction
            if math.abs(self.xspeed) > fric then
                if self.xspeed > 0 then
                    self.xspeed = self.xspeed - fric
                else
                    self.xspeed = self.xspeed + fric
                end
            else
                -- If speed is very low, just stop completely
                self.xspeed = 0
            end
            
            -- Update state if virtually stopped
            if math.abs(self.xspeed) < 0.1 and self.state ~= PlayerState.JUMP and self.state ~= PlayerState.JUMP_FALL then
                self.state = PlayerState.IDLE
            end
        end
        
        -- Apply slope physics when grounded
        if self.groundTileId and TileAngleManager.isSlope(self.groundTileId) then
            local slopeForceX, slopeForceY = TileAngleManager.getSlopeForce(self.groundTileId, self.physics.gravity or 0.3125)
            
            -- Enhanced Sonic-style slope influence
            local groundAngleDegrees = TileAngleManager.getTileAngleDegrees(self.groundTileId) or 0
            local slopeInfluence = 0.125 -- Base slope influence factor (0.125 in Sonic games)
            
            -- Increase influence on steeper slopes
            local angleFactor = math.abs(groundAngleDegrees) / 45.0 -- Normalize to 45 degree reference
            slopeInfluence = slopeInfluence * (1.0 + angleFactor * 0.5)
            
            -- Apply slope force based on ground angle
            if groundAngleDegrees > 0 then
                -- Downward slope (right side lower) - accelerate to the right when going down
                if self.xspeed >= 0 then
                    self.xspeed = self.xspeed + slopeInfluence
                else
                    -- Going uphill - apply more resistance
                    self.xspeed = self.xspeed + slopeInfluence * 0.5
                end
            elseif groundAngleDegrees < 0 then
                -- Upward slope (left side lower) - accelerate to the left when going down  
                if self.xspeed <= 0 then
                    self.xspeed = self.xspeed - slopeInfluence
                else
                    -- Going uphill - apply more resistance
                    self.xspeed = self.xspeed - slopeInfluence * 0.5
                end
            end
            
            -- Cap speed based on slope angle - steeper slopes allow higher speeds
            local slopeSpeedMultiplier = 1.0 + (angleFactor * 0.3)
            local maxSlopeSpeed = (self.physics.topspeed or 6.0) * slopeSpeedMultiplier
            if self.xspeed > maxSlopeSpeed then
                self.xspeed = maxSlopeSpeed
            elseif self.xspeed < -maxSlopeSpeed then
                self.xspeed = -maxSlopeSpeed
            end
            
            -- If moving too slowly uphill on steep slopes, slide back down (Sonic mechanic)
            if math.abs(groundAngleDegrees) > 35 and math.abs(self.xspeed) < 2.0 then
                local slideForce = slopeInfluence * 2.0
                if groundAngleDegrees > 0 then
                    self.xspeed = self.xspeed + slideForce -- Slide right on right-facing slopes
                else
                    self.xspeed = self.xspeed - slideForce -- Slide left on left-facing slopes
                end
            end
            
            -- print("DEBUG: Enhanced slope physics - angle:", groundAngleDegrees, "influence:", slopeInfluence, "xspeed:", self.xspeed)
        end
    else
        -- Air movement - according to Sonic Physics Guide
        local airAcc = 0.09375 -- Air acceleration (0.09375 per frame in Sonic games)
        local airTopSpeed = self.physics.topspeed or 6.0 -- Same as ground top speed
        
        if self.keyLeft and not self.keyRight then
            -- Apply air acceleration to the left
            self.xspeed = self.xspeed - airAcc
            
            -- Cap maximum speed
            if self.xspeed < -airTopSpeed then
                self.xspeed = -airTopSpeed
            end
            
            self.facing = -1
        elseif self.keyRight and not self.keyLeft then
            -- Apply air acceleration to the right
            self.xspeed = self.xspeed + airAcc
            
            -- Cap maximum speed
            if self.xspeed > airTopSpeed then
                self.xspeed = airTopSpeed
            end
            
            self.facing = 1
        end
        
        -- Update state for jumping/falling
        if self.yspeed < 0 then
            self.state = PlayerState.JUMP
        else
            self.state = PlayerState.JUMP_FALL
        end
    end
    
    -- Apply movement
    self.x = self.x + self.xspeed
    self.y = self.y + self.yspeed
    
    -- Update sensor positions after movement but before collision
    self:updateSensors()
    
    -- Check for and resolve collisions
    if self.level and (self.level.csv_ground1 or self.level.csv_semisolid1) then
        print("Checking collisions at:", self.x, self.y)
        local useCsvLevel = self.level and (self.level.csv_ground1 or self.level.csv_semisolid1)
        if useCsvLevel then
            print("Checking collisions at:", self.x, self.y)
            self:checkCsvCollisions(self.level, 16)
        else
            -- Only run horizontal/vertical checks if not using CSV
            if self.checkCollisions then
                self:checkCollisions(self.level, 16)
            end
        end

    end
    -- Update sensor positions again after collision resolution
    self:updateSensors()
    
    -- Update sprite animation based on state (safely)
    if self.sprite then
        -- Set the animation based on player state
        if self.state == PlayerState.IDLE then 
            self.sprite:playAnimation("idle")
        elseif self.state == PlayerState.WALK or self.state == PlayerState.RUN then 
            self.sprite:playAnimation("walk")
        elseif self.state == PlayerState.JUMP then
            self.sprite:playAnimation("jump")
        elseif self.state == PlayerState.JUMP_FALL or self.state == PlayerState.FALLING then
            self.sprite:playAnimation("jump_fall")
        else
            -- Default to idle if animation not available
            self.sprite:playAnimation("idle")
        end
        
        -- Update sprite position
        self.sprite:moveTo(self.x, self.y)
        
        -- Update sprite facing direction if supported
        if self.sprite.setScale then
            self.sprite:setScale(self.facing, 1) -- Flip sprite based on facing direction
        end
    end
    
    -- Store ground speed for reference (useful for loops and slopes later)
    self.groundspeed = self.xspeed
end

function Player:drawSensors(cameraX, cameraY)
    -- Default camera values if not provided
    cameraY = cameraY or 0
    
    -- Set NXOR drawing mode for better text visibility
    gfx.setImageDrawMode(gfx.kDrawModeNXOR)
    
    -- Draw player bounding box
    gfx.drawRect(self.x - self.widthrad - cameraX, self.y - self.heightrad - cameraY, 
                self.widthrad * 2, self.heightrad * 2)
                
    -- Draw minimal debug text to reduce rendering overhead
    gfx.drawText("Status: " .. (self.grounded and "GROUNDED" or "IN AIR"), 10, 80)
    gfx.drawText(string.format("Pos: %.1f, %.1f", self.x, self.y), 10, 100)
    gfx.drawText(string.format("Speed: %.1f, %.1f", self.xspeed, self.yspeed), 10, 120)
    
    -- Draw slope information
    if self.groundTileId and self.grounded then
        gfx.drawText("Ground Tile: " .. tostring(self.groundTileId), 10, 160)
        gfx.drawText("Ground Angle: " .. tostring(self.groundAngle), 10, 180)
        if TileAngleManager.isSlope(self.groundTileId) then
            local degrees = TileAngleManager.getTileAngleDegrees(self.groundTileId)
            gfx.drawText("Slope: " .. string.format("%.1f°", degrees), 10, 200)
        end
    end
    
    -- Draw current state name (compact)
    local stateNames = {
        [1] = "IDLE", [2] = "IMPATIENT", [3] = "I_BAL_F", [4] = "I_BAL_B",
        [5] = "CROUCH", [6] = "LOOK_UP", [7] = "WALK", [8] = "RUN",
        [9] = "DASH", [10] = "PEELOUT", [11] = "SDASH", [12] = "ROLL",
        [13] = "JUMP", [14] = "J_FALL", [15] = "FALL", [16] = "HURT",
        [17] = "DEAD", [18] = "SPIN"
    }
    local stateName = stateNames[self.state] or "?"
    gfx.drawText("State: " .. stateName, 10, 140)
    
    -- Don't draw lives here, as it's handled by the HUD module
    
    -- Only draw sensor points if specifically requested with a flag
    if _G.DRAW_DETAILED_SENSORS then
        if self.sensors then
            for i, s in pairs(self.sensors) do
                if s and s.x and s.y then
                    -- Just draw simple points for all sensors
                    gfx.fillCircleAtPoint(s.x - cameraX, s.y - cameraY, 2)
                end
            end
        end
    end
    
    -- Reset to normal drawing mode
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Player:checkCollisions(level, tileSize)
    -- Guard clause for nil level
    if not level then 
        print("No level provided to checkCollisions")
        return 
    end
    
    -- Make sure width and height radii are set
    self.widthrad = self.widthrad or 14  -- Default to half sprite width
    self.heightrad = self.heightrad or 20 -- Default to half sprite height
    
    -- Update sensor positions
    self:updateSensors()
    
    -- Use cached tileset if available, or load it once
    if not self.collisionTileset then
        -- Try different path formats until one works
        self.collisionTileset = gfx.imagetable.new("sprites/tileset/DF-Simple-Collision-table-16-16")
        
        -- If still not loaded, try alternate paths
        if not self.collisionTileset then
            self.collisionTileset = gfx.imagetable.new("source/sprites/tileset/DF-Simple-Collision-table-16-16")
        end
        
        -- If still not loaded, try just the filename
        if not self.collisionTileset then
            self.collisionTileset = gfx.imagetable.new("DF-Simple-Collision-table-16-16")
        end
        
        -- Final check
        if not self.collisionTileset then
            print("WARNING: Failed to load collision tileset! Tried multiple paths.")
            print("Current directory: " .. pd.file.getWorkingDirectory())
            
            -- Create a simple placeholder tileset for debugging
            local placeholderImg = gfx.image.new(16, 16)
            gfx.pushContext(placeholderImg)
            gfx.drawRect(0, 0, 16, 16)
            gfx.drawLine(0, 0, 16, 16)
            gfx.drawLine(16, 0, 0, 16)
            gfx.popContext()
            
            -- Create a simple table with just this one image
            self.collisionTileset = {
                getImage = function(_, index)
                    return placeholderImg
                end,
                drawImage = function(_, index, x, y)
                    placeholderImg:draw(x, y)
                end
            }
        end
    end
    
    -- Use the cached tileset for collision detection
    local tileset = self.collisionTileset
    
    -- Define the layers we want to check for collisions
    local layersToCheck = {
        { data = level.csv_ground1, name = "Ground1" },
        { data = level.csv_ground2, name = "Ground2" },
        { data = level.csv_ground3, name = "Ground3" },
        { data = level.csv_semisolid1, name = "SemiSolid1" },
        { data = level.csv_semisolid2, name = "SemiSolid2" },
        { data = level.csv_semisolid3, name = "SemiSolid3" }
    }
    
    -- Define collision variables
    local wasGrounded = self.grounded
    local groundedThisFrame = false
    
    -- Store the class-level stability counter or initialize it
    local groundStabilityCounter = self.groundStabilityCounter or 0
    
    -- Get player position and velocity
    local px, py = self.x, self.y
    local vx, vy = self.xspeed, self.yspeed
    
    -- Calculate paddings for collision detection
    local horizPadding = math.min(math.abs(vx) * 0.5, self.widthrad * 0.5)
    
    -- Reset grounded state conditionally
    if groundStabilityCounter <= 0 then
        self.grounded = false
    else
        groundStabilityCounter = groundStabilityCounter - 1
    end
    
    print("Checking collisions at position:", px, py, "with velocity:", vx, vy)
    
    -- Check each layer for collisions
    for _, layer in ipairs(layersToCheck) do
        local tilemap = layer.data
        local layerName = layer.name
        
        if not tilemap then
            print("Layer", layerName, "not found")
            goto continue
        end
        
        -- Calculate tile indices overlapped by player
        -- Add padding based on velocity for more accurate collision detection
        local left = math.floor((px - self.widthrad - math.abs(vx)) / tileSize) + 1
        local right = math.floor((px + self.widthrad + math.abs(vx)) / tileSize) + 1
        local top = math.floor((py - self.heightrad - math.abs(vy)) / tileSize) + 1
        local bottom = math.floor((py + self.heightrad + math.abs(vy)) / tileSize) + 1
        
        -- Clamp indices to tilemap bounds and ensure they're valid
        left = math.max(1, left)
        top = math.max(1, top)
        
        -- Check if tilemap dimensions are valid
        if type(tilemap) ~= "table" or #tilemap == 0 then
            print("Empty tilemap for layer", layerName)
            goto continue
        end
        
        -- Make sure we have at least one row
        if not tilemap[1] or type(tilemap[1]) ~= "table" then
            print("Invalid tilemap row data for layer", layerName)
            goto continue
        end
        
        -- Get dimensions and clamp indices
        local mapHeight = #tilemap
        local mapWidth = #tilemap[1]
        
        right = math.min(mapWidth, right)
        bottom = math.min(mapHeight, bottom)
        
        print("Checking tiles from", left, top, "to", right, bottom, "in layer", layerName)
        
        -- Always check side collisions first
        for ty = top, bottom do
            -- Skip ceiling/floor rows to prevent false positives
            if ty == top or ty == bottom then
                goto continue_walls
            end
            
            -- Check left wall collision (using middle left sensor)
            if self.sensors[Sensor.MIDDLE_LEFT] and tilemap[ty] then
                local tx = math.floor(self.sensors[Sensor.MIDDLE_LEFT].x / tileSize) + 1
                if tx >= 1 and tx <= #tilemap[1] then
                    local tile = tilemap[ty][tx]
                    if tile and tonumber(tile) > 0 then
                        local tileId = tonumber(tile)
                        local hasPixelCollision = true -- Default to true for tile-based collision
                        
                        -- If tileset exists, check for pixel-perfect collision
                        if tileset then
                            print("Checking pixel collision for middle left sensor at tile", tx, ty)
                            hasPixelCollision = PixelCollision.checkSensorPixelCollision(
                                tileset,
                                tileId + 1, -- Lua indexing adjustment
                                self.sensors[Sensor.MIDDLE_LEFT].x,
                                self.sensors[Sensor.MIDDLE_LEFT].y,
                                tx - 1,
                                ty - 1,
                                tileSize
                            )
                            print("Result of pixel collision check:", hasPixelCollision)
                        end
                        
                        -- Left wall collision detected - only resolve if moving left and pixel collision exists
                        if hasPixelCollision and self.xspeed <= 0 then
                            self.x = tx * tileSize + self.widthrad + 0.1
                            self.xspeed = 0
                            print("Left wall collision at tile", tx, ty)
                        end
                    end
                end
            end
            
            -- Check right wall collision (using middle right sensor)
            if self.sensors[Sensor.MIDDLE_RIGHT] and tilemap[ty] then
                local tx = math.floor(self.sensors[Sensor.MIDDLE_RIGHT].x / tileSize) + 1
                if tx >= 1 and tx <= #tilemap[1] then
                    local tile = tilemap[ty][tx]
                    if tile and tonumber(tile) > 0 then
                        local tileId = tonumber(tile)
                        local hasPixelCollision = true -- Default to true for tile-based collision
                        
                        -- If tileset exists, check for pixel-perfect collision
                        if tileset then
                            hasPixelCollision = PixelCollision.checkSensorPixelCollision(
                                tileset,
                                tileId + 1, -- Lua indexing adjustment
                                self.sensors[Sensor.MIDDLE_RIGHT].x,
                                self.sensors[Sensor.MIDDLE_RIGHT].y,
                                tx - 1,
                                ty - 1,
                                tileSize
                            )
                        end
                        
                        -- Right wall collision detected - only resolve if moving right and pixel collision exists
                        if hasPixelCollision and self.xspeed >= 0 then
                            self.x = (tx - 1) * tileSize - self.widthrad - 0.1
                            self.xspeed = 0
                            print("Right wall collision at tile", tx, ty)
                        end
                    end
                end
            end
            
            ::continue_walls::
        end
        
        -- Now check bottom sensors for ground collision
        for tx = left, right do
            -- Ground collision (falling onto ground)
            if vy >= 0 and self.sensors[1] and self.sensors[2] and tilemap[bottom] then
                local leftSensorTile = nil
                local rightSensorTile = nil
                
                -- Get the tiles under the bottom sensors
                local leftSensorX = math.floor(self.sensors[1].x / tileSize) + 1
                local rightSensorX = math.floor(self.sensors[2].x / tileSize) + 1
                
                if leftSensorX >= 1 and leftSensorX <= #tilemap[1] then
                    leftSensorTile = tilemap[bottom][leftSensorX]
                end
                
                if rightSensorX >= 1 and rightSensorX <= #tilemap[1] then
                    rightSensorTile = tilemap[bottom][rightSensorX]
                end
                
                -- First check for tile-level collision
                local leftTileCollision = leftSensorTile and tonumber(leftSensorTile) > 0
                local rightTileCollision = rightSensorTile and tonumber(rightSensorTile) > 0
                
                -- If tiles exist, perform pixel-perfect collision check
                if leftTileCollision or rightTileCollision then
                    local hasPixelCollision = false
                    
                    -- Check left sensor for pixel collision
                    if leftTileCollision and tileset then
                        local leftTileId = tonumber(leftSensorTile)
                        local leftPixelCollision = PixelCollision.checkSensorPixelCollision(
                            tileset, 
                            leftTileId + 1, -- Lua indexing adjustment
                            self.sensors[1].x, 
                            self.sensors[1].y,
                            leftSensorX - 1, 
                            bottom - 1, 
                            tileSize
                        )
                        if leftPixelCollision then
                            hasPixelCollision = true
                        end
                    end
                    
                    -- Check right sensor for pixel collision
                    if rightTileCollision and tileset then
                        local rightTileId = tonumber(rightSensorTile)
                        local rightPixelCollision = PixelCollision.checkSensorPixelCollision(
                            tileset, 
                            rightTileId + 1, -- Lua indexing adjustment
                            self.sensors[2].x, 
                            self.sensors[2].y,
                            rightSensorX - 1, 
                            bottom - 1, 
                            tileSize
                        )
                        if rightPixelCollision then
                            hasPixelCollision = true
                        end
                    end
                    
                    -- If we have a collision with solid pixels, handle it
                    if hasPixelCollision or (not tileset) then -- Fallback to tile-based if no tileset
                        -- Ground collision detected - position player precisely on top of the ground
                        self.y = (bottom - 1) * tileSize - self.heightrad - 0.1
                        self.yspeed = 0
                        self.grounded = true
                        groundedThisFrame = true
                        
                        print("Ground collision at position", self.x, self.y, 
                              "Left tile:", leftSensorTile, "Right tile:", rightSensorTile)
                        
                        -- Check for semi-solid platform
                        local isSemiSolid = string.sub(layerName, 1, 9) == "SemiSolid"
                        if isSemiSolid then
                            print("Landed on semi-solid platform")
                        end
                        
                        -- Important: Don't break here, continue checking all tiles
                        -- This prevents falling through narrow platforms
                    end
                end
            end
            
            -- Ceiling collision (jumping and hitting ceiling)
            if vy < 0 and self.sensors[5] and self.sensors[6] and tilemap[top] then
                local leftSensorTile = nil
                local rightSensorTile = nil
                
                -- Get the tiles above the top sensors
                local leftSensorX = math.floor(self.sensors[5].x / tileSize) + 1
                local rightSensorX = math.floor(self.sensors[6].x / tileSize) + 1
                
                if leftSensorX >= 1 and leftSensorX <= #tilemap[1] then
                    leftSensorTile = tilemap[top][leftSensorX]
                end
                
                if rightSensorX >= 1 and rightSensorX <= #tilemap[1] then
                    rightSensorTile = tilemap[top][rightSensorX]
                end
                
                -- First check for tile-level collision
                local leftTileCollision = leftSensorTile and tonumber(leftSensorTile) > 0
                local rightTileCollision = rightSensorTile and tonumber(rightSensorTile) > 0
                
                -- If tiles exist, perform pixel-perfect collision check
                if leftTileCollision or rightTileCollision then
                    local hasPixelCollision = false
                    
                    -- Check left sensor for pixel collision
                    if leftTileCollision and tileset then
                        local leftTileId = tonumber(leftSensorTile)
                        local leftPixelCollision = PixelCollision.checkSensorPixelCollision(
                            tileset, 
                            leftTileId + 1, -- Lua indexing adjustment
                            self.sensors[5].x, 
                            self.sensors[5].y,
                            leftSensorX - 1, 
                            top - 1, 
                            tileSize
                        )
                        if leftPixelCollision then
                            hasPixelCollision = true
                        end
                    end
                    
                    -- Check right sensor for pixel collision
                    if rightTileCollision and tileset then
                        local rightTileId = tonumber(rightSensorTile)
                        local rightPixelCollision = PixelCollision.checkSensorPixelCollision(
                            tileset, 
                            rightTileId + 1, -- Lua indexing adjustment
                            self.sensors[6].x, 
                            self.sensors[6].y,
                            rightSensorX - 1, 
                            top - 1, 
                            tileSize
                        )
                        if rightPixelCollision then
                            hasPixelCollision = true
                        end
                    end
                    
                    -- If we have a collision with solid pixels, handle it
                    if hasPixelCollision or (not tileset) then -- Fallback to tile-based if no tileset
                        -- Ceiling collision detected
                        self.y = top * tileSize + self.heightrad + 0.1
                        self.yspeed = 0
                        print("Ceiling collision at position", self.x, self.y)
                        break
                    end
                end
            end
        end
        
        ::continue::
    end
    
    -- Update stability counter and handle grounding
    if groundedThisFrame then
        -- Set grounded to true and reset the frames not grounded counter
        self.grounded = true
        self.framesNotGrounded = 0
        
        -- Add stability counter to prevent oscillating between grounded/not grounded
        -- Always keep the stability counter at maximum while grounded
        self.groundStabilityCounter = self.groundStabilityMax or 8
        
        -- Set vertical speed to 0 when landing
        self.yspeed = 0
        
        -- Change the player state if needed based on grounding
        if math.abs(self.xspeed) > 3.0 then
            self.state = PlayerState.RUN
        elseif math.abs(self.xspeed) > 0.5 then
            self.state = PlayerState.WALK
        else
            self.state = PlayerState.IDLE
        end
    else
        -- If not grounded this frame, decrement the stability counter
        if self.groundStabilityCounter > 0 then
            self.groundStabilityCounter = self.groundStabilityCounter - 1
            
            -- If stability counter is still active, we're still grounded
            -- This creates a buffer to prevent one-frame losses of ground state
            if self.groundStabilityCounter > 0 then
                self.grounded = true
            end
        else
            -- If stability counter runs out, we're no longer grounded
            self.grounded = false
        end
    end
    
    -- If the player was previously grounded but is no longer grounded, use tolerance frames
    if wasGrounded and not self.grounded then
        self.framesNotGrounded = (self.framesNotGrounded or 0) + 1
        
        -- Still consider the player grounded within the tolerance window
        -- This prevents single-frame "in air" states
        if self.framesNotGrounded <= self.groundedToleranceFrames then
            self.grounded = true
        end
    elseif self.grounded then
        -- Reset counter when grounded
        self.framesNotGrounded = 0
    end
    
    -- Update sensor positions after collision resolution
    self:updateSensors()
end

_G.Player = Player
return Player
