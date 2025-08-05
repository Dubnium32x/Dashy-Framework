# Tile Reference for Dashy Framework

## Collision System Tile IDs

### Basic Tiles
- **0**: Empty tile (no collision)
- **5**: Full solid tile (complete collision)

### Half Slabs (8-pixel height)
- **1**: Half slab (bottom half)
- **14**: Half slab (right side) 
- **15**: Half slab (bottom half)

### Slopes (1 by 1)
- **2**: 45° slope (1 by 1)

### Slopes (2 by 1 series)
- **3**: 22.5° slope (2 by 1 - gentle part)
- **4**: 22.5° slope (2 by 1 - steep part)

### Slopes (3 by 1 series)  
- **6**: 67.5° slope (3 by 1 - steep)
- **7**: 45° slope (3 by 1 - medium)
- **8**: 22.5° slope (3 by 1 - gentle)

### Slopes (1 by 2 series)
- **9**: 63.4° slope (1 by 2 - steep part)
- **10**: 26.6° slope (1 by 2 - gentle part)

### Slopes (1 by 3 series)
- **11**: 71.6° slope (1 by 3 - steep)
- **12**: 45° slope (1 by 3 - medium)  
- **13**: 18.4° slope (1 by 3 - gentle)

### Vertical Walls
- **16**: Left-side vertical wall (right half solid)
- **17**: Right-side vertical wall (left half solid)
- **18**: Full vertical wall (completely solid)

## Collision Features

### Heightmap System
All slopes and half-slabs use 16-point heightmaps for pixel-perfect collision detection.

### Slope Physics  
- Sonic-style slope influence with uphill resistance and downhill acceleration
- Steeper slopes allow higher maximum speeds
- Slide-back mechanic on steep slopes when moving too slowly
- Enhanced collision tolerance (4 pixels) for reliable slope peak handling

### Wall Detection
- Proper vertical wall collision with directional awareness
- Steep slopes (>60°) also act as walls for horizontal movement
- Half-slabs correctly detected as partial height obstacles

## Recent Improvements
- Added missing heightmaps for 1x2 slopes (tiles 9, 10)
- Enhanced slope influence calculations 
- Improved wall collision with directional checks
- Better half-slab detection and handling
- Increased collision tolerance for slope peaks
