import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var taskStore: TaskStore?
    private var windowCoordinator: WindowCoordinator?
    private var appSettings: AppSettings?
    private var loginItemController: LoginItemController?
    private var reminderScheduler: ReminderScheduler?
    private var reminderPanelController: ReminderPanelController?
    private var appUpdater: AppUpdater?
    private var updateInstaller: UpdateInstaller?
    private var updateCheckTimer: Timer?
    private var dailyReminderRefreshTimer: Timer?
    private var menuBarHelperProcess: Process?
    private var menuBarObservers: [NSObjectProtocol] = []
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
        try? store.refreshDailyReminderTasks()
        let reminderPanelController = ReminderPanelController()
        let scheduler = ReminderScheduler(
            onDue: { [weak self] in
                self?.showReminder()
            },
            onDedicatedReminderDue: { [weak self] id in
                self?.showDedicatedReminder(taskID: id)
            }
        )
        let updater = AppUpdater()
        let updateInstaller = UpdateInstaller()
        let coordinator = WindowCoordinator(taskStore: store)
        coordinator.configureSettings(
            settings: settings,
            reminderScheduler: scheduler,
            loginItemController: loginController,
            updater: updater,
            onInstallUpdate: { [weak self] update in
                Task { @MainActor in
                    self?.appUpdater?.beginInstallation()
                    do {
                        try await self?.updateInstaller?.install(update)
                    } catch {
                        self?.appUpdater?.installationFailed()
                        let alert = NSAlert()
                        alert.messageText = "升级失败"
                        alert.informativeText = error.localizedDescription
                        alert.addButton(withTitle: "重试")
                        alert.addButton(withTitle: "取消")
                        if alert.runModal() == .alertFirstButtonReturn {
                            self?.appUpdater?.beginInstallation()
                            do {
                                try await self?.updateInstaller?.install(update)
                            } catch {
                                self?.appUpdater?.installationFailed()
                            }
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

        taskStore = store
        appSettings = settings
        loginItemController = loginController
        self.reminderPanelController = reminderPanelController
        appUpdater = updater
        self.updateInstaller = updateInstaller
        windowCoordinator = coordinator
        installMenuBarObservers()
        launchMenuBarHelper(pendingCount: store.shortTermTasks.count)
        store.$tasks
            .map { tasks in
                tasks.filter { $0.status == .pending && $0.group == .shortTerm }.count
            }
            .removeDuplicates()
            .sink { count in
                DistributedNotificationCenter.default().postNotificationName(
                    MenuBarBridgeProtocol.pendingCountChanged,
                    object: nil,
                    userInfo: ["count": count],
                    deliverImmediately: true
                )
            }
            .store(in: &cancellables)

        coordinator.onWillShowMainPanel = { [weak reminderPanelController] in
            reminderPanelController?.close()
        }

        reminderScheduler = scheduler
        store.$tasks
            .combineLatest(settings.$values)
            .sink { [weak scheduler, weak reminderPanelController] tasks, values in
                let pendingTasks = tasks.filter { $0.status == .pending }
                scheduler?.configure(
                    enabled: values.reminderEnabled,
                    intervalMinutes: values.reminderIntervalMinutes,
                    startMinuteOfDay: values.reminderStartMinuteOfDay,
                    endMinuteOfDay: values.reminderEndMinuteOfDay,
                    pendingTasks: pendingTasks
                )
                if !values.reminderEnabled || pendingTasks.isEmpty {
                    reminderPanelController?.close()
                }
            }
            .store(in: &cancellables)
        scheduler.startPolling { [weak self] in
            guard let self else { return true }
            return self.windowCoordinator?.isMainPanelVisible == true
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
        dailyReminderRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) {
            [weak store] _ in
            Task { @MainActor in
                try? store?.refreshDailyReminderTasks()
            }
        }
    }

    private func openSettings() {
        windowCoordinator?.closeMainPanel()
        windowCoordinator?.showSettings()
    }

    private func quitApplication() {
        NSApp.terminate(nil)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        windowCoordinator?.toggleMainPanelFromDock()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateCheckTimer?.invalidate()
        dailyReminderRefreshTimer?.invalidate()
        menuBarHelperProcess?.terminate()
        for observer in menuBarObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    @objc
    private func systemDidWake() {
        try? taskStore?.refreshDailyReminderTasks()
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
            menuBarButton: nil,
            testing: testing,
            playsSound: settings.reminderSoundEnabled,
            soundName: settings.reminderSoundName,
            onOpen: { [weak self] in
                self?.showOrFocusMainPanelAtFallback()
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

    private func showDedicatedReminder(taskID: UUID) {
        guard let store = taskStore,
              let settings = appSettings,
              let task = store.pendingTasks.first(where: { $0.id == taskID }) else {
            return
        }
        try? store.markDedicatedReminderTriggered(id: taskID)
        reminderPanelController?.show(
            tasks: [task],
            position: settings.reminderPosition.supportedValue,
            menuBarButton: nil,
            playsSound: settings.reminderSoundEnabled,
            soundName: settings.reminderSoundName,
            onOpen: { [weak self] in
                self?.showOrFocusMainPanelAtFallback()
            },
            onClose: {}
        )
    }

    private func installMenuBarObservers() {
        let center = DistributedNotificationCenter.default()
        menuBarObservers = [
            center.addObserver(
                forName: MenuBarBridgeProtocol.showMainPanel,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let x = notification.userInfo?["x"] as? CGFloat,
                      let y = notification.userInfo?["y"] as? CGFloat else {
                    return
                }
                Task { @MainActor in
                    self?.windowCoordinator?.toggleMainPanel(
                        at: NSPoint(x: x, y: y)
                    )
                }
            },
            center.addObserver(
                forName: MenuBarBridgeProtocol.openSettings,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.openSettings() }
            },
            center.addObserver(
                forName: MenuBarBridgeProtocol.statusItemFrameChanged,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let values = notification.userInfo
                guard let xNumber = values?["x"] as? NSNumber,
                      let yNumber = values?["y"] as? NSNumber,
                      let widthNumber = values?["width"] as? NSNumber,
                      let heightNumber = values?["height"] as? NSNumber,
                      let anchorXNumber = values?["anchorX"] as? NSNumber,
                      let anchorYNumber = values?["anchorY"] as? NSNumber else {
                    return
                }
                let x = CGFloat(truncating: xNumber)
                let y = CGFloat(truncating: yNumber)
                let width = CGFloat(truncating: widthNumber)
                let height = CGFloat(truncating: heightNumber)
                let anchorX = CGFloat(truncating: anchorXNumber)
                let anchorY = CGFloat(truncating: anchorYNumber)
                Task { @MainActor in
                    self?.windowCoordinator?.updateMenuBarLocation(
                        anchor: NSPoint(x: anchorX, y: anchorY),
                        buttonFrame: NSRect(
                            x: x,
                            y: y,
                            width: width,
                            height: height
                        )
                    )
                }
            },
            center.addObserver(
                forName: MenuBarBridgeProtocol.quit,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.quitApplication() }
            },
        ]
    }

    private func launchMenuBarHelper(pendingCount: Int) {
        let executableURL = Bundle.main.bundleURL
            .appendingPathComponent(
                "Contents/Library/Helpers/MonoListMenuBar.app/Contents/MacOS/MonoListMenuBar"
            )
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            return
        }
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            String(ProcessInfo.processInfo.processIdentifier),
            String(pendingCount),
        ]
        try? process.run()
        menuBarHelperProcess = process
    }

    private func showOrFocusMainPanelAtFallback() {
        windowCoordinator?.showOrFocusMainPanelFromMenuBar()
    }
}
