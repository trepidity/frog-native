import SwiftUI

struct PreferencesView: View {
    @StateObject private var settings = AuraSettings.shared
    
    var body: some View {
        TabView {
            GeneralPreferencesView(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            AuraPreferencesView(settings: settings)
                .tabItem {
                    Label("Aura", systemImage: "sparkles")
                }
            
            SensoryPreferencesView(settings: settings)
                .tabItem {
                    Label("Senses", systemImage: "speaker.wave.2")
                }
        }
        .frame(width: 450, height: 350)
        .padding(20)
    }
}

struct GeneralPreferencesView: View {
    @ObservedObject var settings: AuraSettings
    
    var body: some View {
        Form {
            Section("Layout") {
                Picker("Default Layout", selection: $settings.defaultLayout) {
                    Text("Vertical Tree").tag("verticalTree")
                    Text("Pro Table").tag("proTable")
                    Text("Classic List").tag("classic")
                    Text("Staircase").tag("staircase")
                }
            }
            
            Section("File Behavior") {
                Slider(value: $settings.birthGlowDuration, in: 1...30, step: 1) {
                    Text("New File Glow Duration")
                } minimumValueLabel: {
                    Text("1s")
                } maximumValueLabel: {
                    Text("30s")
                }
                Text("\(Int(settings.birthGlowDuration)) seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct AuraPreferencesView: View {
    @ObservedObject var settings: AuraSettings
    
    var body: some View {
        Form {
            Section("Aura Visuals") {
                Slider(value: $settings.auraIntensity, in: 0.1...2.0) {
                    Text("Aura Intensity")
                }
                
                Toggle("Show Hierarchical Guide Lines", isOn: $settings.showGuideLines)
                Toggle("Use Frosted Glass Materials", isOn: $settings.useFrostedMaterials)
            }
            
            Section("Intelligence") {
                Toggle("Enable Temporal Heatmap", isOn: $settings.heatmapEnabled)
                Toggle("Enable Git Health Visualization", isOn: $settings.gitAuraEnabled)
            }
        }
    }
}

struct SensoryPreferencesView: View {
    @ObservedObject var settings: AuraSettings
    
    var body: some View {
        Form {
            Section("Auditory Aura") {
                Toggle("Enable Sound Effects", isOn: $settings.soundEnabled)
                
                Slider(value: $settings.soundVolume, in: 0...1.0) {
                    Text("Sound Volume")
                }
                .disabled(!settings.soundEnabled)
            }
        }
    }
}
