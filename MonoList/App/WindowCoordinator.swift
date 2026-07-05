import AppKit
import SwiftUI

@MainActor
final class WindowCoordinator {
    static let mainPanelWidth: CGFloat = 360
    static let mainPanelMaximumHeight: CGFloat = 520

    var onOpenSettings: (() -> Void)?
    var onWillShowMainPanel: (() -> Void)?

    private let taskStore: TaskStore
    private var mainPanel: MainPanel?
    private var outsideClickMonitor: Any?
    private weak var previousApplication: NSRunningApplication?
    private var settingsWindow: NSWindow?
    private var settings: AppSettings?
    private var loginItemController: LoginItemController?
    private var shortcutController: GlobalShortcutController?
    private var updater: AppUpdater?
    private var onInstallUpdate: ((AppUpdate) -> Void)?

    var isMainPanelVisible: Bool {
        mainPanel?.isVisible == true
    }

    var isSettingsVisible: Bool {
        settingsWindow?.isVisible == true
    }

    init(taskStore: TaskStore) {
        self.taskStore = taskStore
    }

    func configureSettings(
        settings: AppSettings,
        loginItemController: LoginItemController,
        shortcutController: GlobalShortcutController,
        updater: AppUpdater,
        onInstallUpdate: @escaping (AppUpdate) -> Void
    ) {
        self.settings = settings
        self.loginItemController = loginItemController
        self.shortcutController = shortcutController
        self.updater = updater
        self.onInstallUpdate = onInstallUpdate
        onOpenSettings = { [weak self] in
            self?.showSettings()
        }
    }

    func toggleMainPanel(relativeTo button: NSStatusBarButton) {
        if isMainPanelVisible {
            closeMainPanel(restoringFocus: true)
            return
        }

        guard let buttonWindow = button.window else {
            showMainPanel(at: NSEvent.mouseLocation)
            return
        }
        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        showMainPanel(at: NSPoint(x: buttonFrame.midX, y: buttonFrame.minY))
    }

    func showMainPanel(at anchor: NSPoint) {
        closeMainPanel()
        onWillShowMainPanel?()
        rememberFrontmostApplication()

        let panel = makeMainPanel()
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero
        let originX = min(
            max(anchor.x - Self.mainPanelWidth / 2, visibleFrame.minX + 8),
            visibleFrame.maxX - Self.mainPanelWidth - 8
        )
        let originY = max(
            visibleFrame.minY + 8,
            anchor.y - Self.mainPanelMaximumHeight - 6
        )
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        mainPanel = panel
    }

    func closeMainPanel(restoringFocus: Bool = false) {
        removeOutsideClickMonitor()
        mainPanel?.orderOut(nil)
        mainPanel = nil

        if restoringFocus,
           let previousApplication,
           !previousApplication.isTerminated {
            previousApplication.activate(options: [])
        }
    }

    func showSettings() {
        closeMainPanel()
        guard let settings,
              let loginItemController,
              let shortcutController,
              let updater else {
            return
        }

        if let settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MonoList 一栏 · 设置"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsView(
                settings: settings,
                loginItemController: loginItemController,
                shortcutController: shortcutController,
                taskStore: taskStore,
                updater: updater,
                onInstallUpdate: onInstallUpdate ?? { _ in }
            )
        )
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeMainPanel() -> MainPanel {
        let panel = MainPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.mainPanelWidth,
                height: Self.mainPanelMaximumHeight
            ),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.canBecomeKeyOverride = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.collectionBehavior = [.transient, .moveToActiveSpace]
        panel.onCancel = { [weak self] in
            self?.closeMainPanel(restoringFocus: true)
        }
        panel.contentView = NSHostingView(
            rootView: TaskListView(
                store: taskStore,
                onClose: { [weak self] in
                    self?.closeMainPanel(restoringFocus: true)
                },
                onOpenSettings: { [weak self] in
                    self?.closeMainPanel()
                    self?.onOpenSettings?()
                }
            )
        )
        return panel
    }

    private func rememberFrontmostApplication() {
        let current = NSWorkspace.shared.frontmostApplication
        if current?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApplication = current
        }
    }

    private func installOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closeMainPanel()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }
}

private final class MainPanel: NSPanel {
    var canBecomeKeyOverride = false
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool {
        canBecomeKeyOverride
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
