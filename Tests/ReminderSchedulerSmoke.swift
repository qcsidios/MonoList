import AppKit
import Foundation
import SwiftUI

@main
struct ReminderSchedulerSmoke {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        var now: TimeInterval = 100
        let calendar = fixedCalendar()
        var wallClock = fixedDate(hour: 10, minute: 0, calendar: calendar)
        var triggerCount = 0
        let scheduler = ReminderScheduler(
            now: { now },
            wallClock: { wallClock },
            calendar: calendar,
            onDue: { triggerCount += 1 }
        )

        scheduler.configure(
            enabled: true,
            intervalMinutes: 60,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 22 * 60,
            pendingCount: 1
        )
        precondition(scheduler.deadline == 3_700)
        precondition(
            scheduler.nextReminderDate ==
                fixedDate(hour: 11, minute: 0, calendar: calendar)
        )

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

        precondition(
            ReminderScheduler.nextReminderDate(
                after: fixedDate(hour: 8, minute: 0, calendar: calendar),
                intervalMinutes: 30,
                startMinuteOfDay: 9 * 60,
                endMinuteOfDay: 22 * 60,
                calendar: calendar
            ) == fixedDate(hour: 9, minute: 0, calendar: calendar)
        )
        precondition(
            ReminderScheduler.nextReminderDate(
                after: fixedDate(hour: 8, minute: 50, calendar: calendar),
                intervalMinutes: 30,
                startMinuteOfDay: 9 * 60,
                endMinuteOfDay: 22 * 60,
                calendar: calendar
            ) == fixedDate(hour: 9, minute: 20, calendar: calendar)
        )
        precondition(
            ReminderScheduler.nextReminderDate(
                after: fixedDate(hour: 21, minute: 45, calendar: calendar),
                intervalMinutes: 30,
                startMinuteOfDay: 9 * 60,
                endMinuteOfDay: 22 * 60,
                calendar: calendar
            ) == fixedDate(dayOffset: 1, hour: 9, minute: 0, calendar: calendar)
        )
        wallClock = fixedDate(hour: 21, minute: 45, calendar: calendar)
        now = 20_000
        scheduler.configure(
            enabled: true,
            intervalMinutes: 30,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 22 * 60,
            pendingCount: 1
        )
        precondition(
            scheduler.nextReminderDate ==
                fixedDate(dayOffset: 1, hour: 9, minute: 0, calendar: calendar)
        )

        let testTasks = ReminderPanelController.tasksForTest([])
        precondition(testTasks.count == 1)
        precondition(testTasks[0].text == "这是一次轻提醒测试")

        let finalFrame = NSRect(x: 400, y: 500, width: 340, height: 180)
        let startFrame = ReminderPanelController.presentationStartFrame(
            for: finalFrame
        )
        precondition(startFrame.size == finalFrame.size)
        precondition(startFrame.minX == finalFrame.minX)
        precondition(startFrame.minY == finalFrame.minY + 8)
        let reminderModel = ReminderPresentationModel()
        let reminderView = NSHostingView(
            rootView: ReminderView(
                totalCount: 1,
                taskTexts: ["这是一次轻提醒测试"],
                model: reminderModel,
                onOpen: {},
                onClose: {}
            )
        )
        reminderView.frame = NSRect(x: 0, y: 0, width: 340, height: 300)
        reminderView.layoutSubtreeIfNeeded()
        precondition(reminderView.fittingSize.height < 110)

        guard !NSScreen.screens.isEmpty else {
            print("Reminder scheduler smoke passed (界面用例因无可用屏幕而跳过).")
            return
        }

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
        precondition((controller.currentPanelHeight ?? 0) < 110)
        precondition(soundCount == 1)
        controller.close(animated: false)
        precondition(!controller.isTesting)
        precondition(soundCount == 1)
        controller.show(
            tasks: testTasks,
            position: .topCenter,
            menuBarButton: nil,
            testing: true,
            playsSound: false,
            onOpen: {},
            onClose: {}
        )
        precondition(soundCount == 1)
        controller.close(animated: false)

        print("Reminder scheduler smoke passed.")
    }

    private static func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func fixedDate(
        dayOffset: Int = 0,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        let start = calendar.date(
            from: DateComponents(
                year: 2026,
                month: 7,
                day: 7 + dayOffset,
                hour: hour,
                minute: minute
            )
        )!
        return start
    }
}
