-- title_card.lua
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/ui"

local pd <const> = playdate
local gfx <const> = pd.graphics

local TitleCard = {}
TitleCard.wipeActive = false
TitleCard.wipeProgress = 0
TitleCard.WIPE_DURATION = 0.3 -- seconds