-- file_system_tester.lua
-- Script to explore the Playdate file system and understand path handling

import "CoreLibs/graphics"

local pd <const> = playdate
local gfx <const> = pd.graphics

local workingDir = pd.file.getWorkingDirectory()
local files = {}
local currentDir = "."
local scrollOffset = 0

-- Try to list files in a directory
local function listDir(dir)
    print("Listing directory: " .. dir)
    local items, err = pd.file.listFiles(dir)
    
    if items then
        files = {}
        local index = 1
        
        -- Add parent directory entry
        if dir ~= "." then
            table.insert(files, { name = "..", isDir = true })
        end
        
        -- Add all directory items
        for i=1, #items do
            local name = items[i]
            local path = dir .. "/" .. name
            local info = pd.file.getStats(path)
            
            table.insert(files, { 
                name = name,
                isDir = info and info.isDirectory or false,
                size = info and info.size or 0
            })
        end
        
        return true
    else
        print("Error listing directory: " .. tostring(err))
        return false
    end
end

-- Initialize by listing root directory
listDir(currentDir)

function playdate.update()
    gfx.clear()
    
    -- Draw directory info
    gfx.drawText("Current directory: " .. currentDir, 5, 5)
    gfx.drawText("Working directory: " .. workingDir, 5, 20)
    
    -- Draw file listing
    local y = 40
    for i = 1 + scrollOffset, math.min(#files, 10 + scrollOffset) do
        local item = files[i]
        local prefix = item.isDir and "[DIR] " or "[FILE] "
        local sizeInfo = item.isDir and "" or string.format(" (%d bytes)", item.size)
        gfx.drawText(prefix .. item.name .. sizeInfo, 10, y)
        y = y + 15
    end
    
    -- Draw navigation help
    gfx.drawText("↑/↓: Scroll  A: Enter Dir  B: Parent Dir", 10, 220)
    
    pd.drawFPS(380, 5)
end

-- Handle input
function playdate.upButtonDown()
    if scrollOffset > 0 then
        scrollOffset = scrollOffset - 1
    end
end

function playdate.downButtonDown()
    if scrollOffset < #files - 10 then
        scrollOffset = scrollOffset + 1
    end
end

function playdate.AButtonDown()
    local selectedIndex = 1 + scrollOffset
    if selectedIndex <= #files then
        local selected = files[selectedIndex]
        if selected.isDir then
            if selected.name == ".." then
                -- Go to parent directory
                local parts = {}
                for part in string.gmatch(currentDir, "[^/]+") do
                    table.insert(parts, part)
                end
                if #parts > 1 then
                    table.remove(parts) -- Remove last part
                    currentDir = table.concat(parts, "/")
                else
                    currentDir = "."
                end
            else
                -- Enter this directory
                if currentDir == "." then
                    currentDir = selected.name
                else
                    currentDir = currentDir .. "/" .. selected.name
                end
            end
            
            listDir(currentDir)
            scrollOffset = 0
        end
    end
end

function playdate.BButtonDown()
    -- Go to parent directory
    if currentDir ~= "." then
        local parts = {}
        for part in string.gmatch(currentDir, "[^/]+") do
            table.insert(parts, part)
        end
        if #parts > 1 then
            table.remove(parts) -- Remove last part
            currentDir = table.concat(parts, "/")
        else
            currentDir = "."
        end
        
        listDir(currentDir)
        scrollOffset = 0
    end
end
