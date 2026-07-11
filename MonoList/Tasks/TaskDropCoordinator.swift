import Combine
import Foundation

struct TaskDropTarget: Equatable {
    let group: TaskGroup
    let beforeID: UUID?
}

@MainActor
final class TaskDropCoordinator: ObservableObject {
    @Published private(set) var target: TaskDropTarget?

    func hover(group: TaskGroup, before destinationID: UUID?) {
        target = TaskDropTarget(group: group, beforeID: destinationID)
    }

    func cancel() {
        target = nil
    }

    func performDrop(sourceID: UUID, store: TaskStore) throws {
        guard let target else { return }
        try store.move(id: sourceID, to: target.group, before: target.beforeID)
        self.target = nil
    }
}
