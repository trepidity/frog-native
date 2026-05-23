import Foundation
import SwiftUI

@MainActor
class AuraSettings: ObservableObject {
    static let shared = AuraSettings()

    // Visual Aura Settings
    @AppStorage("aura.intensity")
    var auraIntensity: Double = 1.0

    @AppStorage("aura.showGuideLines")
    var showGuideLines: Bool = true

    @AppStorage("aura.frostedMaterials")
    var useFrostedMaterials: Bool = true

    // Temporal (Heatmap) Settings
    @AppStorage("aura.heatmapEnabled")
    var heatmapEnabled: Bool = true

    @AppStorage("aura.birthGlowDuration")
    var birthGlowDuration: Double = 5.0

    // Sensory Settings
    @AppStorage("aura.soundEnabled")
    var soundEnabled: Bool = true

    @AppStorage("aura.soundVolume")
    var soundVolume: Double = 0.5

    @AppStorage("aura.gitAuraEnabled")
    var gitAuraEnabled: Bool = true

    // Layout Defaults
    @AppStorage("aura.defaultLayout")
    var defaultLayout: String = "verticalTree"

    private init() {}
}
