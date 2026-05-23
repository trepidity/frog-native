import AppKit

@MainActor
class SoundManager {
    static let shared = SoundManager()
    
    enum AuraSound: String {
        case click = "Tink"
        case expansion = "Pop"
        case teleport = "Blow"
        case error = "Basso"
    }
    
    func play(_ sound: AuraSound) {
        guard sound == .error else { return }
        if let nsSound = NSSound(named: sound.rawValue) {
            nsSound.play()
        }
    }
}
