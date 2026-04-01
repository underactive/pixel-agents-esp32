import AppKit

/// Sound effects that mirror the firmware's SoundId enum (minus STARTUP).
enum SoundEffect: String, CaseIterable {
    case keyboardType = "keyboard_type"
    case notificationClick = "notification_click"
    case minimalPop = "minimal_pop"
    case dogBark = "dog_bark"
}

/// Plays bundled MP3 sound effects for the software-rendered office scene.
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var sounds: [SoundEffect: NSSound] = [:]

    private init() {
        for effect in SoundEffect.allCases {
            if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3") {
                sounds[effect] = NSSound(contentsOf: url, byReference: true)
            }
        }
    }

    /// Volume level (0.0–1.0), read from UserDefaults each play.
    var volume: Float {
        guard let stored = UserDefaults.standard.object(forKey: SettingsKeys.softwareSoundVolume) as? Double else {
            return 0.65
        }
        return Float(stored)
    }

    func play(_ effect: SoundEffect) {
        guard let sound = sounds[effect] else { return }
        // Stop and restart if already playing (allows rapid re-trigger)
        if sound.isPlaying { sound.stop() }
        sound.volume = volume
        sound.play()
    }
}
