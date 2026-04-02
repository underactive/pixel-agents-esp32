import Foundation

// MARK: - OfficeSim Namespace

/// Namespace enum to avoid conflicts with the app's existing CharState enum.
enum OfficeSim {

    // MARK: - Constants

    static let tileSize: Float = 16
    static let gridCols = 20
    static let gridRows = 14
    static let screenW: Float = 320
    static let screenH: Float = 240
    static let maxDeskAgents = 6
    static let maxMiniAgents = 12
    static let maxAgents = 18  // desk + mini
    static let numPalettes = 6
    static let charW: Float = 16
    static let charH: Float = 32
    static let miniCharW: Float = 13
    static let miniCharH: Float = 16
    static let dogW: Float = 25
    static let dogH: Float = 19

    static let walkSpeedPxPerSec: Float = 48.0
    static let walkFrameDurationSec: Float = 0.15
    static let typeFrameDurationSec: Float = 0.3
    static let wanderPauseMinSec: Float = 2.0
    static let wanderPauseMaxSec: Float = 20.0
    static let wanderMovesMin = 3
    static let wanderMovesMax = 6
    static let sittingOffsetPx: Float = 6
    static let activityChance: Float = 0.40
    static let activityDurationMinSec: Float = 4.0
    static let activityDurationMaxSec: Float = 10.0
    static let activityCooldownSec: Float = 3.0
    static let readActivityFrameSec: Float = 0.4

    static let dogWalkSpeedPxPerSec: Float = 40.0
    static let dogRunSpeedPxPerSec: Float = 72.0
    static let dogWalkFrameDurationSec: Float = 0.12
    static let dogRunFrameDurationSec: Float = 0.08
    static let dogIdleFrameSec: Float = 0.3
    static let dogFollowDurationSec: Float = 20 * 60.0
    static let dogWanderDurationSec: Float = 20 * 60.0
    static let dogPickTargetSec: Float = 60 * 60.0
    static let dogNapIntervalSec: Float = 4 * 60 * 60.0
    static let dogNapDurationSec: Float = 30 * 60.0
    static let dogFollowRepathfindSec: Float = 8.0
    static let dogFollowRadius = 5
    static let dogFollowHysteresis = 3
    static let dogPeeChance: Float = 0.08
    static let dogPeeDurationSec: Float = 3.0
    static let dogRunChance: Float = 0.15
    static let dogWanderPauseMinSec: Float = 2.0
    static let dogWanderPauseMaxSec: Float = 6.0
    static let dogWanderMoveMinSec: Float = 3.0
    static let dogWanderMoveMaxSec: Float = 10.0

    static let dogIdleCount = 8
    static let dogWalkCount = 4
    static let dogRunCount = 8

    static let maxPathLen = 64

    static let spawnDurationSec: Float = 3.0
    static let permissionBubbleDurationSec: Float = 0.0
    static let waitingBubbleDurationSec: Float = 0.0

    // MARK: - Enums

    enum SimCharState: UInt8 {
        case offline = 0, idle = 1, walk = 2, type = 3, read = 4
        case spawn = 5, despawn = 6, activity = 7
    }

    enum Dir: UInt8 {
        case down = 0, up = 1, right = 2, left = 3
    }

    enum IdleActivity: UInt8 {
        case none = 0, reading = 1, coffee = 2, water = 3, socializing = 4
    }

    enum SocialZone: UInt8 {
        case breakRoom = 0, library = 1
    }

    enum DogBehavior: UInt8 {
        case wander = 0, follow = 1, nap = 2
    }

    enum DogColor: UInt8 {
        case black = 0, brown = 1, gray = 2, tan = 3
    }

    enum TileType: UInt8 {
        case floor = 0, wall = 1, blocked = 2
    }

    // MARK: - Structs

    struct PathNode {
        var col: Int
        var row: Int
    }

    struct Workstation {
        let deskCol: Int
        let deskRow: Int
        let seatCol: Int
        let seatRow: Int
        let facingDir: Dir
    }

    struct InteractionPoint {
        let col: Int
        let row: Int
        let facingDir: Dir
    }

    // MARK: - Workstations

    static let workstations: [Workstation] = [
        Workstation(deskCol: 1, deskRow: 12, seatCol: 2, seatRow: 11, facingDir: .down),
        Workstation(deskCol: 6, deskRow: 12, seatCol: 7, seatRow: 11, facingDir: .down),
        Workstation(deskCol: 1, deskRow: 7,  seatCol: 2, seatRow: 8,  facingDir: .up),
        Workstation(deskCol: 6, deskRow: 7,  seatCol: 7, seatRow: 8,  facingDir: .up),
        Workstation(deskCol: 3, deskRow: 4,  seatCol: 2, seatRow: 4,  facingDir: .right),
        Workstation(deskCol: 6, deskRow: 4,  seatCol: 7, seatRow: 4,  facingDir: .left),
    ]

    // MARK: - Social Zones

    static let zoneBreakColMin = 10
    static let zoneBreakColMax = 18
    static let zoneBreakRowMin = 3
    static let zoneBreakRowMax = 4

    static let zoneLibColMin = 12
    static let zoneLibColMax = 19
    static let zoneLibRowMin = 8
    static let zoneLibRowMax = 13

    // MARK: - Interaction Points

    static let readingPoints: [InteractionPoint] = [
        InteractionPoint(col: 14, row: 8, facingDir: .up),
        InteractionPoint(col: 15, row: 8, facingDir: .up),
        InteractionPoint(col: 16, row: 8, facingDir: .up),
        InteractionPoint(col: 17, row: 8, facingDir: .up),
    ]

    static let coffeePoints: [InteractionPoint] = [
        InteractionPoint(col: 16, row: 3, facingDir: .up),
        InteractionPoint(col: 17, row: 3, facingDir: .up),
    ]

    static let waterPoints: [InteractionPoint] = [
        InteractionPoint(col: 12, row: 3, facingDir: .up),
    ]

    // MARK: - Reading Tools

    static let readingTools: Set<String> = ["Read", "Grep", "Glob", "WebFetch", "WebSearch"]

    static func isReadingTool(_ name: String) -> Bool {
        readingTools.contains(name)
    }

    // MARK: - Character

    struct Character {
        var id: Int
        var state: SimCharState = .idle
        var dir: Dir = .down
        var x: Float = 0
        var y: Float = 0
        var tileCol: Int = 0
        var tileRow: Int = 0
        var palette: Int = 0
        var frame: Int = 0
        var frameTimer: Float = 0
        var wanderTimer: Float = 0
        var wanderCount: Int = 0
        var wanderLimit: Int = 0
        var pathLen: Int = 0
        var pathIdx: Int = 0
        var path: [PathNode] = []
        var moveProgress: Float = 0
        var isActive: Bool = false
        var seatIdx: Int = -1
        var agentId: Int = -1
        var homeZone: SocialZone = .breakRoom
        var toolName: String = ""
        var idleActivity: IdleActivity = .none
        var activityDir: Dir = .down
        var activityTimer: Float = 0
        var activityCooldown: Bool = false
        var bubbleType: Int = 0   // 0=none, 1=permission, 2=waiting, 3=info
        var bubbleTimer: Float = 0
        var hasPlayedJobSound: Bool = false
        var effectTimer: Float = 0
        var alive: Bool = false
        var isMini: Bool = false
        var deskIdx: Int = -1
    }

    // MARK: - Pet

    struct Pet {
        var x: Float = 0
        var y: Float = 0
        var tileCol: Int = 0
        var tileRow: Int = 0
        var dir: Dir = .right
        var path: [PathNode] = []
        var pathLen: Int = 0
        var pathIdx: Int = 0
        var moveProgress: Float = 0
        var frame: Int = 0
        var frameTimer: Float = 0
        var walking: Bool = false
        var isRunning: Bool = false
        var idleFrame: Int = 0
        var idleFrameTimer: Float = 0
        var isSitting: Bool = false
        var peeTimer: Float = 0
        var isPeeing: Bool = false
        var behavior: DogBehavior = .wander
        var phaseTimer: Float = 0
        var napTimer: Float = 0
        var napRemaining: Float = 0
        var targetPickTimer: Float = 0
        var repathTimer: Float = 0
        var followTarget: Int = -1
        var lastTargetCol: Int = -1
        var lastTargetRow: Int = -1
        var wanderTimer: Float = 0
    }
}

// MARK: - OfficeScene

@MainActor
final class OfficeScene {

    // MARK: - Scene State

    var characters: [OfficeSim.Character]
    var pet: OfficeSim.Pet
    var dogEnabled: Bool = true
    var dogColor: OfficeSim.DogColor = .brown

    // MARK: - Internal State

    private(set) var tiles: [[OfficeSim.TileType]]

    /// Tracks the last-applied state per agent ID to avoid re-applying unchanged states every frame.
    private var lastAppliedStates: [UInt8: (CharState, String)] = [:]

    /// Clears the dedup cache so the next applyAgentStates re-applies all states.
    func resetAppliedStates() {
        lastAppliedStates.removeAll()
    }

    // MARK: - Sound Queue

    /// Pending sound effects queued during state transitions, consumed by BridgeService each tick.
    private(set) var pendingSounds: [SoundEffect] = []

    /// Queues a sound effect to be played after the current tick.
    private func queueSound(_ sound: SoundEffect) {
        pendingSounds.append(sound)
    }

    /// Drains and returns all pending sounds.
    func consumePendingSounds() -> [SoundEffect] {
        guard !pendingSounds.isEmpty else { return [] }
        let sounds = pendingSounds
        pendingSounds.removeAll()
        return sounds
    }

    // MARK: - Init

    init() {
        // Initialize tile map
        tiles = Array(
            repeating: Array(repeating: OfficeSim.TileType.floor, count: OfficeSim.gridCols),
            count: OfficeSim.gridRows
        )

        // Initialize desk characters (0..<maxDeskAgents) as alive; mini slots start dead
        characters = (0..<OfficeSim.maxAgents).map { i in
            var ch = OfficeSim.Character(id: i)
            ch.isMini = (i >= OfficeSim.maxDeskAgents)
            ch.deskIdx = -1
            if i < OfficeSim.maxDeskAgents {
                ch.alive = true
                ch.palette = i % OfficeSim.numPalettes
                ch.state = .idle
                ch.isActive = false
                ch.seatIdx = -1
                ch.agentId = -1
                ch.homeZone = (i < 3) ? .breakRoom : .library
                ch.dir = .down
                ch.frame = 0
                ch.frameTimer = 0
                ch.wanderTimer = Float.random(in: OfficeSim.wanderPauseMinSec...OfficeSim.wanderPauseMaxSec)
                ch.wanderCount = 0
                ch.wanderLimit = Int.random(in: OfficeSim.wanderMovesMin...OfficeSim.wanderMovesMax)
                ch.pathLen = 0
                ch.pathIdx = 0
                ch.idleActivity = .none
                ch.activityDir = .down
                ch.activityTimer = 0
                ch.activityCooldown = false
                ch.bubbleType = 0
                ch.bubbleTimer = 0
                ch.effectTimer = 0
                ch.toolName = ""
            }
            return ch
        }

        // Initialize pet
        pet = OfficeSim.Pet()

        // Build tile map (must happen before placing characters)
        initTileMap()

        // Place desk characters in their home zones
        for i in 0..<OfficeSim.maxDeskAgents {
            placeCharacterInZone(&characters[i])
        }

        // Place pet
        initPet()
    }

    // MARK: - Tile Map Initialization

    private func initTileMap() {
        // All tiles start as floor (already initialized in init)

        // Mark desk tiles as blocked (2x2 per workstation)
        for ws in OfficeSim.workstations {
            for dr in 0..<2 {
                for dc in 0..<2 {
                    let r = ws.deskRow + dr
                    let c = ws.deskCol + dc
                    if r >= 0 && r < OfficeSim.gridRows && c >= 0 && c < OfficeSim.gridCols {
                        tiles[r][c] = .blocked
                    }
                }
            }
        }

        // Water Cooler at col 12, rows 0-2
        tiles[0][12] = .blocked
        tiles[1][12] = .blocked
        tiles[2][12] = .blocked
        // Counter Top at col 16, row 1
        tiles[1][16] = .blocked
        tiles[1][17] = .blocked
        // Counter Top at col 14, row 1
        tiles[1][14] = .blocked
        tiles[1][15] = .blocked
        // Counter Bottom A at col 14, row 2
        tiles[2][14] = .blocked
        tiles[2][15] = .blocked
        // Counter Bottom A at col 16, row 2
        tiles[2][16] = .blocked
        tiles[2][17] = .blocked
        // Coffee Maker at col 16, rows 0-1
        tiles[0][16] = .blocked
        tiles[1][16] = .blocked
        // Coffee Maker at col 17, rows 0-1
        tiles[0][17] = .blocked
        tiles[1][17] = .blocked
        // Vending Machine at col 18, rows 0-2
        tiles[0][18] = .blocked
        tiles[0][19] = .blocked
        tiles[1][18] = .blocked
        tiles[1][19] = .blocked
        tiles[2][18] = .blocked
        tiles[2][19] = .blocked
        // Plant Top E at col 13, row 1
        tiles[1][13] = .blocked
        // Plant Bottom White at col 13, row 2
        tiles[2][13] = .blocked
        // Computer E at col 1, row 12
        tiles[12][1] = .blocked
        tiles[12][2] = .blocked
        tiles[12][3] = .blocked
        // Computer G at col 7, row 12
        tiles[12][7] = .blocked
        // Laptop B at col 2, rows 6-7
        tiles[6][2] = .blocked
        tiles[7][2] = .blocked
        // Computer B at col 7, rows 6-7
        tiles[6][7] = .blocked
        tiles[6][8] = .blocked
        tiles[7][7] = .blocked
        tiles[7][8] = .blocked
        // Plant Bottom Brown at col 9, row 13
        tiles[13][9] = .blocked
        // Plant Bottom Brown at col 0, row 13
        tiles[13][0] = .blocked
        // Plant Top C at col 0, row 12
        tiles[12][0] = .blocked
        // Plant Top D at col 9, row 12
        tiles[12][9] = .blocked
        // Bookshelf A at col 12, rows 5-7
        tiles[5][12] = .blocked
        tiles[5][13] = .blocked
        tiles[6][12] = .blocked
        tiles[6][13] = .blocked
        tiles[7][12] = .blocked
        tiles[7][13] = .blocked
        // Bookshelf A at col 16, rows 5-7
        tiles[5][16] = .blocked
        tiles[5][17] = .blocked
        tiles[6][16] = .blocked
        tiles[6][17] = .blocked
        tiles[7][16] = .blocked
        tiles[7][17] = .blocked
        // Bookshelf B at col 14, rows 5-7
        tiles[5][14] = .blocked
        tiles[5][15] = .blocked
        tiles[6][14] = .blocked
        tiles[6][15] = .blocked
        tiles[7][14] = .blocked
        tiles[7][15] = .blocked
        // Bookshelf B at col 18, rows 5-7
        tiles[5][18] = .blocked
        tiles[5][19] = .blocked
        tiles[6][18] = .blocked
        tiles[6][19] = .blocked
        tiles[7][18] = .blocked
        tiles[7][19] = .blocked
        // Plant Top G at col 11, row 5
        tiles[5][11] = .blocked
        // Plant Bottom White at col 11, row 6
        tiles[6][11] = .blocked
        // Plant Top 2 at col 18, row 12
        tiles[12][18] = .blocked
        // Plant Bottom White at col 18, row 13
        tiles[13][18] = .blocked
        // Plant Bottom White at col 14, row 13
        tiles[13][14] = .blocked
        // Plant Top 2 at col 14, row 12
        tiles[12][14] = .blocked
        // Bookshelf Wood 1 at col 1, rows 0-1
        tiles[0][1] = .blocked
        tiles[0][2] = .blocked
        tiles[0][3] = .blocked
        tiles[1][1] = .blocked
        tiles[1][2] = .blocked
        tiles[1][3] = .blocked
        // Bookshelf Wood 1 at col 6, rows 0-1
        tiles[0][6] = .blocked
        tiles[0][7] = .blocked
        tiles[0][8] = .blocked
        tiles[1][6] = .blocked
        tiles[1][7] = .blocked
        tiles[1][8] = .blocked
        // Bookshelf Wood 2 at col 4, rows 0-1
        tiles[0][4] = .blocked
        tiles[0][5] = .blocked
        tiles[1][4] = .blocked
        tiles[1][5] = .blocked
        // Plant Top C at col 0, row 0
        tiles[0][0] = .blocked
        // Plant Top D at col 9, row 0
        tiles[0][9] = .blocked
        // Plant Bottom Brown at col 0, row 1
        tiles[1][0] = .blocked
        // Plant Bottom Brown at col 9, row 1
        tiles[1][9] = .blocked
        // Table at col 19, rows 3-4
        tiles[3][19] = .blocked
        tiles[4][19] = .blocked
        // Laptop C at col 6, rows 4-5
        tiles[4][6] = .blocked
        tiles[5][6] = .blocked
        // Laptop D at col 3, rows 4-5
        tiles[4][3] = .blocked
        tiles[5][3] = .blocked
        // Box at col 8, row 3
        tiles[3][8] = .blocked
        // Boxes 2 at col 6, rows 2-3
        tiles[2][6] = .blocked
        tiles[2][7] = .blocked
        tiles[3][6] = .blocked
        tiles[3][7] = .blocked
        // Boxes 1 at col 1, rows 2-3
        tiles[2][1] = .blocked
        tiles[2][2] = .blocked
        tiles[3][1] = .blocked
        tiles[3][2] = .blocked
        // Plant Top H at col 11, row 6
        tiles[6][11] = .blocked
        // Plant Bottom White at col 11, row 7
        tiles[7][11] = .blocked
        // Microwave at col 14, row 1
        tiles[1][14] = .blocked
        tiles[1][15] = .blocked
        // Trash at col 11, rows 1-2
        tiles[1][11] = .blocked
        tiles[2][11] = .blocked
    }

    // MARK: - Character Placement

    private func placeCharacterInZone(_ ch: inout OfficeSim.Character) {
        let (colMin, colMax, rowMin, rowMax) = zoneBounds(ch.homeZone)

        // Try random tiles in zone
        for _ in 0..<40 {
            let col = Int.random(in: colMin...colMax)
            let row = Int.random(in: rowMin...rowMax)
            if isWalkable(col: col, row: row) {
                ch.tileCol = col
                ch.tileRow = row
                ch.x = Float(col) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
                ch.y = Float(row) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
                return
            }
        }

        // Fallback: scan zone for any walkable tile
        for r in rowMin...rowMax {
            for c in colMin...colMax {
                if isWalkable(col: c, row: r) {
                    ch.tileCol = c
                    ch.tileRow = r
                    ch.x = Float(c) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
                    ch.y = Float(r) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
                    return
                }
            }
        }

        // Last resort: center of map
        ch.tileCol = 10
        ch.tileRow = 3
        ch.x = 10 * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
        ch.y = 3 * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
    }

    // MARK: - Pet Initialization

    private func initPet() {
        pet = OfficeSim.Pet()
        pet.dir = .right
        pet.behavior = .wander
        pet.phaseTimer = OfficeSim.dogWanderDurationSec
        pet.napTimer = OfficeSim.dogNapIntervalSec
        pet.targetPickTimer = OfficeSim.dogPickTargetSec
        pet.followTarget = -1
        pet.lastTargetCol = -1
        pet.lastTargetRow = -1
        pet.wanderTimer = Float.random(in: OfficeSim.dogWanderPauseMinSec...OfficeSim.dogWanderPauseMaxSec)

        // Place at a random walkable tile
        for _ in 0..<40 {
            let col = Int.random(in: 2...(OfficeSim.gridCols - 2))
            let row = Int.random(in: 2...(OfficeSim.gridRows - 2))
            if isWalkable(col: col, row: row) {
                pet.tileCol = col
                pet.tileRow = row
                pet.x = Float(col) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
                pet.y = Float(row) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
                return
            }
        }
        // Fallback
        pet.tileCol = 5
        pet.tileRow = 3
        pet.x = 5 * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
        pet.y = 3 * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
    }

    // MARK: - Zone Bounds Helper

    private func zoneBounds(_ zone: OfficeSim.SocialZone) -> (colMin: Int, colMax: Int, rowMin: Int, rowMax: Int) {
        switch zone {
        case .breakRoom:
            return (OfficeSim.zoneBreakColMin, OfficeSim.zoneBreakColMax,
                    OfficeSim.zoneBreakRowMin, OfficeSim.zoneBreakRowMax)
        case .library:
            return (OfficeSim.zoneLibColMin, OfficeSim.zoneLibColMax,
                    OfficeSim.zoneLibRowMin, OfficeSim.zoneLibRowMax)
        }
    }

    // MARK: - Update (called at 15 FPS)

    func update(dt: Float) {
        // Copy-out/mutate/copy-back pattern: avoids Swift exclusivity violation
        // where updateCharacter's inout locks the array while methods like
        // pickActivityTarget and findSocializeTarget need to read other elements.
        for i in 0..<characters.count {
            guard characters[i].alive else { continue }
            var ch = characters[i]
            updateCharacter(&ch, dt: dt)
            characters[i] = ch
        }
        if dogEnabled {
            updatePet(dt: dt)
        }
    }

    // MARK: - Apply Agent States from BridgeService

    /// Syncs the simulation with the agent states from BridgeService.displayAgents.
    /// Converts the app's `CharState` to the simulation's `OfficeSim.SimCharState`.
    func applyAgentStates(_ agents: [Agent]) {
        // Track which character indices are still assigned
        var assignedCharIndices = Set<Int>()

        for agent in agents {
            let appState = agent.state
            let toolName = agent.toolName

            // Dedup: skip if state+tool unchanged since last apply (prevents re-triggering walks every frame)
            if let last = lastAppliedStates[agent.id], last.0 == appState, last.1 == toolName {
                // Still track assignment so we don't prune
                if appState != .offline, let idx = findCharByAgentId(Int(agent.id)) {
                    assignedCharIndices.insert(idx)
                }
                continue
            }
            lastAppliedStates[agent.id] = (appState, toolName)

            // Map app CharState to sim SimCharState
            let simState: OfficeSim.SimCharState
            switch appState {
            case .offline: simState = .offline
            case .idle:    simState = .idle
            case .walk:    simState = .walk
            case .type:    simState = .type
            case .read:    simState = .read
            case .spawn:   simState = .spawn
            case .despawn: simState = .despawn
            }

            if simState == .offline {
                lastAppliedStates.removeValue(forKey: agent.id)
                if let idx = findCharByAgentId(Int(agent.id)) {
                    characters[idx].agentId = -1
                    characters[idx].isActive = false
                    characters[idx].toolName = ""
                    characters[idx].bubbleType = 0
                    characters[idx].bubbleTimer = 0
                    characters[idx].idleActivity = .none
                    characters[idx].activityTimer = 0
                    characters[idx].activityCooldown = false
                    characters[idx].hasPlayedJobSound = false
                    characters[idx].seatIdx = -1
                    if characters[idx].isMini {
                        characters[idx].state = .despawn
                        characters[idx].effectTimer = 0
                    } else {
                        walkToZone(&characters[idx])
                    }
                }
                continue
            }

            guard let idx = findOrAssignChar(agentId: Int(agent.id)) else { continue }
            assignedCharIndices.insert(idx)

            // Clear any idle activity state (agent preemption)
            characters[idx].idleActivity = .none
            characters[idx].activityTimer = 0
            characters[idx].activityCooldown = false

            // Store tool name
            characters[idx].toolName = toolName

            characters[idx].isActive = (simState == .type || simState == .read)

            // Sound triggers (mirroring firmware office_state.cpp)
            if simState == .type || simState == .read {
                if !characters[idx].hasPlayedJobSound {
                    characters[idx].hasPlayedJobSound = true
                    queueSound(.keyboardType)
                }
                if toolName == "PERMISSION" {
                    queueSound(.minimalPop)
                }
            } else if simState == .idle {
                queueSound(.notificationClick)
            }

            // Determine actual animation state from protocol state
            if simState == .type || simState == .read {
                if characters[idx].isMini {
                    // Mini-agents stand near their desk and walk-in-place
                    characters[idx].state = OfficeSim.isReadingTool(toolName) ? .read : .type
                    if characters[idx].deskIdx >= 0 && characters[idx].deskIdx < OfficeSim.workstations.count {
                        characters[idx].dir = OfficeSim.workstations[characters[idx].deskIdx].facingDir
                    }
                    characters[idx].frame = 0
                    characters[idx].frameTimer = 0
                } else {
                    // Assign a seat if not already seated
                    if characters[idx].seatIdx < 0 {
                        characters[idx].seatIdx = findFreeSeat()
                    }
                    // Active: go to desk
                    if characters[idx].seatIdx >= 0 {
                        let ws = OfficeSim.workstations[characters[idx].seatIdx]
                        if characters[idx].tileCol == ws.seatCol && characters[idx].tileRow == ws.seatRow {
                            characters[idx].state = OfficeSim.isReadingTool(toolName) ? .read : .type
                            characters[idx].dir = ws.facingDir
                            characters[idx].frame = 0
                            characters[idx].frameTimer = 0
                        } else {
                            startWalk(&characters[idx], goalCol: ws.seatCol, goalRow: ws.seatRow)
                        }
                    } else {
                        characters[idx].state = OfficeSim.isReadingTool(toolName) ? .read : .type
                        characters[idx].frame = 0
                        characters[idx].frameTimer = 0
                    }
                }
            } else if simState == .idle {
                // Release seat if character was heading to desk or working
                if characters[idx].state == .type || characters[idx].state == .read ||
                    (characters[idx].state == .walk && characters[idx].seatIdx >= 0) {
                    characters[idx].seatIdx = -1
                }
                characters[idx].isActive = false
                characters[idx].hasPlayedJobSound = false
            }

            // Handle bubble for special states (no bubbles for mini-agents)
            if characters[idx].isMini {
                characters[idx].bubbleType = 0
            } else if simState == .type && toolName == "PERMISSION" {
                characters[idx].bubbleType = 1  // permission
                characters[idx].bubbleTimer = OfficeSim.permissionBubbleDurationSec
            } else if simState == .idle {
                characters[idx].bubbleType = 2  // waiting
                characters[idx].bubbleTimer = OfficeSim.waitingBubbleDurationSec
            } else {
                characters[idx].bubbleType = 0
            }
        }

        // Cleanup: despawn any characters whose agentId isn't in the current agent list.
        // This handles mini-agents that were assigned higher IDs (6, 7, ...) that no longer
        // appear in displayAgents after agents are pruned from the tracker.
        let activeAgentIds = Set(agents.filter { $0.state != .offline }.map { Int($0.id) })
        for i in 0..<characters.count {
            guard characters[i].alive, characters[i].agentId >= 0 else { continue }
            if assignedCharIndices.contains(i) { continue }
            if activeAgentIds.contains(characters[i].agentId) { continue }
            // Orphaned character — unassign and despawn/walk-to-zone
            characters[i].agentId = -1
            characters[i].isActive = false
            characters[i].toolName = ""
            characters[i].bubbleType = 0
            characters[i].bubbleTimer = 0
            characters[i].seatIdx = -1
            if characters[i].isMini {
                characters[i].state = .despawn
                characters[i].effectTimer = 0
            } else {
                walkToZone(&characters[i])
            }
            lastAppliedStates = lastAppliedStates.filter { $0.value.0 != .offline || Int($0.key) != characters[i].id }
        }
    }

    // MARK: - Character Update

    private func updateCharacter(_ ch: inout OfficeSim.Character, dt: Float) {
        ch.frameTimer += dt

        // Handle spawn/despawn effects
        if ch.state == .spawn {
            ch.effectTimer += dt
            if ch.effectTimer >= OfficeSim.spawnDurationSec {
                ch.state = .idle
                ch.frame = 0
                ch.frameTimer = 0
            }
            return
        }

        if ch.state == .despawn {
            ch.effectTimer += dt
            if ch.effectTimer >= OfficeSim.spawnDurationSec {
                if ch.isMini {
                    ch.alive = false
                    ch.agentId = -1
                    ch.deskIdx = -1
                } else {
                    ch.state = .idle
                    ch.frame = 0
                    ch.frameTimer = 0
                }
            }
            return
        }

        switch ch.state {
        case .type, .read:
            if ch.isMini {
                // Walk-in-place animation for mini-agents
                if ch.frameTimer >= OfficeSim.walkFrameDurationSec {
                    ch.frameTimer -= OfficeSim.walkFrameDurationSec
                    ch.frame = (ch.frame + 1) % 4
                }
            } else {
                if ch.frameTimer >= OfficeSim.typeFrameDurationSec {
                    ch.frameTimer -= OfficeSim.typeFrameDurationSec
                    ch.frame = (ch.frame + 1) % 2
                }
            }
            if !ch.isActive {
                ch.state = .idle
                ch.frame = 0
                ch.frameTimer = 0
                if !ch.isMini && ch.bubbleType == 0 {
                    ch.bubbleType = 2  // waiting
                    ch.bubbleTimer = OfficeSim.waitingBubbleDurationSec
                }
                ch.seatIdx = -1
                if !ch.isMini {
                    walkToZone(&ch)
                }
            }

        case .idle:
            ch.frame = 0

            // If became active, transition to working state
            if ch.isActive {
                if ch.isMini {
                    // Mini-agents start walk-in-place immediately
                    ch.state = OfficeSim.isReadingTool(ch.toolName) ? .read : .type
                    if ch.deskIdx >= 0 && ch.deskIdx < OfficeSim.workstations.count {
                        ch.dir = OfficeSim.workstations[ch.deskIdx].facingDir
                    }
                    ch.frame = 0
                    ch.frameTimer = 0
                    return
                } else if ch.seatIdx >= 0 {
                    let ws = OfficeSim.workstations[ch.seatIdx]
                    if ch.tileCol == ws.seatCol && ch.tileRow == ws.seatRow {
                        ch.state = .type
                        ch.dir = ws.facingDir
                    } else {
                        startWalk(&ch, goalCol: ws.seatCol, goalRow: ws.seatRow)
                    }
                    ch.frame = 0
                    ch.frameTimer = 0
                    return
                }
            }

            // Wander timer
            ch.wanderTimer -= dt
            if ch.wanderTimer <= 0 {
                if ch.isMini {
                    startMiniWander(&ch)
                } else if ch.agentId < 0 {
                    if !ch.activityCooldown && Float.random(in: 0...1) < OfficeSim.activityChance {
                        startIdleActivity(&ch)
                    } else {
                        startZoneWander(&ch)
                        ch.activityCooldown = false
                    }
                } else {
                    startWander(&ch)
                }
                ch.wanderTimer = Float.random(in: OfficeSim.wanderPauseMinSec...OfficeSim.wanderPauseMaxSec)
            }

        case .walk:
            // Walk animation: 4-frame cycle [walk1, walk2, walk3, walk2]
            if ch.frameTimer >= OfficeSim.walkFrameDurationSec {
                ch.frameTimer -= OfficeSim.walkFrameDurationSec
                ch.frame = (ch.frame + 1) % 4
            }

            if ch.pathIdx >= ch.pathLen {
                // Path complete
                let cx = Float(ch.tileCol) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
                let cy = Float(ch.tileRow) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
                ch.x = cx
                ch.y = cy

                if ch.isMini && ch.isActive {
                    // Mini-agent arrived near desk: face desk and walk-in-place
                    ch.state = OfficeSim.isReadingTool(ch.toolName) ? .read : .type
                    if ch.deskIdx >= 0 && ch.deskIdx < OfficeSim.workstations.count {
                        ch.dir = OfficeSim.workstations[ch.deskIdx].facingDir
                    }
                } else if !ch.isMini && ch.isActive && ch.seatIdx >= 0 {
                    let ws = OfficeSim.workstations[ch.seatIdx]
                    if ch.tileCol == ws.seatCol && ch.tileRow == ws.seatRow {
                        ch.state = OfficeSim.isReadingTool(ch.toolName) ? .read : .type
                        ch.dir = ws.facingDir
                    } else {
                        ch.state = .idle
                    }
                } else if ch.idleActivity != .none {
                    // Arrived at activity destination
                    ch.state = .activity
                    ch.dir = ch.activityDir
                    ch.activityTimer = Float.random(in: OfficeSim.activityDurationMinSec...OfficeSim.activityDurationMaxSec)
                    ch.frame = 0
                    ch.frameTimer = 0
                } else {
                    ch.state = .idle
                    ch.wanderTimer = Float.random(in: OfficeSim.wanderPauseMinSec...OfficeSim.wanderPauseMaxSec)
                }
                ch.frame = 0
                ch.frameTimer = 0
                return
            }

            // Move toward next tile
            let next = ch.path[ch.pathIdx]

            // Update direction
            let dc = next.col - ch.tileCol
            let dr = next.row - ch.tileRow
            if dc > 0 { ch.dir = .right }
            else if dc < 0 { ch.dir = .left }
            else if dr > 0 { ch.dir = .down }
            else { ch.dir = .up }

            ch.moveProgress += (OfficeSim.walkSpeedPxPerSec / OfficeSim.tileSize) * dt

            let fromX = Float(ch.tileCol) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
            let fromY = Float(ch.tileRow) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
            let toX = Float(next.col) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
            let toY = Float(next.row) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0

            let t = min(ch.moveProgress, 1.0)
            ch.x = fromX + (toX - fromX) * t
            ch.y = fromY + (toY - fromY) * t

            if ch.moveProgress >= 1.0 {
                ch.tileCol = next.col
                ch.tileRow = next.row
                ch.x = toX
                ch.y = toY
                ch.pathIdx += 1
                ch.moveProgress = 0
            }

        case .activity:
            // If agent became active, cancel activity immediately
            if ch.isActive {
                ch.state = .idle
                ch.idleActivity = .none
                ch.activityTimer = 0
                ch.frame = 0
                ch.frameTimer = 0
                return
            }

            // Animate reading activity (2-frame cycle)
            if ch.idleActivity == .reading {
                if ch.frameTimer >= OfficeSim.readActivityFrameSec {
                    ch.frameTimer -= OfficeSim.readActivityFrameSec
                    ch.frame = (ch.frame + 1) % 2
                }
            }
            // COFFEE/WATER/SOCIALIZING: standing frame, no animation

            // Count down activity duration
            ch.activityTimer -= dt
            if ch.activityTimer <= 0 {
                ch.state = .idle
                ch.idleActivity = .none
                ch.activityTimer = 0
                ch.activityCooldown = true
                ch.frame = 0
                ch.frameTimer = 0
                ch.wanderTimer = Float.random(in: OfficeSim.activityCooldownSec...(OfficeSim.activityCooldownSec + OfficeSim.wanderPauseMinSec))
                walkToZone(&ch)
            }

        default:
            break
        }

        // Tick bubble timer
        if ch.bubbleType > 0 && ch.bubbleTimer > 0 {
            ch.bubbleTimer -= dt
            if ch.bubbleTimer <= 0 {
                ch.bubbleType = 0
                ch.bubbleTimer = 0
            }
        }
    }

    // MARK: - Walk / Wander

    private func startWalk(_ ch: inout OfficeSim.Character, goalCol: Int, goalRow: Int) {
        if let path = findPath(fromCol: ch.tileCol, fromRow: ch.tileRow, toCol: goalCol, toRow: goalRow) {
            ch.path = path
            ch.pathLen = path.count
            ch.pathIdx = 0
            ch.moveProgress = 0
            ch.state = .walk
            ch.frame = 0
            ch.frameTimer = 0
        }
    }

    private func startWander(_ ch: inout OfficeSim.Character) {
        // Pick a random walkable tile anywhere
        for _ in 0..<20 {
            let col = Int.random(in: 1...(OfficeSim.gridCols - 2))
            let row = Int.random(in: 1...(OfficeSim.gridRows - 1))
            if isWalkable(col: col, row: row) {
                startWalk(&ch, goalCol: col, goalRow: row)
                ch.wanderCount += 1
                return
            }
        }
    }

    private func startZoneWander(_ ch: inout OfficeSim.Character) {
        let (colMin, colMax, rowMin, rowMax) = zoneBounds(ch.homeZone)

        for _ in 0..<30 {
            let col = Int.random(in: colMin...colMax)
            let row = Int.random(in: rowMin...rowMax)
            if isWalkable(col: col, row: row) {
                startWalk(&ch, goalCol: col, goalRow: row)
                ch.wanderCount += 1
                return
            }
        }
    }

    private func walkToZone(_ ch: inout OfficeSim.Character) {
        ch.idleActivity = .none
        let (colMin, colMax, rowMin, rowMax) = zoneBounds(ch.homeZone)

        // Try random tiles in zone
        for _ in 0..<30 {
            let col = Int.random(in: colMin...colMax)
            let row = Int.random(in: rowMin...rowMax)
            if isWalkable(col: col, row: row) {
                startWalk(&ch, goalCol: col, goalRow: row)
                return
            }
        }

        // Fallback: scan zone for any walkable tile
        for r in rowMin...rowMax {
            for c in colMin...colMax {
                if isWalkable(col: c, row: r) {
                    startWalk(&ch, goalCol: c, goalRow: r)
                    return
                }
            }
        }

        // If no walkable tile in zone, just go idle where we are
        ch.state = .idle
        ch.frame = 0
        ch.frameTimer = 0
        ch.wanderTimer = Float.random(in: OfficeSim.wanderPauseMinSec...OfficeSim.wanderPauseMaxSec)
    }

    // MARK: - Idle Activities

    private func startIdleActivity(_ ch: inout OfficeSim.Character) {
        // Roll random activity: READING 30%, COFFEE 20%, WATER 20%, SOCIALIZING 30%
        let roll = Float.random(in: 0...1)
        let activity: OfficeSim.IdleActivity
        if roll < 0.30 {
            activity = .reading
        } else if roll < 0.50 {
            activity = .coffee
        } else if roll < 0.70 {
            activity = .water
        } else {
            activity = .socializing
        }
        pickActivityTarget(&ch, activity: activity)
    }

    private func pickActivityTarget(_ ch: inout OfficeSim.Character, activity: OfficeSim.IdleActivity) {
        let charIdx = characters.firstIndex(where: { $0.id == ch.id }) ?? -1

        if activity == .socializing {
            // Find another idle/unassigned character to socialize with
            guard let target = findSocializeTarget(excludeIdx: charIdx) else {
                startZoneWander(&ch)
                return
            }

            let other = characters[target]
            let dxArr = [0, 0, 1, -1]
            let dyArr = [1, -1, 0, 0]

            for _ in 0..<8 {
                let d = Int.random(in: 0...3)
                let col = other.tileCol + dxArr[d]
                let row = other.tileRow + dyArr[d]
                if isWalkable(col: col, row: row) && isInteractionPointFree(col: col, row: row, excludeIdx: charIdx) {
                    ch.idleActivity = .socializing
                    // Compute facing direction toward target
                    let dcDir = other.tileCol - col
                    let drDir = other.tileRow - row
                    if dcDir > 0 { ch.activityDir = .right }
                    else if dcDir < 0 { ch.activityDir = .left }
                    else if drDir > 0 { ch.activityDir = .down }
                    else { ch.activityDir = .up }
                    startWalk(&ch, goalCol: col, goalRow: row)
                    if ch.state != .walk {
                        ch.idleActivity = .none
                    }
                    return
                }
            }
            // Couldn't find adjacent tile, fall back
            startZoneWander(&ch)
            return
        }

        // Furniture-based activities: READING, COFFEE, WATER
        let points: [OfficeSim.InteractionPoint]
        switch activity {
        case .reading:  points = OfficeSim.readingPoints
        case .coffee:   points = OfficeSim.coffeePoints
        case .water:    points = OfficeSim.waterPoints
        default:
            startZoneWander(&ch)
            return
        }

        // Try random interaction points
        for _ in 0..<(points.count * 2) {
            let idx = Int.random(in: 0..<points.count)
            let pt = points[idx]
            if isWalkable(col: pt.col, row: pt.row) && isInteractionPointFree(col: pt.col, row: pt.row, excludeIdx: charIdx) {
                ch.idleActivity = activity
                ch.activityDir = pt.facingDir
                startWalk(&ch, goalCol: pt.col, goalRow: pt.row)
                if ch.state != .walk {
                    ch.idleActivity = .none
                }
                return
            }
        }

        // All points occupied, fall back to zone wander
        startZoneWander(&ch)
    }

    private func isInteractionPointFree(col: Int, row: Int, excludeIdx: Int) -> Bool {
        for i in 0..<characters.count {
            if i == excludeIdx { continue }
            guard characters[i].alive else { continue }
            // Check if standing on this tile
            if characters[i].tileCol == col && characters[i].tileRow == row { return false }
            // Check if walking to this tile (last node in path)
            if characters[i].state == .walk && characters[i].pathLen > 0
                && characters[i].pathLen <= characters[i].path.count {
                let dest = characters[i].path[characters[i].pathLen - 1]
                if dest.col == col && dest.row == row { return false }
            }
        }
        return true
    }

    private func findSocializeTarget(excludeIdx: Int) -> Int? {
        var candidates: [Int] = []
        for i in 0..<characters.count {
            if i == excludeIdx { continue }
            guard characters[i].alive else { continue }
            guard characters[i].agentId < 0 else { continue }
            if characters[i].state == .idle || characters[i].state == .activity {
                candidates.append(i)
            }
        }
        guard !candidates.isEmpty else { return nil }
        return candidates[Int.random(in: 0..<candidates.count)]
    }

    // MARK: - Character Lookup

    private func findCharByAgentId(_ agentId: Int) -> Int? {
        for i in 0..<characters.count {
            if characters[i].alive && characters[i].agentId == agentId {
                return i
            }
        }
        return nil
    }

    private func findFreeSeat() -> Int {
        for s in 0..<OfficeSim.workstations.count {
            var taken = false
            for i in 0..<characters.count {
                if characters[i].alive && characters[i].seatIdx == s {
                    taken = true
                    break
                }
            }
            if !taken { return s }
        }
        return -1
    }

    private func findOrAssignChar(agentId: Int) -> Int? {
        // First: find a character already assigned to this agentId (all slots)
        if let existing = findCharByAgentId(agentId) {
            return existing
        }

        // Second: find an idle desk agent (0..<maxDeskAgents)
        for i in 0..<OfficeSim.maxDeskAgents {
            if characters[i].alive && characters[i].agentId < 0 &&
                (characters[i].state == .idle || characters[i].state == .walk ||
                 characters[i].state == .activity) {
                characters[i].agentId = agentId
                return i
            }
        }

        // Third: all desk agents busy — try mini-agent slots
        return findOrAssignMini(agentId: agentId)
    }

    private func findOrAssignMini(agentId: Int) -> Int? {
        // Find existing alive mini not assigned
        for i in OfficeSim.maxDeskAgents..<OfficeSim.maxAgents {
            if characters[i].alive && characters[i].agentId < 0 &&
                (characters[i].state == .idle || characters[i].state == .walk) {
                characters[i].agentId = agentId
                return i
            }
        }

        // Spawn a new mini-agent in a dead slot
        for i in OfficeSim.maxDeskAgents..<OfficeSim.maxAgents {
            if !characters[i].alive {
                characters[i] = OfficeSim.Character(id: i)
                characters[i].alive = true
                characters[i].isMini = true
                characters[i].palette = i % OfficeSim.numPalettes
                characters[i].agentId = agentId
                characters[i].seatIdx = -1
                characters[i].deskIdx = leastLoadedDesk()
                characters[i].homeZone = characters[i].deskIdx < 3 ? .breakRoom : .library
                characters[i].state = .spawn
                characters[i].effectTimer = 0
                characters[i].dir = .down
                characters[i].toolName = ""
                pickMiniPosition(i)
                return i
            }
        }
        return nil  // all 18 slots full
    }

    private func leastLoadedDesk() -> Int {
        var counts = [Int](repeating: 0, count: OfficeSim.workstations.count)
        for i in OfficeSim.maxDeskAgents..<OfficeSim.maxAgents {
            if characters[i].alive && characters[i].deskIdx >= 0 && characters[i].deskIdx < counts.count {
                counts[characters[i].deskIdx] += 1
            }
        }
        return counts.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }

    private func pickMiniPosition(_ idx: Int) {
        let deskIdx = characters[idx].deskIdx
        guard deskIdx >= 0 && deskIdx < OfficeSim.workstations.count else {
            characters[idx].tileCol = 10; characters[idx].tileRow = 3
            characters[idx].x = Float(10) * OfficeSim.tileSize + OfficeSim.tileSize / 2
            characters[idx].y = Float(3) * OfficeSim.tileSize + OfficeSim.tileSize / 2
            return
        }
        let ws = OfficeSim.workstations[deskIdx]
        for _ in 0..<40 {
            let col = Int.random(in: (ws.deskCol - 2)...(ws.deskCol + 3))
            let row = Int.random(in: (ws.deskRow - 2)...(ws.deskRow + 3))
            if col == ws.seatCol && row == ws.seatRow { continue }
            if isWalkable(col: col, row: row) {
                characters[idx].tileCol = col
                characters[idx].tileRow = row
                characters[idx].x = Float(col) * OfficeSim.tileSize + OfficeSim.tileSize / 2
                characters[idx].y = Float(row) * OfficeSim.tileSize + OfficeSim.tileSize / 2
                return
            }
        }
        // Fallback
        characters[idx].tileCol = ws.seatCol
        characters[idx].tileRow = ws.seatRow + 1
        characters[idx].x = Float(ws.seatCol) * OfficeSim.tileSize + OfficeSim.tileSize / 2
        characters[idx].y = Float(ws.seatRow + 1) * OfficeSim.tileSize + OfficeSim.tileSize / 2
    }

    private func startMiniWander(_ ch: inout OfficeSim.Character) {
        let dIdx = ch.deskIdx
        guard dIdx >= 0 && dIdx < OfficeSim.workstations.count else {
            startZoneWander(&ch)
            return
        }
        let ws = OfficeSim.workstations[dIdx]
        for _ in 0..<20 {
            let col = Int.random(in: (ws.deskCol - 2)...(ws.deskCol + 3))
            let row = Int.random(in: (ws.deskRow - 2)...(ws.deskRow + 3))
            if col == ws.seatCol && row == ws.seatRow { continue }
            if isWalkable(col: col, row: row) {
                startWalk(&ch, goalCol: col, goalRow: row)
                return
            }
        }
    }

    // MARK: - Pathfinding (BFS)

    private func isWalkable(col: Int, row: Int) -> Bool {
        guard col >= 0 && col < OfficeSim.gridCols && row >= 0 && row < OfficeSim.gridRows else {
            return false
        }
        return tiles[row][col] == .floor
    }

    private func findPath(fromCol: Int, fromRow: Int, toCol: Int, toRow: Int) -> [OfficeSim.PathNode]? {
        if fromCol == toCol && fromRow == toRow {
            return []
        }

        let dxArr = [0, 0, 1, -1]
        let dyArr = [1, -1, 0, 0]

        // BFS with parent tracking
        var visited = Array(repeating: Array(repeating: false, count: OfficeSim.gridCols), count: OfficeSim.gridRows)
        var parentCol = Array(repeating: Array(repeating: -1, count: OfficeSim.gridCols), count: OfficeSim.gridRows)
        var parentRow = Array(repeating: Array(repeating: -1, count: OfficeSim.gridCols), count: OfficeSim.gridRows)

        struct QNode {
            let col: Int
            let row: Int
        }

        var queue: [QNode] = []
        queue.reserveCapacity(OfficeSim.gridRows * OfficeSim.gridCols)
        var qHead = 0

        visited[fromRow][fromCol] = true
        queue.append(QNode(col: fromCol, row: fromRow))

        var found = false
        while qHead < queue.count {
            let cur = queue[qHead]
            qHead += 1

            if cur.col == toCol && cur.row == toRow {
                found = true
                break
            }

            for d in 0..<4 {
                let nc = cur.col + dxArr[d]
                let nr = cur.row + dyArr[d]
                guard nc >= 0 && nc < OfficeSim.gridCols && nr >= 0 && nr < OfficeSim.gridRows else { continue }
                guard !visited[nr][nc] else { continue }
                // Allow walking to destination even if it's "blocked" (e.g., seat tile)
                if !isWalkable(col: nc, row: nr) && !(nc == toCol && nr == toRow) { continue }
                visited[nr][nc] = true
                parentCol[nr][nc] = cur.col
                parentRow[nr][nc] = cur.row
                queue.append(QNode(col: nc, row: nr))
            }
        }

        guard found else { return nil }

        // Reconstruct path (reverse)
        var revPath: [OfficeSim.PathNode] = []
        var cc = toCol, cr = toRow
        while cc != fromCol || cr != fromRow {
            if revPath.count >= OfficeSim.maxPathLen { return nil }
            revPath.append(OfficeSim.PathNode(col: cc, row: cr))
            let pc = parentCol[cr][cc]
            let pr = parentRow[cr][cc]
            cc = pc
            cr = pr
        }

        // Reverse into output
        return revPath.reversed()
    }

    // MARK: - Pet Update

    private func updatePet(dt: Float) {
        pet.frameTimer += dt

        // Nap timer (always counts down)
        pet.napTimer -= dt
        if pet.behavior != .nap && pet.napTimer <= 0 {
            pet.behavior = .nap
            pet.napRemaining = OfficeSim.dogNapDurationSec
            pet.walking = false
            pet.isRunning = false
            pet.pathLen = 0
            pet.frame = 0
            pet.frameTimer = 0
            pet.isSitting = false
            pet.isPeeing = false
        }

        // Idle animations (cycle 8 idle frames)
        if !pet.walking && !pet.isPeeing && pet.behavior != .nap {
            pet.idleFrameTimer += dt
            if pet.idleFrameTimer >= OfficeSim.dogIdleFrameSec {
                pet.idleFrameTimer -= OfficeSim.dogIdleFrameSec
                pet.idleFrame = (pet.idleFrame + 1) % OfficeSim.dogIdleCount
            }
        }

        // Pee timer tick
        if pet.isPeeing {
            pet.peeTimer -= dt
            if pet.peeTimer <= 0 { pet.isPeeing = false }
        }

        // Behavior FSM
        switch pet.behavior {
        case .nap:
            pet.napRemaining -= dt
            if pet.napRemaining <= 0 {
                pet.behavior = .wander
                pet.phaseTimer = OfficeSim.dogWanderDurationSec
                pet.napTimer = OfficeSim.dogNapIntervalSec
                pet.wanderTimer = Float.random(in: OfficeSim.dogWanderPauseMinSec...OfficeSim.dogWanderPauseMaxSec)
            }

        case .follow:
            pet.phaseTimer -= dt
            pet.targetPickTimer -= dt

            if pet.phaseTimer <= 0 {
                pet.behavior = .wander
                pet.phaseTimer = OfficeSim.dogWanderDurationSec
                pet.followTarget = -1
                pet.isSitting = false
                pet.wanderTimer = Float.random(in: OfficeSim.dogWanderPauseMinSec...OfficeSim.dogWanderPauseMaxSec)
                return
            }

            if pet.targetPickTimer <= 0 {
                petPickTarget()
                pet.targetPickTimer = OfficeSim.dogPickTargetSec
            }

            // Check if follow target is seated -- dog sits nearby
            pet.isSitting = false
            if pet.followTarget >= 0 && pet.followTarget < characters.count && !pet.walking {
                let target = characters[pet.followTarget]
                if target.alive && (target.state == .type || target.state == .read) {
                    let dx = abs(pet.tileCol - target.tileCol)
                    let dy = abs(pet.tileRow - target.tileRow)
                    if dx + dy <= 2 {
                        pet.isSitting = true
                    }
                }
            }

            // Re-pathfind periodically while following (not while sitting)
            if !pet.walking && !pet.isSitting {
                pet.repathTimer -= dt
                if pet.repathTimer <= 0 {
                    petFollowNear()
                    pet.repathTimer = OfficeSim.dogFollowRepathfindSec
                }
            }

        case .wander:
            pet.phaseTimer -= dt
            pet.targetPickTimer -= dt

            if pet.phaseTimer <= 0 {
                pet.behavior = .follow
                pet.phaseTimer = OfficeSim.dogFollowDurationSec
                pet.isPeeing = false
                if pet.followTarget < 0 { petPickTarget() }
                pet.repathTimer = 0
                return
            }

            if pet.targetPickTimer <= 0 {
                petPickTarget()
                pet.targetPickTimer = OfficeSim.dogPickTargetSec
            }

            if !pet.walking && !pet.isPeeing {
                pet.wanderTimer -= dt
                if pet.wanderTimer <= 0 {
                    // Random chance to pee when pausing
                    if Float.random(in: 0...1) < OfficeSim.dogPeeChance {
                        pet.isPeeing = true
                        pet.peeTimer = OfficeSim.dogPeeDurationSec
                        pet.wanderTimer = OfficeSim.dogPeeDurationSec + 0.5
                    } else {
                        // Random chance this walk becomes a run
                        let run = Float.random(in: 0...1) < OfficeSim.dogRunChance
                        petWander()
                        if run && pet.walking {
                            pet.isRunning = true
                        }
                        pet.wanderTimer = Float.random(in: OfficeSim.dogWanderMoveMinSec...OfficeSim.dogWanderMoveMaxSec)
                    }
                }
            }
        }

        // Walk/run movement
        if pet.walking && pet.pathIdx < pet.pathLen {
            let frameDur = pet.isRunning ? OfficeSim.dogRunFrameDurationSec : OfficeSim.dogWalkFrameDurationSec
            let frameCount = pet.isRunning ? OfficeSim.dogRunCount : OfficeSim.dogWalkCount
            if pet.frameTimer >= frameDur {
                pet.frameTimer -= frameDur
                pet.frame = (pet.frame + 1) % frameCount
            }

            let next = pet.path[pet.pathIdx]

            let dc = next.col - pet.tileCol
            let dr = next.row - pet.tileRow
            if dc > 0 { pet.dir = .right }
            else if dc < 0 { pet.dir = .left }
            else if dr > 0 { pet.dir = .down }
            else { pet.dir = .up }

            let speed = pet.isRunning ? OfficeSim.dogRunSpeedPxPerSec : OfficeSim.dogWalkSpeedPxPerSec
            pet.moveProgress += (speed / OfficeSim.tileSize) * dt

            let fromX = Float(pet.tileCol) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
            let fromY = Float(pet.tileRow) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
            let toX = Float(next.col) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
            let toY = Float(next.row) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0

            let t = min(pet.moveProgress, 1.0)
            pet.x = fromX + (toX - fromX) * t
            pet.y = fromY + (toY - fromY) * t

            if pet.moveProgress >= 1.0 {
                pet.tileCol = next.col
                pet.tileRow = next.row
                pet.x = toX
                pet.y = toY
                pet.pathIdx += 1
                pet.moveProgress = 0
            }
        } else if pet.walking {
            pet.walking = false
            pet.isRunning = false
            pet.frame = 0
            pet.frameTimer = 0
            pet.x = Float(pet.tileCol) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
            pet.y = Float(pet.tileRow) * OfficeSim.tileSize + OfficeSim.tileSize / 2.0
        }
    }

    // MARK: - Pet Helpers

    private func petStartWalk(goalCol: Int, goalRow: Int) {
        if let path = findPath(fromCol: pet.tileCol, fromRow: pet.tileRow, toCol: goalCol, toRow: goalRow) {
            pet.path = path
            pet.pathLen = path.count
            pet.pathIdx = 0
            pet.moveProgress = 0
            pet.walking = true
            pet.isRunning = false
            pet.frame = 0
            pet.frameTimer = 0
        }
    }

    private func petWander() {
        for _ in 0..<20 {
            let col = Int.random(in: 1...(OfficeSim.gridCols - 2))
            let row = Int.random(in: 1...(OfficeSim.gridRows - 1))
            if isWalkable(col: col, row: row) {
                petStartWalk(goalCol: col, goalRow: row)
                return
            }
        }
    }

    private func petPickTarget() {
        let prevTarget = pet.followTarget
        var candidates: [Int] = []
        for i in 0..<characters.count {
            if characters[i].alive { candidates.append(i) }
        }
        guard !candidates.isEmpty else { return }
        let nextTarget = candidates[Int.random(in: 0..<candidates.count)]
        if nextTarget != prevTarget {
            pet.followTarget = nextTarget
            pet.lastTargetCol = -1
            pet.lastTargetRow = -1
            queueSound(.dogBark)
        }
    }

    private func petFollowNear() {
        guard pet.followTarget >= 0 && pet.followTarget < characters.count else { return }
        let target = characters[pet.followTarget]
        guard target.alive else {
            petPickTarget()
            return
        }

        let tCol = target.tileCol
        let tRow = target.tileRow

        // Hysteresis: only re-pathfind if target moved significantly
        if pet.lastTargetCol >= 0 {
            let dx = abs(tCol - pet.lastTargetCol)
            let dy = abs(tRow - pet.lastTargetRow)
            if dx + dy <= OfficeSim.dogFollowHysteresis { return }
        }

        // Already close enough?
        let distX = abs(pet.tileCol - tCol)
        let distY = abs(pet.tileRow - tRow)
        if distX + distY <= 2 { return }

        // Pick a walkable tile within DOG_FOLLOW_RADIUS of target
        for _ in 0..<30 {
            let col = tCol + Int.random(in: -OfficeSim.dogFollowRadius...OfficeSim.dogFollowRadius)
            let row = tRow + Int.random(in: -OfficeSim.dogFollowRadius...OfficeSim.dogFollowRadius)
            guard col >= 0 && col < OfficeSim.gridCols && row >= 0 && row < OfficeSim.gridRows else { continue }
            let d = abs(col - tCol) + abs(row - tRow)
            guard d >= 2 && d <= OfficeSim.dogFollowRadius else { continue }
            if isWalkable(col: col, row: row) {
                petStartWalk(goalCol: col, goalRow: row)
                pet.lastTargetCol = tCol
                pet.lastTargetRow = tRow
                return
            }
        }
    }
}
