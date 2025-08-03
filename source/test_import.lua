-- Test script to verify importing pixel_collision
print("Starting import test...")
local PixelCollision = import "scripts/world/pixel_collision"
print("Import successful!")
print("PixelCollision functions:", PixelCollision.checkPixelCollision, PixelCollision.checkSensorPixelCollision)
