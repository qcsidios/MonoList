import Combine
import Foundation

struct DailyFocusSelection: Codable, Equatable {
    var dayKey: String
    var orderedTaskIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
}

private struct FocusDatabase: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var selection: DailyFocusSelection?

    init(selection: DailyFocusSelection?) {
        schemaVersion = Self.currentSchemaVersion
        self.selection = selection
    }
}

enum FocusStoreError: LocalizedError {
    case invalidSelection
    case completedTaskLocked
    case writePaused

    var errorDescription: String? {
        switch self {
        case .invalidSelection:
            return "今日专注需要选择 1–3 条现有待办"
        case .completedTaskLocked:
            return "今天已经完成的专注任务不能移出"
        case .writePaused:
            return "今日专注保存失败，请重试"
        }
    }
}

@MainActor
final class FocusStore: ObservableObject {
    @Published private(set) var selection: DailyFocusSelection?
    @Published private(set) var loadError: Error?
    @Published private(set) var isWritePaused = false

    private let fileURL: URL
    private let writer: any AtomicWriting
    private let calendar: Calendar

    init(
        fileURL: URL,
        writer: any AtomicWriting = AtomicFileWriter(),
        calendar: Calendar = .current
    ) {
        self.fileURL = fileURL
        self.writer = writer
        self.calendar = calendar
        load()
    }

    func isActive(at date: Date = Date()) -> Bool {
        guard let selection else { return false }
        return selection.dayKey == Self.dayKey(for: date, calendar: calendar) &&
            !selection.orderedTaskIDs.isEmpty
    }

    func taskIDs(at date: Date = Date()) -> [UUID] {
        isActive(at: date) ? selection?.orderedTaskIDs ?? [] : []
    }

    func suggestedTaskIDs(at date: Date = Date()) -> [UUID] {
        guard let selection,
              selection.dayKey != Self.dayKey(for: date, calendar: calendar) else {
            return []
        }
        return selection.orderedTaskIDs
    }

    func setSelection(
        _ ids: [UUID],
        existingTaskIDs: Set<UUID>,
        completedTaskIDs: Set<UUID>,
        at date: Date = Date()
    ) throws {
        guard (1...3).contains(ids.count),
              Set(ids).count == ids.count,
              Set(ids).isSubset(of: existingTaskIDs) else {
            throw FocusStoreError.invalidSelection
        }

        if isActive(at: date) {
            let lockedIDs = Set(taskIDs(at: date)).intersection(completedTaskIDs)
            guard lockedIDs.isSubset(of: Set(ids)) else {
                throw FocusStoreError.completedTaskLocked
            }
        }

        let oldSelection = isActive(at: date) ? selection : nil
        let candidate = DailyFocusSelection(
            dayKey: Self.dayKey(for: date, calendar: calendar),
            orderedTaskIDs: ids,
            createdAt: oldSelection?.createdAt ?? date,
            updatedAt: date
        )
        try persist(candidate)
        selection = candidate
        loadError = nil
    }

    func clearSelection() throws {
        guard selection != nil else { return }
        try persist(nil)
        selection = nil
        loadError = nil
    }

    func reconcile(existingTaskIDs: Set<UUID>) {
        guard var selection else { return }
        let validIDs = selection.orderedTaskIDs.filter(existingTaskIDs.contains)
        guard validIDs != selection.orderedTaskIDs else { return }
        selection.orderedTaskIDs = validIDs
        selection.updatedAt = Date()
        let candidate = validIDs.isEmpty ? nil : selection
        do {
            try persist(candidate)
            self.selection = candidate
        } catch {
            isWritePaused = true
        }
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let shifted = calendar.date(byAdding: .hour, value: -4, to: date) ?? date
        let components = calendar.dateComponents([.year, .month, .day], from: shifted)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let database = try decoder.decode(FocusDatabase.self, from: data)
            guard database.schemaVersion == FocusDatabase.currentSchemaVersion else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Unsupported focus schema")
                )
            }
            selection = database.selection
        } catch {
            selection = nil
            loadError = error
        }
    }

    private func persist(_ candidate: DailyFocusSelection?) throws {
        guard !isWritePaused else { throw FocusStoreError.writePaused }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(FocusDatabase(selection: candidate))
            try writer.write(data, to: fileURL)
        } catch {
            isWritePaused = true
            throw error
        }
    }
}
