import Combine
import Foundation

struct TaskDropTarget: Equatable {
    let group: TaskGroup
    let beforeID: UUID?
    let highlightsGroupHeader: Bool

    init(
        group: TaskGroup,
        beforeID: UUID?,
        highlightsGroupHeader: Bool = false
    ) {
        self.group = group
        self.beforeID = beforeID
        self.highlightsGroupHeader = highlightsGroupHeader
    }
}

@MainActor
final class TaskDropCoordinator: ObservableObject {
    @Published private(set) var target: TaskDropTarget?
    @Published private(set) var sourceTask: TaskItem?

    func beginDragging(task: TaskItem) {
        sourceTask = task
        target = nil
    }

    func hover(
        group: TaskGroup,
        before destinationID: UUID?,
        highlightsGroupHeader: Bool = false
    ) {
        target = TaskDropTarget(
            group: group,
            beforeID: destinationID,
            highlightsGroupHeader: highlightsGroupHeader
        )
    }

    func dropTarget(
        group: TaskGroup,
        upperBeforeID: UUID?,
        lowerBeforeID: UUID?,
        locationY: CGFloat,
        rowHeight: CGFloat,
        highlightsGroupHeader: Bool = false
    ) -> TaskDropTarget {
        TaskDropTarget(
            group: group,
            beforeID: locationY < rowHeight / 2 ? upperBeforeID : lowerBeforeID,
            highlightsGroupHeader: highlightsGroupHeader
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
