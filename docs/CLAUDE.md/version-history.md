# Version History

| Ver | Changes |
|-----|---------|
| 0.1.0 | Initial implementation: sprite converter, ESP32 firmware (renderer, FSM, BFS pathfinding, serial protocol), Python companion bridge, project docs |
| 0.2.0 | Office Tileset integration: extract tiles from PNG spritesheet for floor/wall/furniture rendering, tileset support in layout editor, fallback to hand-drawn sprites when tileset absent |
| 0.3.0 | Always-visible characters: all 6 characters idle in social zones (break room, library) at boot, walk to desks when agents activate, walk back when inactive; status bar shows "N/6 active" |
| 0.4.0 | French Bulldog pet: 16x16 animated dog roams the office with WANDER/FOLLOW/NAP behavior FSM, depth-sorted with characters, BFS pathfinding, sprite generator tool |
