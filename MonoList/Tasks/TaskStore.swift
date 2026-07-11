import Combine
import Foundation

enum TaskStoreError: LocalizedError {
    case emptyText
    case invalidSchemaVersion
    case missingTask
    case invalidOrder
    case invalidReminder
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
        case .invalidReminder:
            return "提醒时间无效"
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
                if $0.group != $1.group {
                    return $0.group == .shortTerm
                }
                if $0.order != $1.order {
                    return $0.order < $1.order
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    var shortTermTasks: [TaskItem] {
        pendingTasks.filter { $0.group == .shortTerm }
    }

    var longTermTasks: [TaskItem] {
        pendingTasks.filter { $0.group == .longTerm }
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
        group: TaskGroup = .shortTerm,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> TaskItem {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            throw TaskStoreError.emptyText
        }

        var candidate = tasks
        var pending = tasks(in: group)
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
            completedAt: nil,
            group: group
        )
        pending.insert(item, at: insertionIndex)
        normalizeOrders(in: &pending)
        candidate.removeAll { $0.status == .pending && $0.group == group }
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

    func updateReminder(
        id: UUID,
        reminder: TaskReminder?,
        at date: Date = Date()
    ) throws {
        if let reminder {
            try validate(reminder)
        }
        try mutateTask(id: id) { item in
            item.reminder = reminder
            item.updatedAt = date
        }
    }

    func clearTriggeredOneTimeReminder(
        id: UUID,
        at date: Date = Date()
    ) throws {
        try mutateTask(id: id) { item in
            if item.reminder?.kind == .once {
                item.reminder = nil
                item.updatedAt = date
            }
        }
    }

    func markDedicatedReminderTriggered(
        id: UUID,
        at date: Date = Date()
    ) throws {
        try mutateTask(id: id) { item in
            guard var reminder = item.reminder else { return }
            switch reminder.kind {
            case .once:
                item.reminder = nil
            case .daily:
                reminder.lastTriggeredAt = date
                item.reminder = reminder
            }
            item.updatedAt = date
        }
    }

    func refreshDailyReminderTasks(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        try guardAvailable()
        let startOfToday = calendar.startOfDay(for: date)
        var candidate = tasks
        let dailyGroups = Dictionary(
            grouping: candidate.filter {
                $0.reminder?.kind == .daily &&
                    $0.reminder?.recurrenceID != nil
            },
            by: { $0.reminder!.recurrenceID! }
        )
        guard !dailyGroups.isEmpty else { return }

        var pending = pendingTasks
        var didChange = false
        for (_, group) in dailyGroups {
            if group.contains(where: { $0.status == .pending }) {
                continue
            }
            guard let source = group.max(by: { lhs, rhs in
                let lhsDate = lhs.completedAt ?? lhs.updatedAt
                let rhsDate = rhs.completedAt ?? rhs.updatedAt
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }) else {
                continue
            }
            if calendar.startOfDay(for: source.createdAt) >= startOfToday {
                continue
            }
            var reminder = source.reminder
            if reminder?.kind == .daily,
               let lastTriggeredAt = reminder?.lastTriggeredAt,
               calendar.startOfDay(for: lastTriggeredAt) >= startOfToday {
                reminder?.lastTriggeredAt = nil
            }
            let item = TaskItem(
                id: UUID(),
                text: source.text,
                status: .pending,
                order: pending.count,
                createdAt: date,
                updatedAt: date,
                completedAt: nil,
                reminder: reminder,
                group: source.group
            )
            pending.append(item)
            didChange = true
        }
        guard didChange else { return }

        normalizeOrders(in: &pending)
        candidate.removeAll { $0.status == .pending }
        candidate.append(contentsOf: pending)
        try commit(candidate)
    }

    func move(id: UUID, by offset: Int) throws {
        try guardAvailable()
        guard offset != 0 else {
            return
        }

        guard let group = tasks.first(where: { $0.id == id })?.group else {
            throw TaskStoreError.missingTask
        }
        var pending = tasks(in: group)
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

        var candidate = tasks.filter { !($0.status == .pending && $0.group == group) }
        candidate.append(contentsOf: pending)
        try commit(candidate)
    }

    func move(id: UUID, to group: TaskGroup, before destinationID: UUID?) throws {
        try guardAvailable()
        if destinationID == id { return }
        guard let item = tasks.first(where: { $0.id == id && $0.status == .pending }) else {
            throw TaskStoreError.missingTask
        }
        var sourceGroup = tasks(in: item.group).filter { $0.id != id }
        var destinationGroup = item.group == group ? sourceGroup : tasks(in: group)
        var moved = item
        moved.group = group
        let insertionIndex = destinationID.flatMap { destinationID in
            destinationGroup.firstIndex(where: { $0.id == destinationID })
        } ?? destinationGroup.endIndex
        destinationGroup.insert(moved, at: insertionIndex)
        normalizeOrders(in: &destinationGroup)
        if item.group != group {
            normalizeOrders(in: &sourceGroup)
        }
        var candidate = tasks.filter { $0.status != .pending }
        for candidateGroup in TaskGroup.allCases {
            if candidateGroup == group {
                candidate.append(contentsOf: destinationGroup)
            } else if candidateGroup == item.group {
                candidate.append(contentsOf: sourceGroup)
            } else {
                candidate.append(contentsOf: tasks(in: candidateGroup))
            }
        }
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
        guard let item = candidate.first(where: { $0.id == id }) else {
            throw TaskStoreError.missingTask
        }
        if item.reminder?.kind == .daily,
           let recurrenceID = item.reminder?.recurrenceID {
            for index in candidate.indices
            where candidate[index].reminder?.recurrenceID == recurrenceID {
                candidate[index].reminder = nil
            }
        }
        candidate.removeAll { $0.id == id }
        normalizePendingOrders(in: &candidate)
        try commit(candidate)
    }

    func clearPending() throws {
        try guardAvailable()
        var candidate = tasks
        let recurrenceIDs = Set(
            candidate.compactMap { item -> UUID? in
                guard item.status == .pending,
                      item.reminder?.kind == .daily else {
                    return nil
                }
                return item.reminder?.recurrenceID
            }
        )
        if !recurrenceIDs.isEmpty {
            for index in candidate.indices
            where candidate[index].reminder?.recurrenceID.map(recurrenceIDs.contains) == true {
                candidate[index].reminder = nil
            }
        }
        candidate.removeAll { $0.status == .pending }
        normalizePendingOrders(in: &candidate)
        try commit(candidate)
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

    private func validate(_ reminder: TaskReminder) throws {
        switch reminder.kind {
        case .once:
            guard reminder.date != nil else {
                throw TaskStoreError.invalidReminder
            }
        case .daily:
            guard (0..<24 * 60).contains(reminder.minuteOfDay),
                  reminder.recurrenceID != nil else {
                throw TaskStoreError.invalidReminder
            }
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

    private func tasks(in group: TaskGroup) -> [TaskItem] {
        pendingTasks.filter { $0.group == group }
    }
}
