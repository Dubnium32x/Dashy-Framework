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
    self.widthrad = self.widthrad or 8
    self.heightrad = self.heightrad or 16
    
    -- Bottom sensors (for ground detection)
    self.sensors[Sensor.BOTTOM_LEFT] = {
        x = self.x - self.widthrad * 0.7,
        y = self.y + self.heightrad
    }
    self.sensors[Sensor.BOTTOM_RIGHT] = {
        x = self.x + self.widthrad * 0.7,
        y = self.y + self.heightrad
    }
    
    -- Middle sensors (for wall detection)
    self.sensors[Sensor.MIDDLE_LEFT] = {
        x = self.x - self.widthrad,
        y = self.y
    }
    self.sensors[Sensor.MIDDLE_RIGHT] = {
        x = self.x + self.widthrad,
        y = self.y
    }
    
    -- Top sensors (for ceiling detection)
    self.sensors[Sensor.TOP_LEFT] = {
        x = self.x - self.widthrad * 0.7,
        y = self.y - self.heightrad
    }
    self.sensors[Sensor.TOP_RIGHT] = {
        x = self.x + self.widthrad * 0.7,
        y = self.y - self.heightrad
    }
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
    
    -- Player dimensions
    self.widthrad = 9
    self.heightrad = 19
    
    -- Physics constants (fallbacks if not in physics object)
    self.gravity = self.physics.gravity or 0.26
    self.maxFallSpeed = self.physics.maxFallSpeed or 14.0
    self.jumpforce = 5.5
    self.groundStabilityCounter = 0
    self.framesNotGrounded = 0
    
    -- Initialize player state for collision
    self.isRolling = false
    self.rollTimer = 0
    self.canExitRoll = false
    
    -- Initialize sensors manually
    self:updateSensors()
    
    print("Player initialized at position:", self.x, self.y)
    print("Physics settings: gravity =", self.gravity, "maxFall =", self.maxFallSpeed)
end

function Player:draw(cameraX, cameraY)
    cameraX = cameraX or 0
    cameraY = cameraY or 0
    if self.image then
        self.image:draw(self.x - cameraX, self.y - cameraY)
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
        -- Calculate a parabolic-like jump curve with variable gravity
        local gravityModifier = 1.0
        
        -- When moving upward, use lighter gravity for a more gradual slowdown
        if self.yspeed < 0 then
            -- Use lighter gravity at the beginning of the jump (when speed is high)
            -- and gradually increase it as we approach the apex
            gravityModifier = 0.5 + (0.5 * (1.0 - math.min(math.abs(self.yspeed) / (self.jumpforce or 5.5), 1.0)))
            
            -- Jump height control (variable height) - apply only during first half of jump
            if not self.keyActionHeld then
                -- If player releases jump button during rise, add extra gravity
                gravityModifier = gravityModifier + 0.7  -- Makes jump cut feel more responsive
            end
        -- When falling, use slightly lower gravity for lower descent
        else
            gravityModifier = 0.8
        end
        
        -- Apply adjusted gravity
        self.yspeed = self.yspeed + self.gravity * gravityModifier
        
        -- Clamp maximum fall speed
        if self.yspeed > self.maxFallSpeed then
            self.yspeed = self.maxFallSpeed
        end
    end
    
    -- Handle jumping
    if self.grounded and self.keyActionPressed then
        -- Apply the full jump force instantly for responsive feel
        self.yspeed = -(self.jumpforce or 5.5)
        self.grounded = false
        
        -- Change state to jumping
        self.state = 13 -- PlayerState.JUMP
        
        print("Jump initiated! yspeed =", self.yspeed)
    end
    
    -- Ground movement
    if self.grounded then
        if self.keyLeft and not self.keyRight then
            -- If moving right but trying to go left, apply stronger deceleration (turn-around)
            if self.xspeed > 0 then
                self.xspeed = self.xspeed - (self.physics.deceleration or 0.08) * 2.5 -- Stronger turn-around force
            -- Normal acceleration to the left
            else
                self.xspeed = self.xspeed - (self.physics.acceleration or 0.06)
            end
            
            -- Cap maximum speed
            if self.xspeed < -(self.physics.topspeed or 6.0) then
                self.xspeed = -(self.physics.topspeed or 6.0)
            end
            
            -- Update state
            if self.state ~= 13 and self.state ~= 14 then -- Not JUMP or JUMP_FALL
                self.state = self.xspeed > 0 and 8 or 7 -- RUN if still moving right, otherwise WALK
                self.facing = -1
            end
        elseif self.keyRight and not self.keyLeft then
            -- If moving left but trying to go right, apply stronger deceleration (turn-around)
            if self.xspeed < 0 then
                self.xspeed = self.xspeed + (self.physics.deceleration or 0.08) * 2.5 -- Stronger turn-around force
            -- Normal acceleration to the right
            else
                self.xspeed = self.xspeed + (self.physics.acceleration or 0.06)
            end
            
            -- Cap maximum speed
            if self.xspeed > (self.physics.topspeed or 6.0) then
                self.xspeed = (self.physics.topspeed or 6.0)
            end
            
            -- Update state
            if self.state ~= 13 and self.state ~= 14 then -- Not JUMP or JUMP_FALL
                self.state = self.xspeed < 0 and 8 or 7 -- RUN if still moving left, otherwise WALK
                self.facing = 1
            end
        else
            -- No input - apply friction
            if self.xspeed > 0 then
                self.xspeed = self.xspeed - (self.physics.friction or 0.046875)
                if self.xspeed < 0 then self.xspeed = 0 end
            elseif self.xspeed < 0 then
                self.xspeed = self.xspeed + (self.physics.friction or 0.046875)
                if self.xspeed > 0 then self.xspeed = 0 end
            end
            
            -- Update state if virtually stopped
            if math.abs(self.xspeed) < 0.1 and self.state ~= 13 and self.state ~= 14 then
                self.state = 1 -- IDLE
            end
        end
    else
        -- Air movement - increased control with no friction
        local airControlFactor = 1.2 -- Tripled from 0.4 for more responsive air control
        
        -- In mid-air, apply turn-around effect but softer than on ground
        if self.keyLeft and not self.keyRight then
            -- If moving right but trying to go left in air, apply moderate turn-around
            if self.xspeed > 0 then
                self.xspeed = self.xspeed - (self.physics.deceleration or 0.08) * 0.8 -- Slightly reduced for less heavy feel
            -- Enhanced air acceleration for responsive control
            else
                self.xspeed = self.xspeed - (self.physics.acceleration or 0.06) * airControlFactor
            end
            
            -- Cap maximum speed
            if self.xspeed < -(self.physics.topspeed or 6.0) then
                self.xspeed = -(self.physics.topspeed or 6.0)
            end
            
            self.facing = -1
        elseif self.keyRight and not self.keyLeft then
            -- If moving left but trying to go right in air, apply moderate turn-around
            if self.xspeed < 0 then
                self.xspeed = self.xspeed + (self.physics.deceleration or 0.08) * 0.5 -- Slightly reduced for less heavy feel
            -- Enhanced air acceleration for responsive control
            else
                self.xspeed = self.xspeed + (self.physics.acceleration or 0.06) * airControlFactor
            end
            
            -- Cap maximum speed
            if self.xspeed > (self.physics.topspeed or 6.0) then
                self.xspeed = (self.physics.topspeed or 6.0)
            end
            
            self.facing = 1
        else
            -- No input in air - apply reduced friction
            if self.xspeed > 0 then
                self.xspeed = self.xspeed - (self.physics.friction or 0.046875) * 0.5 -- Reduced friction in air
                if self.xspeed < 0 then self.xspeed = 0 end
            elseif self.xspeed < 0 then
                self.xspeed = self.xspeed + (self.physics.friction or 0.046875) * 0.5 -- Reduced friction in air
                if self.xspeed > 0 then self.xspeed = 0 end
            end
        end
        
        -- Update state for jumping/falling
        if self.yspeed < 0 then
            self.state = 13 -- JUMP
        else
            self.state = 14 -- JUMP_FALL
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
        self:checkCollisions(self.level, 16)
    else
        print("No level or ground layer for collision!")
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

function Player:drawSensors()
    -- Debug: draw sensor points
    gfx.setColor(gfx.kColorBlack)
    if self.sensors then
        for _, s in pairs(self.sensors) do
            if s and s.x and s.y then
                gfx.fillCircleAtPoint(s.x, s.y, 2)
            end
        end
    end
end

function Player:checkCollisions(level, tileSize)
    -- Guard clause for nil level
    if not level then 
        print("No level provided to checkCollisions")
        return 
    end
    
    -- Import the tile collision module
    local TileCollision = import "scripts/world/tile_collision"
    
    -- Make sure width and height radii are set
    self.widthrad = self.widthrad or 8
    self.heightrad = self.heightrad or 8
    
    -- Update sensor positions
    self:updateSensors()
    
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
    local groundStabilityCounter = 0
    
    -- Get player position and velocity
    local px, py = self.x, self.y
    local vx, vy = self.xspeed, self.yspeed
    
    -- Calculate paddings for collision detection
    local horizPadding = math.min(math.abs(vx) * 0.5, self.widthrad * 0.5)
    
    -- Store previous grounded state
    local wasGrounded = self.grounded
    
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
        
        -- Clamp indices to tilemap bounds
        left = math.max(1, left)
        top = math.max(1, top)
        
        -- Check if tilemap dimensions are valid
        if #tilemap == 0 or #tilemap[1] == 0 then
            print("Empty tilemap for layer", layerName)
            goto continue
        end
        
        right = math.min(#tilemap[1], right)
        bottom = math.min(#tilemap, bottom)
        
        print("Checking tiles from", left, top, "to", right, bottom)
        
        -- Always check side collisions first
        for ty = top, bottom do
            -- Check left wall collision (right side sensor)
            if vx < 0 or (math.abs(vx) < 0.1 and self.sensors[3] and tilemap[ty]) then
                local tx = math.floor(self.sensors[3].x / tileSize) + 1
                if tx >= 1 and tx <= #tilemap[1] then
                    local tile = tilemap[ty][tx]
                    if tile and tonumber(tile) > 0 then
                        -- Left wall collision detected
                        self.x = tx * tileSize + self.widthrad + 0.1
                        self.xspeed = 0
                        print("Left wall collision at tile", tx, ty)
                    end
                end
            end
            
            -- Check right wall collision (left side sensor)
            if vx > 0 or (math.abs(vx) < 0.1 and self.sensors[4] and tilemap[ty]) then
                local tx = math.floor(self.sensors[4].x / tileSize) + 1
                if tx >= 1 and tx <= #tilemap[1] then
                    local tile = tilemap[ty][tx]
                    if tile and tonumber(tile) > 0 then
                        -- Right wall collision detected
                        self.x = (tx - 1) * tileSize - self.widthrad - 0.1
                        self.xspeed = 0
                        print("Right wall collision at tile", tx, ty)
                    end
                end
            end
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
                
                -- Check for ground collision with either sensor
                if (leftSensorTile and tonumber(leftSensorTile) > 0) or
                   (rightSensorTile and tonumber(rightSensorTile) > 0) then
                    -- Ground collision detected
                    self.y = (bottom - 1) * tileSize - self.heightrad
                    self.yspeed = 0
                    self.grounded = true
                    groundedThisFrame = true
                    print("Ground collision at position", self.x, self.y)
                    
                    -- Check for semi-solid platform
                    local isSemiSolid = string.sub(layerName, 1, 9) == "SemiSolid"
                    if isSemiSolid then
                        print("Landed on semi-solid platform")
                    end
                    
                    -- Exit this layer check since we found ground
                    break
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
                
                -- Check for ceiling collision with either sensor
                if (leftSensorTile and tonumber(leftSensorTile) > 0) or
                   (rightSensorTile and tonumber(rightSensorTile) > 0) then
                    -- Ceiling collision detected
                    self.y = top * tileSize + self.heightrad + 0.1
                    self.yspeed = 0
                    print("Ceiling collision at position", self.x, self.y)
                    break
                end
            end
        end
        
        ::continue::
    end
    
    -- Update stability counter if we found ground
    if groundedThisFrame then
        -- Set grounded to true and reset the frames not grounded counter
        self.grounded = true
        self.framesNotGrounded = 0
        
        -- Add stability counter to prevent oscillating between grounded/not grounded
        groundStabilityCounter = 3 -- Equivalent to GROUND_DEBOUNCE_FRAMES
        
        -- Change the player state if needed based on grounding
        -- self:setGroundedState()
    end
    
    -- If the player was previously grounded but is no longer grounded, increment framesNotGrounded
    if wasGrounded and not self.grounded then
        self.framesNotGrounded = (self.framesNotGrounded or 0) + 1
    elseif self.grounded then
        -- Reset counter when grounded
        self.framesNotGrounded = 0
    end
    
    -- Update sensor positions after collision resolution
    self:updateSensors()
end

_G.Player = Player
return Player
