import Foundation

enum TaskStatus: String, Codable {
    case pending
    case history
}

enum TaskReminderKind: String, Codable {
    case once
    case daily
}

struct TaskReminder: Codable, Equatable {
    var kind: TaskReminderKind
    var date: Date?
    var minuteOfDay: Int
    var recurrenceID: UUID?
    var lastTriggeredAt: Date?

    static func once(at date: Date) -> TaskReminder {
        TaskReminder(
            kind: .once,
            date: date,
            minuteOfDay: 0,
            recurrenceID: nil,
            lastTriggeredAt: nil
        )
    }

    static func daily(
        minuteOfDay: Int,
        id: UUID = UUID(),
        lastTriggeredAt: Date? = nil
    ) -> TaskReminder {
        TaskReminder(
            kind: .daily,
            date: nil,
            minuteOfDay: minuteOfDay,
            recurrenceID: id,
            lastTriggeredAt: lastTriggeredAt
        )
    }
}

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var status: TaskStatus
    var order: Int
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var reminder: TaskReminder? = nil
}

struct TaskDatabase: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var tasks: [TaskItem]

    init(tasks: [TaskItem]) {
        schemaVersion = Self.currentSchemaVersion
        self.tasks = tasks
    }
}
