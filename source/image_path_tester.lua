-- image_path_tester.lua
-- Tests loading image tables from different paths

import "CoreLibs/graphics"
import "CoreLibs/timer"

local pd <const> = playdate
local gfx <const> = pd.graphics

-- Try different image paths to determine which one works
local function tryLoadImageTable(path)
    print("Trying to load image table from path: " .. path)
    local imageTable = gfx.imagetable.new(path)
    if imageTable then
        print("SUCCESS: Image table loaded from " .. path)
        print("  Number of images: " .. imageTable:getLength())
        return imageTable
    else
        print("FAILED: Could not load image table from " .. path)
        return nil
    end
end

local paths = {
    "sprites/tileset/SPGSolidTileHeightCollision_flipped-table-16-16",
    "source/sprites/tileset/SPGSolidTileHeightCollision_flipped-table-16-16",
    "/sprites/tileset/SPGSolidTileHeightCollision_flipped-table-16-16",
    "/source/sprites/tileset/SPGSolidTileHeightCollision_flipped-table-16-16",
    "SPGSolidTileHeightCollision_flipped-table-16-16"
}

local currentPath = 1
local loadedImageTable = nil
local testStarted = false

function playdate.update()
    if not testStarted then
        testStarted = true
        print("Current directory: " .. pd.file.getWorkingDirectory())
        print("Starting image path tests...")
    end
    
    if currentPath <= #paths and not loadedImageTable then
        loadedImageTable = tryLoadImageTable(paths[currentPath])
        currentPath = currentPath + 1
        if not loadedImageTable then
            -- Wait a bit before trying the next path
            pd.timer.performAfterDelay(500, function() loadedImageTable = nil end)
        end
    end
    
    gfx.clear()
    
    if loadedImageTable then
        -- Draw the first image from the table
        local img = loadedImageTable:getImage(1)
        if img then
            img:draw(200, 120)
            gfx.drawText("Image loaded successfully from path #" .. (currentPath-1), 10, 10)
            gfx.drawText("Path: " .. paths[currentPath-1], 10, 30)
        end
    else
        if currentPath <= #paths then
            gfx.drawText("Testing path " .. currentPath .. "/" .. #paths, 10, 10)
            gfx.drawText(paths[currentPath], 10, 30)
        else
            gfx.drawText("All paths failed! Check console for details.", 10, 10)
        end
    end
    
    -- Draw working directory
    gfx.drawText("Working dir: " .. pd.file.getWorkingDirectory(), 10, 200)
    
    pd.drawFPS(380, 10)
end
