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
        precondition(settings.reminderIntervalMinutes == 30)
        precondition(settings.reminderPosition == .topCenter)
        precondition(settings.reminderSoundEnabled)
        precondition(!settings.launchAtLogin)
        precondition(settings.globalShortcut == nil)
        precondition(ReminderPosition.supportedCases == [.topCenter, .topRight])
        precondition(ReminderPosition.center.supportedValue == .topCenter)
        precondition(ReminderPosition.belowMenuBar.supportedValue == .topCenter)

        try settings.update {
            $0.reminderEnabled = false
            $0.reminderIntervalMinutes = 90
            $0.reminderPosition = .topRight
            $0.reminderSoundEnabled = false
            $0.globalShortcut = ShortcutDefinition(keyCode: 40, modifiers: 1 << 20)
        }

        let reloaded = AppSettings(fileURL: fileURL)
        precondition(!reloaded.reminderEnabled)
        precondition(reloaded.reminderIntervalMinutes == 90)
        precondition(reloaded.reminderPosition == .topRight)
        precondition(!reloaded.reminderSoundEnabled)
        precondition(reloaded.globalShortcut?.keyCode == 40)

        let legacyURL = directory.appendingPathComponent("legacy.json")
        let legacyData = Data(
            """
            {
              "schemaVersion": 1,
              "values": {
                "reminderEnabled": true,
                "reminderIntervalMinutes": 60,
                "reminderPosition": "center",
                "launchAtLogin": true,
                "globalShortcut": null,
                "lastAutomaticUpdateCheckAt": null
              }
            }
            """.utf8
        )
        try legacyData.write(to: legacyURL)
        let legacy = AppSettings(fileURL: legacyURL)
        precondition(legacy.loadError == nil)
        precondition(legacy.reminderPosition == .topCenter)
        precondition(legacy.reminderSoundEnabled)
        precondition(legacy.launchAtLogin)

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
