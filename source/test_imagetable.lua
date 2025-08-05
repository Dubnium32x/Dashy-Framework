import "CoreLibs/graphics"

local gfx <const> = playdate.graphics

local imageTable = gfx.imagetable.new("sprites/tileset/DF-Simple-Collision-table-16-16")

function playdate.update()
    gfx.clear()
    gfx.setBackgroundColor(gfx.kColorBlack)
    if imageTable then
        local img = imageTable:getImage(1)
        if img then
            img:draw(100, 100)
        end
    end
end
