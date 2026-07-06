import Foundation

@MainActor
final class ReminderScheduler: ObservableObject {
    private(set) var deadline: TimeInterval?
    @Published private(set) var nextReminderDate: Date?

    private let now: () -> TimeInterval
    private let wallClock: () -> Date
    private let calendar: Calendar
    private let onDue: () -> Void
    private var enabled = false
    private var interval: TimeInterval = 60 * 60
    private var startMinuteOfDay = 9 * 60
    private var endMinuteOfDay = 22 * 60
    private var pendingCount = 0
    private var pollingTimer: Timer?

    init(
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        wallClock: @escaping () -> Date = { Date() },
        calendar: Calendar = .current,
        onDue: @escaping () -> Void
    ) {
        self.now = now
        self.wallClock = wallClock
        self.calendar = calendar
        self.onDue = onDue
    }

    func configure(
        enabled: Bool,
        intervalMinutes: Int,
        startMinuteOfDay: Int = 9 * 60,
        endMinuteOfDay: Int = 22 * 60,
        pendingCount: Int
    ) {
        let changed = self.enabled != enabled ||
            self.interval != TimeInterval(intervalMinutes * 60) ||
            self.startMinuteOfDay != startMinuteOfDay ||
            self.endMinuteOfDay != endMinuteOfDay
        self.enabled = enabled
        interval = TimeInterval(intervalMinutes * 60)
        self.startMinuteOfDay = startMinuteOfDay
        self.endMinuteOfDay = endMinuteOfDay
        self.pendingCount = pendingCount

        if !enabled || pendingCount == 0 {
            deadline = nil
            nextReminderDate = nil
        } else if changed || deadline == nil {
            restart()
        }
    }

    func pendingCountChanged(from oldCount: Int, to newCount: Int) {
        pendingCount = newCount
        guard enabled else {
            deadline = nil
            nextReminderDate = nil
            return
        }
        if newCount == 0 {
            deadline = nil
            nextReminderDate = nil
        } else if oldCount == 0 {
            restart()
        }
    }

    func wake(pendingCount: Int) {
        self.pendingCount = pendingCount
        if enabled && pendingCount > 0 {
            restart()
        } else {
            deadline = nil
            nextReminderDate = nil
        }
    }

    func evaluate(interfaceBusy: Bool) {
        guard let deadline, now() >= deadline else {
            return
        }
        guard enabled, pendingCount > 0 else {
            self.deadline = nil
            nextReminderDate = nil
            return
        }
        if interfaceBusy {
            restart()
        } else {
            self.deadline = nil
            nextReminderDate = nil
            onDue()
        }
    }

    func reminderClosed(pendingCount: Int) {
        self.pendingCount = pendingCount
        if enabled && pendingCount > 0 {
            restart()
        } else {
            deadline = nil
            nextReminderDate = nil
        }
    }

    func startPolling(interfaceBusy: @escaping () -> Bool) {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.evaluate(interfaceBusy: interfaceBusy())
            }
        }
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        deadline = nil
        nextReminderDate = nil
    }

    private func restart() {
        let scheduledDate = Self.nextReminderDate(
            after: wallClock(),
            intervalMinutes: Int(interval / 60),
            startMinuteOfDay: startMinuteOfDay,
            endMinuteOfDay: endMinuteOfDay,
            calendar: calendar
        )
        let delay = max(0, scheduledDate.timeIntervalSince(wallClock()))
        deadline = now() + delay
        nextReminderDate = scheduledDate
    }

    static func nextReminderDate(
        after date: Date,
        intervalMinutes: Int,
        startMinuteOfDay: Int,
        endMinuteOfDay: Int,
        calendar: Calendar = .current
    ) -> Date {
        let candidate = date.addingTimeInterval(TimeInterval(intervalMinutes * 60))
        let candidateStart = boundaryDate(
            matching: startMinuteOfDay,
            on: candidate,
            calendar: calendar
        )
        let candidateEnd = boundaryDate(
            matching: endMinuteOfDay,
            on: candidate,
            calendar: calendar
        )
        if candidate >= candidateStart && candidate <= candidateEnd {
            return candidate
        }
        if candidate < candidateStart {
            return candidateStart
        }
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: candidate
        ) ?? candidate
        return boundaryDate(
            matching: startMinuteOfDay,
            on: tomorrow,
            calendar: calendar
        )
    }

    private static func boundaryDate(
        matching minuteOfDay: Int,
        on date: Date,
        calendar: Calendar
    ) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return startOfDay.addingTimeInterval(TimeInterval(minuteOfDay * 60))
    }
}
