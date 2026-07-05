import AppKit
import SwiftUI

@MainActor
final class ReminderPanelController {
    private var panel: NSPanel?
    private var countdownTimer: Timer?
    private var remainingTenths = 30
    private var model: ReminderPresentationModel?
    private var onClose: (() -> Void)?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(
        tasks: [TaskItem],
        position: ReminderPosition,
        menuBarButton: NSStatusBarButton?,
        onOpen: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        close(notifying: false)
        guard !tasks.isEmpty else {
            onClose()
            return
        }

        let snapshot = Array(tasks.prefix(3))
        let model = ReminderPresentationModel()
        let panel = PassiveReminderPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: panelHeight(for: snapshot.count)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.transient, .moveToActiveSpace]
        panel.contentView = NSHostingView(
            rootView: ReminderView(
                totalCount: tasks.count,
                taskTexts: snapshot.map(\.text),
                model: model,
                onOpen: { [weak self] in
                    self?.close()
                    onOpen()
                },
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )

        let mousePoint = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mousePoint) })
            ?? NSScreen.main
        guard let screen else {
            onClose()
            return
        }
        let frame = frame(
            size: panel.frame.size,
            position: position,
            visibleFrame: screen.visibleFrame,
            menuBarButton: menuBarButton
        )
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()

        self.panel = panel
        self.model = model
        self.onClose = onClose
        remainingTenths = 30
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.countDown()
            }
        }
    }

    func close(notifying: Bool = true) {
        countdownTimer?.invalidate()
        countdownTimer = nil
        panel?.orderOut(nil)
        panel = nil
        model = nil
        if notifying {
            let callback = onClose
            onClose = nil
            callback?()
        } else {
            onClose = nil
        }
    }

    private func countDown() {
        guard model?.isPaused == false else {
            return
        }
        remainingTenths -= 1
        model?.remainingSeconds = max(0, Int(ceil(Double(remainingTenths) / 10)))
        if remainingTenths <= 0 {
            close()
        }
    }

    private func panelHeight(for taskCount: Int) -> CGFloat {
        CGFloat(92 + taskCount * 46)
    }

    private func frame(
        size: NSSize,
        position: ReminderPosition,
        visibleFrame: NSRect,
        menuBarButton: NSStatusBarButton?
    ) -> NSRect {
        let margin: CGFloat = 12
        let origin: NSPoint
        switch position {
        case .topCenter:
            origin = NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.maxY - size.height - margin
            )
        case .topRight:
            origin = NSPoint(
                x: visibleFrame.maxX - size.width - margin,
                y: visibleFrame.maxY - size.height - margin
            )
        case .belowMenuBar:
            if let button = menuBarButton, let window = button.window {
                let buttonFrame = window.convertToScreen(button.frame)
                origin = NSPoint(
                    x: min(
                        max(buttonFrame.midX - size.width / 2, visibleFrame.minX + margin),
                        visibleFrame.maxX - size.width - margin
                    ),
                    y: visibleFrame.maxY - size.height - margin
                )
            } else {
                origin = NSPoint(
                    x: visibleFrame.midX - size.width / 2,
                    y: visibleFrame.maxY - size.height - margin
                )
            }
        }
        return NSRect(origin: origin, size: size)
    }
}

private final class PassiveReminderPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
