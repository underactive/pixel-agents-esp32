# Plan: Update Dog Sprites from PNG Sprite Sheet

## Objective
Replace hand-drawn 32x24 dog sprites with new 25x19 pixel art from `assets/doggy3.png` sprite sheet. Add Run and Pee behaviors, remove Blink/Happy/Tail Wag, simplify to side-view only.

## Sprite Sheet Layout (125x95, 5x5 grid of 25x19 frames)
- Frame 0: Sit
- Frames 1-8: Idle (8 frames)
- Frames 9-16: Run (8 frames)
- Frame 17: Pee
- Frame 18: Lay down (used for nap/sleep)
- Frames 19-22: Walk (4 frames)
- Frames 23-24: Empty

## Changes

### 1. `tools/convert_dog.py`
- Rewrite to load `assets/doggy3.png` via PIL
- Extract 25x19 frames from 5x5 grid
- Convert RGBA pixels to RGB565 (transparent where alpha=0)
- Output 23 frames to `firmware/src/sprites/dog.h`

### 2. `firmware/src/config.h`
- DOG_W = 25 (was 32), DOG_H = 19 (was 24)
- New frame indices: SIT=0, IDLE_BASE=1 (8 frames), RUN_BASE=9 (8 frames), PEE=17, LAYDOWN=18, WALK_BASE=19 (4 frames)
- Remove: DOG_BLINK_IDX, DOG_HAPPY_IDX, DOG_TAIL*_IDX, DOG_SLEEP_Z_IDX, DOG_DOWN/UP/RIGHT_WALK_BASE
- Remove: blink, happy, tail wag timing constants
- Add: run speed, pee timing constants

### 3. `firmware/src/office_state.h`
- Remove from Pet: blinkTimer, blinkRemaining, isBlinking, happyTimer, isHappy, tailWagTimer, tailWagCooldown, tailFrameTimer, tailFrame, napZTimer, showingZ
- Add to Pet: isRunning, peeTimer, peeRemaining, isPeeing, idleFrame count update for 8 frames

### 4. `firmware/src/office_state.cpp`
- Remove: blink, happy, tail wag, nap Z toggle logic
- Add: pee behavior (random chance during idle, like current happy)
- Add: run behavior (randomly initiated walk at faster speed)
- Nap uses lay down frame directly (no Z toggle)

### 5. `firmware/src/renderer.cpp`
- Update drawDog(): remove blink/happy/tail wag branches
- Side-view only: flip for LEFT, same frames for all directions
- Add run frame selection (8-frame cycle)
- Add pee frame selection
- Use LAYDOWN for nap (no Z toggle)

## Dependencies
- convert_dog.py must run before firmware build (generates dog.h)
- PIL/Pillow required for convert_dog.py

## Risks
- Sprite sheet frame ordering assumed from description + empty cell analysis; verify visually after generation
