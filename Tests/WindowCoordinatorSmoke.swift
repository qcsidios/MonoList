import AppKit
import Foundation
import SwiftUI

@main
struct WindowCoordinatorSmoke {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonoListWindowTests-\(UUID().uuidString)")
        let store = TaskStore(fileURL: directory.appendingPathComponent("tasks.json"))
        let coordinator = WindowCoordinator(taskStore: store)

        precondition(WindowCoordinator.mainPanelWidth == 336)
        precondition(WindowCoordinator.mainPanelMaximumHeight == 447)
        precondition(WindowCoordinator.settingsWindowWidth == 430)
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let fallbackAnchor = WindowCoordinator.fallbackMainPanelAnchor(
            in: visibleFrame,
            menuBarBottomY: 866
        )
        precondition(fallbackAnchor.y == 866)
        precondition(
            fallbackAnchor.x == visibleFrame.maxX -
                WindowCoordinator.mainPanelWidth / 2 - 8
        )
        let statusItemFrame = NSRect(x: 1180, y: 876, width: 72, height: 24)
        let statusItemAnchor = WindowCoordinator.mainPanelAnchor(
            below: statusItemFrame,
            in: visibleFrame
        )
        precondition(statusItemAnchor == NSPoint(x: 1216, y: 900))
        precondition(
            WindowCoordinator.isStatusItemClick(
                NSPoint(x: 1216, y: 888),
                frame: statusItemFrame
            )
        )
        precondition(
            !WindowCoordinator.isStatusItemClick(
                NSPoint(x: 1100, y: 888),
                frame: statusItemFrame
            )
        )
        let originalFrame = NSRect(x: 120, y: 300, width: 336, height: 180)
        let expandedFrame = WindowCoordinator.mainPanelFrame(
            keepingTopOf: originalFrame,
            height: 260
        )
        precondition(expandedFrame.minY == 220)
        precondition(expandedFrame.maxY == originalFrame.maxY)
        precondition(expandedFrame.width == originalFrame.width)
        let collapsedFrame = WindowCoordinator.mainPanelFrame(
            keepingTopOf: expandedFrame,
            height: 120
        )
        precondition(collapsedFrame.maxY == originalFrame.maxY)
        let halfwayFrame = WindowCoordinator.interpolatedMainPanelFrame(
            from: originalFrame,
            to: expandedFrame,
            progress: 0.5
        )
        precondition(halfwayFrame.height == 220)
        precondition(halfwayFrame.maxY == originalFrame.maxY)
        precondition(WindowCoordinator.requiresScrolling(contentHeight: 479))
        precondition(WindowCoordinator.requiresScrolling(contentHeight: 481))
        precondition(
            WindowCoordinator.preferredMainPanelHeight(
                pendingCount: 0,
                todayCompletedCount: 0,
                olderVisibleCount: 0
            ) < 148
        )
        precondition(
            WindowCoordinator.preferredMainPanelHeight(
                pendingCount: 20,
                todayCompletedCount: 10,
                olderVisibleCount: 10
            ) == WindowCoordinator.mainPanelMaximumHeight
        )
        precondition(
            WindowCoordinator.preferredMainPanelHeight(
                pendingCount: 2,
                todayCompletedCount: 7,
                olderVisibleCount: 0
            ) == 430
        )
        precondition(
            TaskListView.additionalLines(
                for: "shotlens升级。线上部署，把key放入安全环境。控制台 UI比例调整。"
            ) == 1
        )
        precondition(
            TaskListView.contentHeight(
                rowCount: 7,
                additionalLineCount: 7,
                dateHeaderCount: 0
            ) == WindowCoordinator.mainPanelMaximumHeight
        )
        precondition(
            TaskListView.contentHeight(
                rowCount: 8,
                additionalLineCount: 8,
                dateHeaderCount: 0
            ) > WindowCoordinator.mainPanelMaximumHeight
        )
        var directSubmitCount = 0
        let directEditor = TaskSubmitTextView()
        directEditor.onSubmit = { directSubmitCount += 1 }
        directEditor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        precondition(directSubmitCount == 1)
        let emptyDraftHeight = try measuredTaskEditorHeight(
            text: "",
            width: 310,
            offeredHeight: 90
        )
        precondition(emptyDraftHeight <= 18)
        let wrappedDraftHeight = try measuredTaskEditorHeight(
            text: "这是一条足够长的待办内容，用来验证输入框只有在文本真的需要换行时才自动变成两行显示。",
            width: 310,
            offeredHeight: 90
        )
        precondition(wrappedDraftHeight > emptyDraftHeight)
        let enterDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonoListEnterTests-\(UUID().uuidString)")
        let enterStore = TaskStore(
            fileURL: enterDirectory.appendingPathComponent("tasks.json")
        )
        let enterDraft = TaskDraftState()
        enterDraft.present(after: nil)
        enterDraft.text = "加号或双击新增的待办"
        directEditor.onSubmit = {
            try! enterDraft.submitAndContinue(to: enterStore)
        }
        directEditor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        precondition(enterStore.pendingTasks.map(\.text) == ["加号或双击新增的待办"])
        precondition(enterDraft.isPresented)
        precondition(enterDraft.text.isEmpty)
        enterDraft.text = "下一行待办"
        directEditor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        precondition(
            enterStore.pendingTasks.map(\.text) ==
                ["加号或双击新增的待办", "下一行待办"]
        )
        precondition(enterDraft.isPresented)

        let draft = TaskDraftState()
        draft.syncVisibility(hasPendingTasks: false)
        precondition(draft.isPresented)
        draft.text = "还没有按回车"
        precondition(draft.text == "还没有按回车")
        precondition(store.pendingTasks.isEmpty)
        try draft.submit(to: store)
        precondition(store.pendingTasks.map(\.text) == ["还没有按回车"])
        precondition(draft.text.isEmpty)
        precondition(!draft.isPresented)
        draft.present(after: store.pendingTasks.last?.id)
        precondition(draft.isPresented)
        draft.dismissIfEmpty()
        precondition(!draft.isPresented)
        draft.present(after: nil)
        draft.text = "保留的草稿"
        try draft.commitOrDismiss(to: store)
        precondition(store.pendingTasks.map(\.text) == ["还没有按回车", "保留的草稿"])
        precondition(!draft.isPresented)
        draft.present(after: store.pendingTasks.last?.id)
        try draft.commitOrDismiss(to: store)
        precondition(store.pendingTasks.count == 2)
        precondition(!draft.isPresented)
        draft.present(after: store.pendingTasks.last?.id)
        draft.text = "连续输入第一条"
        let continuedItem = try draft.submitAndContinue(to: store)
        precondition(continuedItem?.text == "连续输入第一条")
        precondition(draft.isPresented)
        precondition(draft.text.isEmpty)
        precondition(draft.afterID == continuedItem?.id)
        coordinator.showMainPanel(at: NSPoint(x: 500, y: 500))
        precondition(coordinator.isMainPanelVisible)
        coordinator.closeMainPanel()
        precondition(!coordinator.isMainPanelVisible)

        print("Window coordinator smoke passed.")
    }

    @MainActor
    private static func measuredTaskEditorHeight(
        text: String,
        width: CGFloat,
        offeredHeight: CGFloat
    ) throws -> CGFloat {
        let view = NSHostingView(
            rootView: TaskEditorSizingProbe(text: text)
                .frame(width: width, height: offeredHeight)
        )
        view.frame = NSRect(x: 0, y: 0, width: width, height: offeredHeight)
        let window = NSWindow(
            contentRect: view.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        view.layoutSubtreeIfNeeded()
        guard let textView = findTaskTextView(in: view) else {
            throw CocoaError(.coderInvalidValue)
        }
        return textView.frame.height
    }

    private static func findTaskTextView(in view: NSView) -> TaskSubmitTextView? {
        if let textView = view as? TaskSubmitTextView {
            return textView
        }
        for subview in view.subviews {
            if let textView = findTaskTextView(in: subview) {
                return textView
            }
        }
        return nil
    }
}

private struct TaskEditorSizingProbe: View {
    @State private var text: String
    @State private var isFocused = false

    init(text: String) {
        _text = State(initialValue: text)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: "circle")
                .font(.system(size: 18))
                .frame(width: 28, height: 28)
            TaskTextEditor(
                text: $text,
                isFocused: $isFocused,
                onSubmit: {}
            )
            .padding(.vertical, 5)
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}
