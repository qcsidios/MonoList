import AppKit
import Combine
import SwiftUI

@MainActor
final class ReminderPanelController: ObservableObject {
    @Published private(set) var isTesting = false

    private var panel: NSPanel?
    private var countdownTimer: Timer?
    private var remainingTenths = 30
    private var model: ReminderPresentationModel?
    private var onClose: (() -> Void)?
    private var finalFrame: NSRect?
    private var position = ReminderPosition.topCenter
    private var frameAnimation: NSViewAnimation?
    private var isClosing = false
    private let playSound: () -> Void

    var isVisible: Bool {
        panel?.isVisible == true
    }

    init(
        playSound: @escaping () -> Void = {
            NSSound(named: NSSound.Name("Ping"))?.play()
        }
    ) {
        self.playSound = playSound
    }

    static func tasksForTest(_ tasks: [TaskItem], at date: Date = Date()) -> [TaskItem] {
        guard tasks.isEmpty else { return tasks }
        return [
            TaskItem(
                id: UUID(),
                text: "这是一次轻提醒测试",
                status: .pending,
                order: 0,
                createdAt: date,
                updatedAt: date,
                completedAt: nil
            )
        ]
    }

    func show(
        tasks: [TaskItem],
        position: ReminderPosition,
        menuBarButton: NSStatusBarButton?,
        testing: Bool = false,
        onOpen: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        close(animated: false, notifying: false)
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
        let supportedPosition = position.supportedValue
        let compactFrame = Self.compactFrame(
            for: frame,
            position: supportedPosition
        )
        panel.setFrame(compactFrame, display: false)
        panel.orderFrontRegardless()

        self.panel = panel
        self.model = model
        self.onClose = onClose
        self.finalFrame = frame
        self.position = supportedPosition
        isTesting = testing
        isClosing = false
        remainingTenths = 30
        playSound()
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel, self.panel === panel else { return }
            model.isExpanded = true
            self.animate(panel: panel, to: frame, duration: 0.32)
        }
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.countDown()
            }
        }
    }

    func close(animated: Bool = true, notifying: Bool = true) {
        guard let panel else {
            isTesting = false
            if notifying {
                let callback = onClose
                onClose = nil
                callback?()
            } else {
                onClose = nil
            }
            return
        }
        if isClosing && animated {
            return
        }
        isClosing = true
        countdownTimer?.invalidate()
        countdownTimer = nil
        isTesting = false
        frameAnimation?.stop()
        frameAnimation = nil

        guard animated, let finalFrame else {
            finishClosing(panel: panel, notifying: notifying)
            return
        }
        model?.isExpanded = false
        let compactFrame = Self.compactFrame(
            for: finalFrame,
            position: position
        )
        animate(panel: panel, to: compactFrame, duration: 0.24)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            [weak self, weak panel] in
            guard let self, let panel, self.panel === panel else { return }
            self.finishClosing(panel: panel, notifying: notifying)
        }
    }

    static func compactFrame(
        for finalFrame: NSRect,
        position: ReminderPosition
    ) -> NSRect {
        let size = NSSize(width: 36, height: 36)
        let x: CGFloat
        switch position.supportedValue {
        case .topRight:
            x = finalFrame.maxX - size.width
        default:
            x = finalFrame.midX - size.width / 2
        }
        return NSRect(
            x: x,
            y: finalFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
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

    private func animate(
        panel: NSPanel,
        to frame: NSRect,
        duration: TimeInterval
    ) {
        frameAnimation?.stop()
        let animation = NSViewAnimation(
            viewAnimations: [[
                .target: panel,
                .endFrame: NSValue(rect: frame),
            ]]
        )
        animation.duration = duration
        animation.animationCurve = .easeInOut
        animation.animationBlockingMode = .nonblocking
        frameAnimation = animation
        animation.start()
    }

    private func finishClosing(panel: NSPanel, notifying: Bool) {
        frameAnimation?.stop()
        frameAnimation = nil
        panel.orderOut(nil)
        self.panel = nil
        model = nil
        finalFrame = nil
        isClosing = false
        if notifying {
            let callback = onClose
            onClose = nil
            callback?()
        } else {
            onClose = nil
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
        case .center:
            origin = NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2
            )
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
