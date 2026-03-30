import Foundation
import AppKit

// MARK: - Sprite Cache

/// Loads sprite sheets at init and pre-crops all individual frames into
/// lookup dictionaries. This avoids per-frame CGImage.cropping(to:) calls
/// during the render loop (~105 allocations/sec eliminated).
final class SpriteCache {

    static let shared = SpriteCache()

    // Sprite dimensions
    static let charW = 16
    static let charH = 32
    static let charCols = 7
    static let charRows = 3
    static let numPalettes = 6

    static let dogW = 25
    static let dogH = 19
    static let dogCols = 5
    static let dogRows = 5
    static let dogFrameCount = dogCols * dogRows  // 25

    // Robot mini-agent sprite sheet
    static let robotFrameSize = 64   // each frame canvas in source
    static let robotCols = 2
    static let robotRows = 3
    static let robotFrameCount = robotCols * robotRows  // 6
    // Content bbox within each 64x64 frame
    static let robotCropX = 19
    static let robotCropY = 18
    static let robotCropW = 24
    static let robotCropH = 30

    // Pre-cropped frame caches
    private var charFrames: [Int: CGImage] = [:]   // key: (palette * 3 + row) * 7 + col
    private var dogFrames: [Int: CGImage] = [:]     // key: colorRaw * 25 + frameIdx
    private var robotFrameCache: [Int: CGImage] = [:]  // key: frameIdx (0-5)
    private var bgImage: CGImage?

    init() {
        loadAll()
    }

    private func loadAll() {
        // Load + pre-crop character frames: 6 palettes x 3 rows x 7 cols = 126 frames
        for palette in 0..<Self.numPalettes {
            guard let sheet = loadImage(named: "char_\(palette)") else { continue }
            for row in 0..<Self.charRows {
                for col in 0..<Self.charCols {
                    let cropRect = CGRect(
                        x: col * Self.charW, y: row * Self.charH,
                        width: Self.charW, height: Self.charH
                    )
                    if let frame = sheet.cropping(to: cropRect) {
                        charFrames[(palette * Self.charRows + row) * Self.charCols + col] = frame
                    }
                }
            }
        }

        // Load + pre-crop dog frames: 4 colors x 25 frames = 100 frames
        let dogColorMap: [(OfficeSim.DogColor, String)] = [
            (.black, "doggy-black"),
            (.brown, "doggy-brown"),
            (.gray,  "doggy-gray"),
            (.tan,   "doggy-tan"),
        ]
        for (color, name) in dogColorMap {
            guard let sheet = loadImage(named: name) else { continue }
            let colorRaw = Int(color.rawValue)
            for idx in 0..<Self.dogFrameCount {
                let col = idx % Self.dogCols
                let row = idx / Self.dogCols
                let cropRect = CGRect(
                    x: col * Self.dogW, y: row * Self.dogH,
                    width: Self.dogW, height: Self.dogH
                )
                if let frame = sheet.cropping(to: cropRect) {
                    dogFrames[colorRaw * Self.dogFrameCount + idx] = frame
                }
            }
        }

        // Load + pre-crop robot frames: 2 cols x 3 rows = 6 frames, cropped to content area
        if let robotSheet = loadImage(named: "robot walk") {
            var idx = 0
            for row in 0..<Self.robotRows {
                for col in 0..<Self.robotCols {
                    let cropRect = CGRect(
                        x: col * Self.robotFrameSize + Self.robotCropX,
                        y: row * Self.robotFrameSize + Self.robotCropY,
                        width: Self.robotCropW,
                        height: Self.robotCropH
                    )
                    if let frame = robotSheet.cropping(to: cropRect) {
                        robotFrameCache[idx] = frame
                    }
                    idx += 1
                }
            }
        }

        bgImage = loadImage(named: "office_background")
    }

    private func loadImage(named name: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }
        return cgImage
    }

    /// Returns a pre-cropped character frame.
    /// - Parameters:
    ///   - palette: Character variant index (0-5)
    ///   - dir: Direction (DOWN=row0, UP=row1, RIGHT=row2). LEFT handled by caller via flip.
    ///   - frameCol: Column index in the sprite sheet (0-6)
    func characterFrame(palette: Int, dir: OfficeSim.Dir, frameCol: Int) -> CGImage? {
        let row: Int
        switch dir {
        case .down:  row = 0
        case .up:    row = 1
        case .right, .left: row = 2
        }
        let col = max(0, min(frameCol, Self.charCols - 1))
        let paletteIdx = palette % Self.numPalettes
        return charFrames[(paletteIdx * Self.charRows + row) * Self.charCols + col]
    }

    /// Returns a pre-cropped dog frame.
    /// - Parameters:
    ///   - color: Dog color variant
    ///   - index: Linear frame index (0-24)
    func dogFrame(color: OfficeSim.DogColor, index: Int) -> CGImage? {
        let frameIdx = max(0, min(index, Self.dogFrameCount - 1))
        return dogFrames[Int(color.rawValue) * Self.dogFrameCount + frameIdx]
    }

    /// Returns a pre-cropped robot walk frame (0-5).
    func robotFrame(index: Int) -> CGImage? {
        let frameIdx = max(0, min(index, Self.robotFrameCount - 1))
        return robotFrameCache[frameIdx]
    }

    /// Returns the full office background image.
    func background() -> CGImage? {
        bgImage
    }
}

// MARK: - Office Renderer

/// Renders the full office scene into a reusable 320x224 CGBitmapContext,
/// producing a CGImage suitable for display in an NSImageView or SwiftUI Image.
@MainActor
final class OfficeRenderer {

    // MARK: - Constants

    private let sceneW = 320
    private let sceneH = 224  // Grid area only (14 rows * 16px), no status bar
    private let charW: CGFloat = 16
    private let charH: CGFloat = 32
    private let miniCharW: CGFloat = 13
    private let miniCharH: CGFloat = 16
    private let dogW: CGFloat = 25
    private let dogH: CGFloat = 19
    private let sittingOffsetPx: CGFloat = 6

    // MARK: - Properties

    private let sprites = SpriteCache.shared
    private var bitmapCtx: CGContext?

    // Cached speech bubble attributed strings (only 2 variants, avoid per-frame allocation)
    private let cachedBubbleExcl: NSAttributedString
    private let cachedBubbleDots: NSAttributedString
    private let cachedBubbleExclSize: NSSize
    private let cachedBubbleDotsSize: NSSize

    // MARK: - Entity Depth Sorting

    private enum EntityKind {
        case character(Int)
        case dog
    }

    // MARK: - Init

    init() {
        let ctx = CGContext(
            data: nil,
            width: sceneW,
            height: sceneH,
            bitsPerComponent: 8,
            bytesPerRow: sceneW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        ctx?.interpolationQuality = .none
        bitmapCtx = ctx
        if ctx == nil {
            NSLog("[OfficeRenderer] Failed to allocate %dx%d CGBitmapContext", sceneW, sceneH)
        }

        // Pre-build speech bubble text
        let bubbleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        cachedBubbleExcl = NSAttributedString(string: "!", attributes: bubbleAttrs)
        cachedBubbleDots = NSAttributedString(string: "...", attributes: bubbleAttrs)
        cachedBubbleExclSize = cachedBubbleExcl.size()
        cachedBubbleDotsSize = cachedBubbleDots.size()
    }

    // MARK: - Public Render

    /// Renders the full office scene and returns a CGImage.
    /// - Parameter scene: The current office scene state.
    /// - Returns: A 320x224 CGImage, or nil if the bitmap context is unavailable.
    func render(scene: OfficeScene) -> CGImage? {
        guard let ctx = bitmapCtx else { return nil }

        // 1. Clear
        ctx.clear(CGRect(x: 0, y: 0, width: sceneW, height: sceneH))

        // 2. Draw background
        drawBackground(ctx)

        // 3. Collect all depth-sortable entities
        var entities: [(y: Float, kind: EntityKind)] = []

        for i in 0..<scene.characters.count {
            let ch = scene.characters[i]
            guard ch.alive else { continue }
            entities.append((y: ch.y, kind: .character(i)))
        }

        if scene.dogEnabled {
            entities.append((y: scene.pet.y, kind: .dog))
        }

        // 4. Sort by Y (lower Y = behind = drawn first)
        entities.sort { $0.y < $1.y }

        // 5. Draw entities in depth order
        for entity in entities {
            switch entity.kind {
            case .character(let idx):
                let ch = scene.characters[idx]
                if ch.state == .spawn || ch.state == .despawn {
                    ch.isMini ? drawMiniSpawnEffect(ctx, character: ch) : drawSpawnEffect(ctx, character: ch)
                } else {
                    ch.isMini ? drawMiniCharacter(ctx, character: ch) : drawCharacter(ctx, character: ch, scene: scene)
                }
            case .dog:
                drawDog(ctx, pet: scene.pet, dogColor: scene.dogColor)
            }
        }

        // 6. Draw speech bubbles (on top of all entities)
        for ch in scene.characters {
            guard ch.alive, !ch.isMini, ch.bubbleType > 0 else { continue }
            drawBubble(ctx, character: ch)
        }

        // 7. Produce image
        return ctx.makeImage()
    }

    // MARK: - Sprite Drawing Helper

    /// Draws a CGImage at SwiftUI-style coordinates (top-left origin), handling
    /// the CGContext Y-flip and optional horizontal flip.
    private func drawSprite(
        _ ctx: CGContext,
        image: CGImage,
        x: CGFloat,
        y: CGFloat,
        w: CGFloat,
        h: CGFloat,
        flipH: Bool = false
    ) {
        let cgY = CGFloat(sceneH) - y - h
        if flipH {
            ctx.saveGState()
            ctx.translateBy(x: x + w, y: cgY)
            ctx.scaleBy(x: -1, y: 1)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            ctx.restoreGState()
        } else {
            ctx.draw(image, in: CGRect(x: x, y: cgY, width: w, height: h))
        }
    }

    // MARK: - Background

    private func drawBackground(_ ctx: CGContext) {
        guard let bg = sprites.background() else { return }
        ctx.draw(bg, in: CGRect(x: 0, y: 0, width: sceneW, height: sceneH))
    }

    // MARK: - Character Rendering

    private func drawCharacter(_ ctx: CGContext, character ch: OfficeSim.Character, scene: OfficeScene) {
        let sittingOff: CGFloat = (ch.state == .type || ch.state == .read) ? sittingOffsetPx : 0
        let drawX = CGFloat(ch.x) - charW / 2
        let drawY = CGFloat(ch.y) + sittingOff - charH

        // Determine frame column
        let frameCol: Int
        if ch.state == .activity && ch.idleActivity != .reading {
            frameCol = 1  // standing pose for coffee/water/socializing
        } else {
            frameCol = getFrameCol(state: ch.state, frame: ch.frame)
        }

        // Determine direction and flip
        let renderDir: OfficeSim.Dir
        let flipH: Bool
        if ch.dir == .left {
            renderDir = .right
            flipH = true
        } else {
            renderDir = ch.dir
            flipH = false
        }

        guard let frame = sprites.characterFrame(
            palette: ch.palette,
            dir: renderDir,
            frameCol: frameCol
        ) else { return }

        drawSprite(ctx, image: frame, x: drawX, y: drawY, w: charW, h: charH, flipH: flipH)
    }

    // MARK: - Spawn/Despawn Effect

    private func drawSpawnEffect(_ ctx: CGContext, character ch: OfficeSim.Character) {
        let drawX = CGFloat(ch.x) - charW / 2
        let drawY = CGFloat(ch.y) - charH
        let frameCol = 1  // standing pose

        let renderDir: OfficeSim.Dir
        let flipH: Bool
        if ch.dir == .left {
            renderDir = .right
            flipH = true
        } else {
            renderDir = ch.dir
            flipH = false
        }

        guard let frame = sprites.characterFrame(
            palette: ch.palette,
            dir: renderDir,
            frameCol: frameCol
        ) else { return }

        // Calculate reveal progress (0.0 to 1.0)
        let progress = CGFloat(min(ch.effectTimer / OfficeSim.spawnDurationSec, 1.0))
        let revealCols = Int(progress * charW)
        guard revealCols > 0 else { return }

        // Crop to revealed columns
        let cropX: Int
        let cropW: Int
        if ch.state == .despawn {
            // Despawn: reveal from right, hide from left
            cropX = Int(charW) - revealCols
            cropW = revealCols
        } else {
            cropX = 0
            cropW = revealCols
        }

        guard let croppedFrame = frame.cropping(
            to: CGRect(x: cropX, y: 0, width: cropW, height: Int(charH))
        ) else { return }

        let offsetX = drawX + CGFloat(cropX)
        drawSprite(ctx, image: croppedFrame, x: offsetX, y: drawY, w: CGFloat(cropW), h: charH, flipH: flipH)

        // Matrix-style green tint overlay on revealed area
        let overlayAlpha = 0.3 * (1.0 - progress)
        let overlayX: CGFloat
        if flipH {
            overlayX = drawX + charW - CGFloat(cropX) - CGFloat(cropW)
        } else {
            overlayX = offsetX
        }
        let overlayCGY = CGFloat(sceneH) - drawY - charH
        ctx.saveGState()
        ctx.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: overlayAlpha))
        ctx.fill(CGRect(x: overlayX, y: overlayCGY, width: CGFloat(cropW), height: charH))
        ctx.restoreGState()
    }

    // MARK: - Mini Character Rendering

    private func drawMiniCharacter(_ ctx: CGContext, character ch: OfficeSim.Character) {
        let drawX = CGFloat(ch.x) - miniCharW / 2
        let drawY = CGFloat(ch.y) - miniCharH

        // Robot: no directional variants, cycle through walk frames
        let localFrame: Int
        if ch.state == .type || ch.state == .read || ch.state == .walk {
            localFrame = ch.frame % SpriteCache.robotFrameCount
        } else {
            localFrame = 0
        }

        guard let frame = sprites.robotFrame(index: localFrame) else { return }
        drawSprite(ctx, image: frame, x: drawX, y: drawY, w: miniCharW, h: miniCharH, flipH: false)
    }

    private func drawMiniSpawnEffect(_ ctx: CGContext, character ch: OfficeSim.Character) {
        let drawX = CGFloat(ch.x) - miniCharW / 2
        let drawY = CGFloat(ch.y) - miniCharH

        guard let frame = sprites.robotFrame(index: 0) else { return }

        let progress = CGFloat(min(ch.effectTimer / OfficeSim.spawnDurationSec, 1.0))
        let revealCols = Int(progress * miniCharW)
        guard revealCols > 0 else { return }

        let cropX: Int
        let cropW: Int
        if ch.state == .despawn {
            cropX = Int(miniCharW) - revealCols
            cropW = revealCols
        } else {
            cropX = 0
            cropW = revealCols
        }

        // Scale crop coordinates from mini to source frame for CGImage cropping
        let scaleX = CGFloat(frame.width) / miniCharW
        let srcCropRect = CGRect(
            x: CGFloat(cropX) * scaleX,
            y: 0,
            width: CGFloat(cropW) * scaleX,
            height: CGFloat(frame.height)
        )
        guard let croppedFrame = frame.cropping(to: srcCropRect) else { return }

        let offsetX = drawX + CGFloat(cropX)
        drawSprite(ctx, image: croppedFrame, x: offsetX, y: drawY, w: CGFloat(cropW), h: miniCharH, flipH: false)

        // Matrix-style green tint overlay
        let overlayAlpha = 0.3 * (1.0 - progress)
        let overlayCGY = CGFloat(sceneH) - drawY - miniCharH
        ctx.saveGState()
        ctx.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: overlayAlpha))
        ctx.fill(CGRect(x: offsetX, y: overlayCGY, width: CGFloat(cropW), height: miniCharH))
        ctx.restoreGState()
    }

    // MARK: - Dog Rendering

    private func drawDog(_ ctx: CGContext, pet: OfficeSim.Pet, dogColor: OfficeSim.DogColor) {
        let drawX = CGFloat(pet.x) - dogW / 2
        let drawY = CGFloat(pet.y) - dogH
        let flipH = (pet.dir == .left)

        // Determine frame index (matching firmware renderer.cpp drawDog)
        let frameIdx: Int
        if pet.behavior == .nap {
            frameIdx = 18  // DOG_LAYDOWN_IDX
        } else if pet.isSitting {
            frameIdx = 0   // DOG_SIT_IDX
        } else if pet.isPeeing {
            frameIdx = 17  // DOG_PEE_IDX
        } else if pet.walking {
            if pet.isRunning {
                frameIdx = 9 + (pet.frame % 8)   // DOG_RUN_BASE + frame % DOG_RUN_COUNT
            } else {
                frameIdx = 19 + (pet.frame % 4)  // DOG_WALK_BASE + frame % DOG_WALK_COUNT
            }
        } else {
            frameIdx = 1 + (pet.idleFrame % 8)   // DOG_IDLE_BASE + idleFrame % DOG_IDLE_COUNT
        }

        guard let frame = sprites.dogFrame(color: dogColor, index: frameIdx) else { return }

        drawSprite(ctx, image: frame, x: drawX, y: drawY, w: dogW, h: dogH, flipH: flipH)
    }

    // MARK: - Speech Bubbles

    private func drawBubble(_ ctx: CGContext, character ch: OfficeSim.Character) {
        let sittingOff: CGFloat = (ch.state == .type || ch.state == .read) ? sittingOffsetPx : 0
        let bubbleX = CGFloat(ch.x)
        let bubbleY = CGFloat(ch.y) + sittingOff - charH - 10

        let bubbleW: CGFloat = 14
        let bubbleH: CGFloat = 10

        let bgCGColor: CGColor
        let attrStr: NSAttributedString
        let textSize: NSSize

        switch ch.bubbleType {
        case 1:
            // Permission bubble: orange with "!"
            bgCGColor = CGColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0)
            attrStr = cachedBubbleExcl
            textSize = cachedBubbleExclSize
        case 2:
            // Waiting bubble: blue with "..."
            bgCGColor = CGColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
            attrStr = cachedBubbleDots
            textSize = cachedBubbleDotsSize
        default:
            return
        }

        let rectX = bubbleX - bubbleW / 2
        let rectY = bubbleY - bubbleH / 2
        let cgY = CGFloat(sceneH) - rectY - bubbleH

        // Draw bubble background (rounded rect)
        let path = CGPath(
            roundedRect: CGRect(x: rectX, y: cgY, width: bubbleW, height: bubbleH),
            cornerWidth: 3,
            cornerHeight: 3,
            transform: nil
        )
        ctx.saveGState()
        ctx.setFillColor(bgCGColor)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.restoreGState()

        // Draw cached text centered in bubble
        NSGraphicsContext.saveGraphicsState()
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsCtx
        attrStr.draw(at: NSPoint(
            x: rectX + (bubbleW - textSize.width) / 2,
            y: cgY + (bubbleH - textSize.height) / 2
        ))
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - Frame Index Mapping

    /// Maps character state + animation frame to sprite sheet column index.
    /// Matches firmware `Renderer::getFrameIndex()`.
    private func getFrameCol(state: OfficeSim.SimCharState, frame: Int) -> Int {
        switch state {
        case .walk:
            // Cycle: walk1, walk2, walk3, walk2 -> columns [0, 1, 2, 1]
            return [0, 1, 2, 1][frame % 4]
        case .type:
            return 3 + (frame % 2)  // type1, type2
        case .read:
            return 5 + (frame % 2)  // read1, read2
        case .activity:
            return 5 + (frame % 2)  // READ frames for READING activity
        case .idle, .spawn, .despawn, .offline:
            return 1  // walk2 = standing pose
        }
    }
}
