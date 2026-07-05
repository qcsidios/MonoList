import Foundation

@MainActor
final class ReminderScheduler {
    private(set) var deadline: TimeInterval?

    private let now: () -> TimeInterval
    private let onDue: () -> Void
    private var enabled = false
    private var interval: TimeInterval = 60 * 60
    private var pendingCount = 0
    private var pollingTimer: Timer?

    init(
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        onDue: @escaping () -> Void
    ) {
        self.now = now
        self.onDue = onDue
    }

    func configure(enabled: Bool, intervalMinutes: Int, pendingCount: Int) {
        let changed = self.enabled != enabled ||
            self.interval != TimeInterval(intervalMinutes * 60)
        self.enabled = enabled
        interval = TimeInterval(intervalMinutes * 60)
        self.pendingCount = pendingCount

        if !enabled || pendingCount == 0 {
            deadline = nil
        } else if changed || deadline == nil {
            restart()
        }
    }

    func pendingCountChanged(from oldCount: Int, to newCount: Int) {
        pendingCount = newCount
        guard enabled else {
            deadline = nil
            return
        }
        if newCount == 0 {
            deadline = nil
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
        }
    }

    func evaluate(interfaceBusy: Bool) {
        guard let deadline, now() >= deadline else {
            return
        }
        guard enabled, pendingCount > 0 else {
            self.deadline = nil
            return
        }
        if interfaceBusy {
            restart()
        } else {
            self.deadline = nil
            onDue()
        }
    }

    func reminderClosed(pendingCount: Int) {
        self.pendingCount = pendingCount
        if enabled && pendingCount > 0 {
            restart()
        } else {
            deadline = nil
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
    }

    private func restart() {
        deadline = now() + interval
    }
}
