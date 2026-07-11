import Combine
import Foundation

struct TaskDropTarget: Equatable {
    let group: TaskGroup
    let beforeID: UUID?
}

@MainActor
final class TaskDropCoordinator: ObservableObject {
    @Published private(set) var target: TaskDropTarget?
    @Published private(set) var sourceTask: TaskItem?

    func beginDragging(task: TaskItem) {
        sourceTask = task
        target = nil
    }

    func hover(group: TaskGroup, before destinationID: UUID?) {
        target = TaskDropTarget(group: group, beforeID: destinationID)
    }

    func cancel() {
        target = nil
        sourceTask = nil
    }

    func clearTarget() {
        target = nil
    }

    func previewTasks(_ tasks: [TaskItem], in group: TaskGroup) -> [TaskItem] {
        guard let sourceTask, let target else { return tasks }
        if target.beforeID == sourceTask.id { return tasks }
        var preview = tasks.filter { $0.id != sourceTask.id }
        guard target.group == group else { return preview }
        var moved = sourceTask
        moved.group = group
        let index = target.beforeID.flatMap { destinationID in
            preview.firstIndex(where: { $0.id == destinationID })
        } ?? preview.endIndex
        preview.insert(moved, at: index)
        return preview
    }

    func performDrop(sourceID: UUID, store: TaskStore) throws {
        guard let target else { return }
        try store.move(id: sourceID, to: target.group, before: target.beforeID)
        cancel()
    }
}
