import AppKit
import Foundation

@main
struct ReminderSchedulerSmoke {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        var now: TimeInterval = 100
        var triggerCount = 0
        let scheduler = ReminderScheduler(
            now: { now },
            onDue: { triggerCount += 1 }
        )

        scheduler.configure(enabled: true, intervalMinutes: 60, pendingCount: 1)
        precondition(scheduler.deadline == 3_700)

        scheduler.pendingCountChanged(from: 1, to: 2)
        precondition(scheduler.deadline == 3_700)

        now = 3_700
        scheduler.evaluate(interfaceBusy: true)
        precondition(triggerCount == 0)
        precondition(scheduler.deadline == 7_300)

        now = 7_300
        scheduler.evaluate(interfaceBusy: false)
        precondition(triggerCount == 1)
        precondition(scheduler.deadline == nil)

        scheduler.reminderClosed(pendingCount: 2)
        precondition(scheduler.deadline == 10_900)

        scheduler.pendingCountChanged(from: 2, to: 0)
        precondition(scheduler.deadline == nil)

        now = 8_000
        scheduler.pendingCountChanged(from: 0, to: 1)
        precondition(scheduler.deadline == 11_600)
        scheduler.wake(pendingCount: 1)
        precondition(scheduler.deadline == 11_600)

        let testTasks = ReminderPanelController.tasksForTest([])
        precondition(testTasks.count == 1)
        precondition(testTasks[0].text == "这是一次轻提醒测试")

        let finalFrame = NSRect(x: 400, y: 500, width: 340, height: 180)
        let centeredCompactFrame = ReminderPanelController.compactFrame(
            for: finalFrame,
            position: .topCenter
        )
        precondition(centeredCompactFrame.width == 36)
        precondition(centeredCompactFrame.height == 36)
        precondition(centeredCompactFrame.midX == finalFrame.midX)
        precondition(centeredCompactFrame.maxY == finalFrame.maxY)
        let rightCompactFrame = ReminderPanelController.compactFrame(
            for: finalFrame,
            position: .topRight
        )
        precondition(rightCompactFrame.maxX == finalFrame.maxX)
        precondition(rightCompactFrame.maxY == finalFrame.maxY)

        var soundCount = 0
        let controller = ReminderPanelController(playSound: { soundCount += 1 })
        controller.show(
            tasks: testTasks,
            position: .topCenter,
            menuBarButton: nil,
            testing: true,
            onOpen: {},
            onClose: {}
        )
        precondition(controller.isTesting)
        precondition(soundCount == 1)
        controller.close(animated: false)
        precondition(!controller.isTesting)
        precondition(soundCount == 1)

        print("Reminder scheduler smoke passed.")
    }
}
