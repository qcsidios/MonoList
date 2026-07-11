import Foundation

@main
struct TaskDropCoordinatorSmoke {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonoListDropTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = TaskStore(fileURL: directory.appendingPathComponent("tasks.json"))
        let short = try store.add(text: "短期")
        let long = try store.add(text: "长期", group: .longTerm)
        let coordinator = TaskDropCoordinator()

        coordinator.beginDragging(task: short)
        coordinator.hover(group: .longTerm, before: long.id)
        precondition(coordinator.previewTasks(store.shortTermTasks, in: .shortTerm).isEmpty)
        precondition(
            coordinator.previewTasks(store.longTermTasks, in: .longTerm).map(\.id) ==
                [short.id, long.id]
        )
        precondition(store.shortTermTasks.map(\.id) == [short.id])
        precondition(store.longTermTasks.map(\.id) == [long.id])
        coordinator.cancel()
        precondition(store.shortTermTasks.map(\.id) == [short.id])
        precondition(store.longTermTasks.map(\.id) == [long.id])

        coordinator.beginDragging(task: short)
        coordinator.hover(group: .longTerm, before: long.id)
        try coordinator.performDrop(sourceID: short.id, store: store)
        precondition(store.longTermTasks.map(\.id) == [short.id, long.id])

        coordinator.hover(group: .shortTerm, before: nil)
        try coordinator.performDrop(sourceID: long.id, store: store)
        precondition(store.shortTermTasks.map(\.id) == [long.id])
        print("Task drop coordinator smoke passed.")
    }
}
