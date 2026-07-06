import Combine
import Foundation

enum TaskStoreError: LocalizedError {
    case emptyText
    case invalidSchemaVersion
    case missingTask
    case invalidOrder
    case recoveryRequired
    case writePaused

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "待办内容不能为空"
        case .invalidSchemaVersion:
            return "任务数据版本无法读取"
        case .missingTask:
            return "找不到这条待办"
        case .invalidOrder:
            return "待办排序数据无效"
        case .recoveryRequired:
            return "任务数据读取失败，请重试"
        case .writePaused:
            return "保存已暂停，请重试"
        }
    }
}

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var loadError: Error?
    @Published private(set) var isWritePaused = false

    private let fileURL: URL
    private let writer: any AtomicWriting

    var pendingTasks: [TaskItem] {
        tasks
            .filter { $0.status == .pending }
            .sorted {
                if $0.order != $1.order {
                    return $0.order < $1.order
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    var historyTasks: [TaskItem] {
        tasks
            .filter { $0.status == .history }
            .sorted {
                let lhsDate = $0.completedAt ?? .distantPast
                let rhsDate = $1.completedAt ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    func completedTasks(
        on date: Date,
        calendar: Calendar = .current
    ) -> [TaskItem] {
        historyTasks.filter {
            calendar.isDate($0.createdAt, inSameDayAs: date)
        }
    }

    func completedTasks(
        before date: Date,
        calendar: Calendar = .current
    ) -> [TaskItem] {
        let startOfDay = calendar.startOfDay(for: date)
        return historyTasks.filter {
            $0.createdAt < startOfDay
        }
    }

    init(fileURL: URL, writer: any AtomicWriting = AtomicFileWriter()) {
        self.fileURL = fileURL
        self.writer = writer
        load()
    }

    @discardableResult
    func add(
        text: String,
        after previousID: UUID? = nil,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> TaskItem {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            throw TaskStoreError.emptyText
        }

        var candidate = tasks
        var pending = pendingTasks
        let insertionIndex: Int
        if let previousID,
           let previousIndex = pending.firstIndex(where: { $0.id == previousID }) {
            insertionIndex = pending.index(after: previousIndex)
        } else {
            insertionIndex = pending.endIndex
        }

        let item = TaskItem(
            id: id,
            text: normalizedText,
            status: .pending,
            order: insertionIndex,
            createdAt: createdAt,
            updatedAt: createdAt,
            completedAt: nil
        )
        pending.insert(item, at: insertionIndex)
        normalizeOrders(in: &pending)
        candidate.removeAll { $0.status == .pending }
        candidate.append(contentsOf: pending)
        try commit(candidate)
        return item
    }

    func complete(id: UUID, at date: Date = Date()) throws {
        try mutateTask(id: id) { item in
            item.status = .history
            item.updatedAt = date
            item.completedAt = date
        }
    }

    func complete(id: UUID, finalText: String, at date: Date = Date()) throws {
        let normalizedText = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        try mutateTask(id: id) { item in
            if !normalizedText.isEmpty {
                item.text = normalizedText
            }
            item.status = .history
            item.updatedAt = date
            item.completedAt = date
        }
    }

    func updateText(id: UUID, text: String, at date: Date = Date()) throws {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            throw TaskStoreError.emptyText
        }
        try mutateTask(id: id) { item in
            item.text = normalizedText
            item.updatedAt = date
        }
    }

    func move(id: UUID, by offset: Int) throws {
        try guardAvailable()
        guard offset != 0 else {
            return
        }

        var pending = pendingTasks
        guard let sourceIndex = pending.firstIndex(where: { $0.id == id }) else {
            throw TaskStoreError.missingTask
        }
        let destinationIndex = min(max(sourceIndex + offset, pending.startIndex),
                                   pending.index(before: pending.endIndex))
        guard sourceIndex != destinationIndex else {
            return
        }

        let item = pending.remove(at: sourceIndex)
        pending.insert(item, at: destinationIndex)
        normalizeOrders(in: &pending)

        var candidate = tasks.filter { $0.status != .pending }
        candidate.append(contentsOf: pending)
        try commit(candidate)
    }

    func reorder(ids: [UUID]) throws {
        try guardAvailable()
        let pending = pendingTasks
        guard ids.count == pending.count,
              Set(ids) == Set(pending.map(\.id)) else {
            throw TaskStoreError.invalidOrder
        }
        let itemsByID = Dictionary(uniqueKeysWithValues: pending.map { ($0.id, $0) })
        var reordered = try ids.map { id -> TaskItem in
            guard let item = itemsByID[id] else {
                throw TaskStoreError.invalidOrder
            }
            return item
        }
        normalizeOrders(in: &reordered)
        var candidate = tasks.filter { $0.status != .pending }
        candidate.append(contentsOf: reordered)
        try commit(candidate)
    }

    func restore(id: UUID, at date: Date = Date()) throws {
        let nextOrder = pendingTasks.count
        try mutateTask(id: id) { item in
            item.status = .pending
            item.order = nextOrder
            item.updatedAt = date
            item.completedAt = nil
        }
    }

    func delete(id: UUID) throws {
        try guardAvailable()
        var candidate = tasks
        guard candidate.contains(where: { $0.id == id }) else {
            throw TaskStoreError.missingTask
        }
        candidate.removeAll { $0.id == id }
        normalizePendingOrders(in: &candidate)
        try commit(candidate)
    }

    func clearPending() throws {
        try clear { $0.status == .pending }
    }

    func clearHistory() throws {
        try clear { $0.status == .history }
    }

    func clearAll() throws {
        try clear { _ in true }
    }

    func retryPersist() throws {
        guard loadError == nil else {
            throw TaskStoreError.recoveryRequired
        }
        do {
            try persist(tasks)
            isWritePaused = false
        } catch {
            isWritePaused = true
            throw error
        }
    }

    func retryLoad() {
        tasks = []
        loadError = nil
        isWritePaused = false
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let database = try decoder.decode(TaskDatabase.self, from: data)
            guard database.schemaVersion == TaskDatabase.currentSchemaVersion else {
                throw TaskStoreError.invalidSchemaVersion
            }
            tasks = database.tasks
            normalizePendingOrders(in: &tasks)
        } catch {
            loadError = error
        }
    }

    private func mutateTask(
        id: UUID,
        mutation: (inout TaskItem) -> Void
    ) throws {
        try guardAvailable()
        var candidate = tasks
        guard let index = candidate.firstIndex(where: { $0.id == id }) else {
            throw TaskStoreError.missingTask
        }
        mutation(&candidate[index])
        normalizePendingOrders(in: &candidate)
        try commit(candidate)
    }

    private func clear(where shouldDelete: (TaskItem) -> Bool) throws {
        try guardAvailable()
        var candidate = tasks
        candidate.removeAll(where: shouldDelete)
        normalizePendingOrders(in: &candidate)
        try commit(candidate)
    }

    private func commit(_ candidate: [TaskItem]) throws {
        try guardAvailable()
        do {
            try persist(candidate)
            tasks = candidate
        } catch {
            isWritePaused = true
            throw error
        }
    }

    private func persist(_ candidate: [TaskItem]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(TaskDatabase(tasks: candidate))
        try writer.write(data, to: fileURL)
    }

    private func guardAvailable() throws {
        if loadError != nil {
            throw TaskStoreError.recoveryRequired
        }
        if isWritePaused {
            throw TaskStoreError.writePaused
        }
    }

    private func normalizePendingOrders(in candidate: inout [TaskItem]) {
        var pending = candidate
            .filter { $0.status == .pending }
            .sorted {
                if $0.order != $1.order {
                    return $0.order < $1.order
                }
                return $0.id.uuidString < $1.id.uuidString
            }
        normalizeOrders(in: &pending)
        let orders = Dictionary(uniqueKeysWithValues: pending.map { ($0.id, $0.order) })
        for index in candidate.indices where candidate[index].status == .pending {
            candidate[index].order = orders[candidate[index].id] ?? candidate[index].order
        }
    }

    private func normalizeOrders(in pending: inout [TaskItem]) {
        for index in pending.indices {
            pending[index].order = index
        }
    }
}
