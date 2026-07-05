import Foundation

enum TaskStatus: String, Codable {
    case pending
    case history
}

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var status: TaskStatus
    var order: Int
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
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
