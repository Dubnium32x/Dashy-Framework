-- csv_loader.lua
-- Simple CSV loader for Playdate Lua

local csv_loader = {}

-- Loads a CSV file and returns a 2D array (table of tables)
function csv_loader.load_csv(filepath)
    local rows = {}
    local success, error = pcall(function()
        local file = playdate.file.open(filepath)
        if not file then
            print("[ERROR] Could not open CSV file:", filepath)
            return rows
        end
        
        local fileSize = playdate.file.getSize(filepath)
        if not fileSize or fileSize <= 0 then
            print("[ERROR] File is empty or cannot get size:", filepath)
            file:close()
            return rows
        end
        
        local content = file:read(fileSize)
        if not content or content == "" then
            print("[ERROR] Failed to read content from file:", filepath)
            file:close()
            return rows
        end
        
        for line in string.gmatch(content, "[^\r\n]+") do
            local row = {}
            for value in string.gmatch(line, '([^,]+)') do
                table.insert(row, tonumber(value) or value)
            end
            table.insert(rows, row)
        end
        
        file:close()
    end)
    
    if not success then
        print("[ERROR] Exception while loading CSV file:", filepath, error)
        return {}
    end
    
    if #rows > 0 then
        print("[INFO] Successfully loaded CSV with " .. #rows .. " rows:", filepath)
    else
        print("[WARNING] CSV loaded but contains no rows:", filepath)
    end
    
    return rows
end

return csv_loader