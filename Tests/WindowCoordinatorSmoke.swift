import AppKit
import Foundation

@main
struct WindowCoordinatorSmoke {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonoListWindowTests-\(UUID().uuidString)")
        let store = TaskStore(fileURL: directory.appendingPathComponent("tasks.json"))
        let coordinator = WindowCoordinator(taskStore: store)

        precondition(WindowCoordinator.mainPanelWidth == 336)
        precondition(WindowCoordinator.mainPanelMaximumHeight == 480)
        precondition(WindowCoordinator.settingsWindowWidth == 430)
        let originalFrame = NSRect(x: 120, y: 300, width: 336, height: 180)
        let expandedFrame = WindowCoordinator.mainPanelFrame(
            keepingTopOf: originalFrame,
            height: 260
        )
        precondition(expandedFrame.minY == 220)
        precondition(expandedFrame.maxY == originalFrame.maxY)
        precondition(expandedFrame.width == originalFrame.width)
        let collapsedFrame = WindowCoordinator.mainPanelFrame(
            keepingTopOf: expandedFrame,
            height: 120
        )
        precondition(collapsedFrame.maxY == originalFrame.maxY)
        precondition(!WindowCoordinator.requiresScrolling(contentHeight: 479))
        precondition(WindowCoordinator.requiresScrolling(contentHeight: 481))
        precondition(
            WindowCoordinator.preferredMainPanelHeight(
                pendingCount: 0,
                todayCompletedCount: 0,
                olderVisibleCount: 0
            ) < 148
        )
        precondition(
            WindowCoordinator.preferredMainPanelHeight(
                pendingCount: 20,
                todayCompletedCount: 10,
                olderVisibleCount: 10
            ) == 480
        )

        let draft = TaskDraftState()
        draft.syncVisibility(hasPendingTasks: false)
        precondition(draft.isPresented)
        draft.text = "还没有按回车"
        precondition(draft.text == "还没有按回车")
        precondition(store.pendingTasks.isEmpty)
        try draft.submit(to: store)
        precondition(store.pendingTasks.map(\.text) == ["还没有按回车"])
        precondition(draft.text.isEmpty)
        precondition(!draft.isPresented)
        draft.present(after: store.pendingTasks.last?.id)
        precondition(draft.isPresented)
        draft.dismissIfEmpty()
        precondition(!draft.isPresented)
        draft.present(after: nil)
        draft.text = "保留的草稿"
        try draft.commitOrDismiss(to: store)
        precondition(store.pendingTasks.map(\.text) == ["还没有按回车", "保留的草稿"])
        precondition(!draft.isPresented)
        draft.present(after: store.pendingTasks.last?.id)
        try draft.commitOrDismiss(to: store)
        precondition(store.pendingTasks.count == 2)
        precondition(!draft.isPresented)
        coordinator.showMainPanel(at: NSPoint(x: 500, y: 500))
        precondition(coordinator.isMainPanelVisible)
        coordinator.closeMainPanel()
        precondition(!coordinator.isMainPanelVisible)

        print("Window coordinator smoke passed.")
    }
}
