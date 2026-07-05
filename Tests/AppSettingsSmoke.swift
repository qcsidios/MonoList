import Foundation

@main
struct AppSettingsSmoke {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonoListSettingsTests-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("settings.json")
        let settings = AppSettings(fileURL: fileURL)

        precondition(settings.reminderEnabled)
        precondition(settings.reminderIntervalMinutes == 60)
        precondition(settings.reminderPosition == .topCenter)
        precondition(!settings.launchAtLogin)
        precondition(settings.globalShortcut == nil)

        try settings.update {
            $0.reminderEnabled = false
            $0.reminderIntervalMinutes = 90
            $0.reminderPosition = .topRight
            $0.globalShortcut = ShortcutDefinition(keyCode: 40, modifiers: 1 << 20)
        }

        let reloaded = AppSettings(fileURL: fileURL)
        precondition(!reloaded.reminderEnabled)
        precondition(reloaded.reminderIntervalMinutes == 90)
        precondition(reloaded.reminderPosition == .topRight)
        precondition(reloaded.globalShortcut?.keyCode == 40)

        let original = Data(#"{"schemaVersion":99,"values":{}}"#.utf8)
        let unknownURL = directory.appendingPathComponent("unknown.json")
        try original.write(to: unknownURL)
        let unknown = AppSettings(fileURL: unknownURL)
        precondition(unknown.loadError != nil)
        let unchangedData = try Data(contentsOf: unknownURL)
        precondition(unchangedData == original)

        print("App settings smoke passed.")
    }
}
