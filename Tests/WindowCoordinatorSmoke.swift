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

        precondition(WindowCoordinator.mainPanelWidth == 360)
        precondition(WindowCoordinator.mainPanelMaximumHeight == 520)
        coordinator.showMainPanel(at: NSPoint(x: 500, y: 500))
        precondition(coordinator.isMainPanelVisible)
        coordinator.closeMainPanel()
        precondition(!coordinator.isMainPanelVisible)

        print("Window coordinator smoke passed.")
    }
}
