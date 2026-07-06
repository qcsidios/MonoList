import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var taskStore: TaskStore?
    private var windowCoordinator: WindowCoordinator?
    private var appSettings: AppSettings?
    private var loginItemController: LoginItemController?
    private var reminderScheduler: ReminderScheduler?
    private var reminderPanelController: ReminderPanelController?
    private var appUpdater: AppUpdater?
    private var updateInstaller: UpdateInstaller?
    private var updateCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MonoList")
        let store = TaskStore(
            fileURL: applicationSupportURL.appendingPathComponent("tasks.json")
        )
        let settings = AppSettings(
            fileURL: applicationSupportURL.appendingPathComponent("settings.json")
        )
        let loginController = LoginItemController()
        if settings.launchAtLogin && loginController.status != .enabled {
            try? loginController.setEnabled(true)
        }
        let reminderPanelController = ReminderPanelController()
        let updater = AppUpdater()
        let updateInstaller = UpdateInstaller()
        let coordinator = WindowCoordinator(taskStore: store)
        coordinator.configureSettings(
            settings: settings,
            loginItemController: loginController,
            updater: updater,
            onInstallUpdate: { [weak self] update in
                Task { @MainActor in
                    do {
                        try await self?.updateInstaller?.install(update)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "升级失败"
                        alert.informativeText = error.localizedDescription
                        alert.addButton(withTitle: "重试")
                        alert.addButton(withTitle: "取消")
                        if alert.runModal() == .alertFirstButtonReturn {
                            try? await self?.updateInstaller?.install(update)
                        }
                    }
                }
            },
            onTestReminder: { [weak self] in
                guard let self else { return }
                if self.reminderPanelController?.isTesting == true {
                    self.reminderPanelController?.close()
                } else {
                    self.showReminder(testing: true)
                }
            }
        )

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "待办"
        item.button?.toolTip = "MonoList 一栏"
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        store.$tasks
            .map { tasks in tasks.filter { $0.status == .pending }.count }
            .removeDuplicates()
            .sink { [weak item] count in
                item?.button?.title = count == 0 ? "待办" : "待办 \(count)"
            }
            .store(in: &cancellables)

        taskStore = store
        appSettings = settings
        loginItemController = loginController
        self.reminderPanelController = reminderPanelController
        appUpdater = updater
        self.updateInstaller = updateInstaller
        windowCoordinator = coordinator
        statusItem = item

        coordinator.onWillShowMainPanel = { [weak reminderPanelController] in
            reminderPanelController?.close()
        }

        let scheduler = ReminderScheduler { [weak self] in
            self?.showReminder()
        }
        reminderScheduler = scheduler
        store.$tasks
            .combineLatest(settings.$values)
            .sink { [weak scheduler, weak reminderPanelController] tasks, values in
                let count = tasks.filter { $0.status == .pending }.count
                scheduler?.configure(
                    enabled: values.reminderEnabled,
                    intervalMinutes: values.reminderIntervalMinutes,
                    pendingCount: count
                )
                if !values.reminderEnabled || count == 0 {
                    reminderPanelController?.close()
                }
            }
            .store(in: &cancellables)
        scheduler.startPolling { [weak self] in
            guard let self else { return true }
            return self.windowCoordinator?.isMainPanelVisible == true ||
                self.windowCoordinator?.isSettingsVisible == true ||
                self.statusItem?.menu != nil
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        Task {
            await updater.check(manual: false, settings: settings)
        }
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) {
            [weak updater, weak settings] _ in
            Task { @MainActor in
                guard let updater, let settings else { return }
                await updater.check(manual: false, settings: settings)
            }
        }
    }

    @objc
    private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            reminderPanelController?.close()
            windowCoordinator?.closeMainPanel()
            let menu = NSMenu()
            menu.addItem(
                withTitle: "打开控制台",
                action: #selector(openSettings),
                keyEquivalent: ","
            )
            menu.addItem(.separator())
            menu.addItem(
                withTitle: "退出应用",
                action: #selector(quitApplication),
                keyEquivalent: "q"
            )
            for item in menu.items {
                item.target = self
            }
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            windowCoordinator?.toggleMainPanel(relativeTo: sender)
        }
    }

    @objc
    private func openSettings() {
        windowCoordinator?.closeMainPanel()
        windowCoordinator?.showSettings()
    }

    @objc
    private func quitApplication() {
        NSApp.terminate(nil)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag, let button = statusItem?.button {
            windowCoordinator?.toggleMainPanel(relativeTo: button)
        }
        return true
    }

    @objc
    private func systemDidWake() {
        reminderScheduler?.wake(
            pendingCount: taskStore?.pendingTasks.count ?? 0
        )
    }

    private func showReminder(testing: Bool = false) {
        guard let pendingTasks = taskStore?.pendingTasks,
              let settings = appSettings else {
            reminderScheduler?.reminderClosed(pendingCount: 0)
            return
        }
        let tasks = testing
            ? ReminderPanelController.tasksForTest(pendingTasks)
            : pendingTasks
        guard !tasks.isEmpty else {
            reminderScheduler?.reminderClosed(pendingCount: 0)
            return
        }
        reminderPanelController?.show(
            tasks: tasks,
            position: settings.reminderPosition.supportedValue,
            menuBarButton: statusItem?.button,
            testing: testing,
            onOpen: { [weak self] in
                guard let button = self?.statusItem?.button else { return }
                self?.windowCoordinator?.toggleMainPanel(relativeTo: button)
            },
            onClose: { [weak self] in
                if !testing {
                    self?.reminderScheduler?.reminderClosed(
                        pendingCount: self?.taskStore?.pendingTasks.count ?? 0
                    )
                }
            }
        )
    }
}
