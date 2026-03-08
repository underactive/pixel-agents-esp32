# Version History

| Ver | Changes |
|-----|---------|
| 0.1.0 | Initial implementation: sprite converter, ESP32 firmware (renderer, FSM, BFS pathfinding, serial protocol), Python companion bridge, project docs |
| 0.2.0 | Office Tileset integration: extract tiles from PNG spritesheet for floor/wall/furniture rendering, tileset support in layout editor, fallback to hand-drawn sprites when tileset absent |
| 0.3.0 | Always-visible characters: all 6 characters idle in social zones (break room, library) at boot, walk to desks when agents activate, walk back when inactive; status bar shows "N/6 active" |
| 0.4.0 | French Bulldog pet: 16x16 animated dog roams the office with WANDER/FOLLOW/NAP behavior FSM, depth-sorted with characters, BFS pathfinding, sprite generator tool |
| 0.4.1 | Updated dog sprites: replaced hand-drawn 32x24 with 25x19 pixel art from PNG sprite sheet, 23 frames (8 idle, 4 walk, 8 run, sit, lay down, pee), side-view only with LEFT flip, added run and pee behaviors |
| 0.5.0 | Hamburger menu + multi-color dog: 4 dog color variants (black, brown, gray, tan), CYD touch hamburger menu for dog toggle and color selection, NVS settings persistence across reboots |
