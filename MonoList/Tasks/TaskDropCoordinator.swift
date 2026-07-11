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

    func dropTarget(
        group: TaskGroup,
        upperBeforeID: UUID?,
        lowerBeforeID: UUID?,
        locationY: CGFloat,
        rowHeight: CGFloat
    ) -> TaskDropTarget {
        TaskDropTarget(
            group: group,
            beforeID: locationY < rowHeight / 2 ? upperBeforeID : lowerBeforeID
        )
    }

    func cancel() {
        target = nil
        sourceTask = nil
    }

    func clearTarget() {
        target = nil
    }

    func performDrop(sourceID: UUID, store: TaskStore) throws {
        guard let target else { return }
        try store.move(id: sourceID, to: target.group, before: target.beforeID)
        cancel()
    }
}
