-- level_list.lua
-- List of levels and their metadata for the game

local levelList = {}
-- Example entries; update with your actual level/layer names
for i = 0, 9 do
    table.insert(levelList, {
        levelName = "Level_" .. i,
        layerNames = {
            "Ground1",
            "SemiSolids1",
            "Objects1"
        },
        entryId = i, -- Unique identifier for the level entry
        world = "World_1", -- Specify the world this level belongs to
    })
end
print("[DEBUG] Level list loaded with " .. #levelList .. " levels.")

for i, level in ipairs(levelList) do
    print(string.format("[DEBUG] Level %d: %s, Entry ID: %d, World: %s", i, level.levelName, level.entryId, level.world))
end

return levelList
