# Plan: French Bulldog Pet

## Objective

Add an animated French Bulldog that freely roams the office. Every hour it picks a random character to stay near (within 5 tiles), every 20 minutes it takes a wander break, and every 4 hours it naps for 30 minutes.

## Changes

### 1. `tools/convert_dog.py` (new)
- Python script to generate `firmware/src/sprites/dog.h`
- 16x16 pixel art defined as character grids, converted to RGB565
- Frames: 3 walk frames x 3 directions + 1 nap = 10 frames
- Fawn-colored frenchie with bat ears, stocky body, short legs

### 2. `firmware/src/sprites/dog.h` (generated)
- Direct RGB565 arrays, 16x16 per frame, PROGMEM
- 10 frames x 512 bytes = 5 KB

### 3. `firmware/src/config.h`
- Dog sprite dimensions, walk speed, behavior timing constants
- `DogBehavior` enum: WANDER, FOLLOW, NAP

### 4. `firmware/src/office_state.h`
- `Pet` struct: position, path, animation, behavior timers, followTarget
- Add `Pet _pet` member and private update/movement methods
- Public accessor `getPet()`

### 5. `firmware/src/office_state.cpp`
- `initPet()`: random walkable tile, start WANDER
- `updatePet(dt)`: behavior FSM with phase/hour/nap timers
- Called from `update(dt)`

### 6. `firmware/src/renderer.h/.cpp`
- `drawDog()` method
- Insert dog into character depth sort in `drawScene()`

## Dependencies
- `initPet()` called from `spawnAllCharacters()`
- Reuses existing `findPath()` / `isWalkable()`

## Risks
1. 16x16 pixel art quality - may need iteration
2. Follow jitter - uses hysteresis (only re-pathfind if target moved >3 tiles)
