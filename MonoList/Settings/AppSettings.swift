import Combine
import Foundation

enum AppSettingsError: LocalizedError {
    case recoveryRequired
    case invalidReminderInterval

    var errorDescription: String? {
        switch self {
        case .recoveryRequired:
            return "设置数据读取失败，请重试"
        case .invalidReminderInterval:
            return "提醒间隔无效"
        }
    }
}

enum ReminderPosition: String, Codable, CaseIterable, Identifiable {
    case topCenter
    case belowMenuBar
    case topRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topCenter:
            return "顶部居中"
        case .belowMenuBar:
            return "菜单栏下方"
        case .topRight:
            return "右上角"
        }
    }
}

struct ShortcutDefinition: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
}

struct SettingsValues: Codable, Equatable {
    var reminderEnabled = true
    var reminderIntervalMinutes = 60
    var reminderPosition = ReminderPosition.topCenter
    var launchAtLogin = false
    var globalShortcut: ShortcutDefinition?
    var lastAutomaticUpdateCheckAt: Date?
}

private struct SettingsDatabase: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var values: SettingsValues

    init(values: SettingsValues) {
        schemaVersion = Self.currentSchemaVersion
        self.values = values
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published private(set) var values = SettingsValues()
    @Published private(set) var loadError: Error?
    @Published private(set) var saveError: Error?

    private let fileURL: URL
    private let writer: any AtomicWriting

    var reminderEnabled: Bool { values.reminderEnabled }
    var reminderIntervalMinutes: Int { values.reminderIntervalMinutes }
    var reminderPosition: ReminderPosition { values.reminderPosition }
    var launchAtLogin: Bool { values.launchAtLogin }
    var globalShortcut: ShortcutDefinition? { values.globalShortcut }
    var lastAutomaticUpdateCheckAt: Date? { values.lastAutomaticUpdateCheckAt }

    init(fileURL: URL, writer: any AtomicWriting = AtomicFileWriter()) {
        self.fileURL = fileURL
        self.writer = writer
        load()
    }

    func update(_ mutation: (inout SettingsValues) -> Void) throws {
        guard loadError == nil else {
            throw AppSettingsError.recoveryRequired
        }
        var candidate = values
        mutation(&candidate)
        guard [30, 60, 90, 120].contains(candidate.reminderIntervalMinutes) else {
            throw AppSettingsError.invalidReminderInterval
        }

        do {
            try persist(candidate)
            values = candidate
            saveError = nil
        } catch {
            saveError = error
            throw error
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let database = try decoder.decode(SettingsDatabase.self, from: data)
            guard database.schemaVersion == SettingsDatabase.currentSchemaVersion else {
                throw CocoaError(.coderInvalidValue)
            }
            values = database.values
        } catch {
            loadError = error
        }
    }

    private func persist(_ values: SettingsValues) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(SettingsDatabase(values: values))
        try writer.write(data, to: fileURL)
    }
}
