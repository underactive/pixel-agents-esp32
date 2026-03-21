import Foundation
import AppKit

// MARK: - Sprite Cache

/// Loads and caches all sprite sheet CGImages from the app bundle.
/// Provides cropped sprite frames for characters and dogs.
final class SpriteCache {

    static let shared = SpriteCache()

    // Character sprite sheets (6 palettes, each 112x96: 7 cols x 3 rows of 16x32)
    private var charSheets: [CGImage?] = []

    // Dog sprite sheets keyed by color (each 125x95: 5x5 grid of 25x19)
    private var dogSheets: [OfficeSim.DogColor: CGImage] = [:]

    // Background image (320x224)
    private var bgImage: CGImage?

    // Sprite dimensions
    static let charW = 16
    static let charH = 32
    static let charCols = 7
    static let charRows = 3

    static let dogW = 25
    static let dogH = 19
    static let dogCols = 5
    static let dogRows = 5

    init() {
        loadAll()
    }

    private func loadAll() {
        // Load character sheets: char_0 through char_5
        for i in 0..<6 {
            charSheets.append(loadImage(named: "char_\(i)"))
        }

        // Load dog sheets
        let dogColorMap: [(OfficeSim.DogColor, String)] = [
            (.black, "doggy-black"),
            (.brown, "doggy-brown"),
            (.gray,  "doggy-gray"),
            (.tan,   "doggy-tan"),
        ]
        for (color, name) in dogColorMap {
            if let img = loadImage(named: name) {
                dogSheets[color] = img
            }
        }

        // Load background
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

    /// Returns a cropped character frame from the sprite sheet.
    /// - Parameters:
    ///   - palette: Character variant index (0-5)
    ///   - dir: Direction (DOWN=row0, UP=row1, RIGHT=row2). LEFT handled by caller via flip.
    ///   - frameCol: Column index in the sprite sheet (0-6)
    func characterFrame(palette: Int, dir: OfficeSim.Dir, frameCol: Int) -> CGImage? {
        guard !charSheets.isEmpty else { return nil }
        let paletteIdx = palette % charSheets.count
        guard let sheet = charSheets[paletteIdx] else { return nil }

        let row: Int
        switch dir {
        case .down:  row = 0
        case .up:    row = 1
        case .right: row = 2
        case .left:  row = 2  // caller flips horizontally
        }

        let col = max(0, min(frameCol, Self.charCols - 1))
        let cropRect = CGRect(
            x: col * Self.charW,
            y: row * Self.charH,
            width: Self.charW,
            height: Self.charH
        )
        return sheet.cropping(to: cropRect)
    }

    /// Returns a cropped dog frame from the sprite sheet.
    /// - Parameters:
    ///   - color: Dog color variant
    ///   - index: Linear frame index (0-22)
    func dogFrame(color: OfficeSim.DogColor, index: Int) -> CGImage? {
        guard let sheet = dogSheets[color] else { return nil }

        let frameIdx = max(0, min(index, Self.dogCols * Self.dogRows - 1))
        let col = frameIdx % Self.dogCols
        let row = frameIdx / Self.dogCols
        let cropRect = CGRect(
            x: col * Self.dogW,
            y: row * Self.dogH,
            width: Self.dogW,
            height: Self.dogH
        )
        return sheet.cropping(to: cropRect)
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
    private let dogW: CGFloat = 25
    private let dogH: CGFloat = 19
    private let sittingOffsetPx: CGFloat = 6

    // MARK: - Properties

    private let sprites = SpriteCache.shared
    private var bitmapCtx: CGContext?

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
                    drawSpawnEffect(ctx, character: ch)
                } else {
                    drawCharacter(ctx, character: ch, scene: scene)
                }
            case .dog:
                drawDog(ctx, pet: scene.pet, dogColor: scene.dogColor)
            }
        }

        // 6. Draw speech bubbles (on top of all entities)
        for ch in scene.characters {
            guard ch.alive, ch.bubbleType > 0 else { continue }
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
        let text: String

        switch ch.bubbleType {
        case 1:
            // Permission bubble: orange with "!"
            bgCGColor = CGColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0)
            text = "!"
        case 2:
            // Waiting bubble: blue with "..."
            bgCGColor = CGColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
            text = "..."
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

        // Draw text centered in bubble using NSAttributedString
        NSGraphicsContext.saveGraphicsState()
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsCtx
        let attrStr = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 7, weight: .bold),
            .foregroundColor: NSColor.white,
        ])
        let textSize = attrStr.size()
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
