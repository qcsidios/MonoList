import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct TaskListView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var draftState: TaskDraftState
    let onClose: () -> Void
    let onOpenSettings: () -> Void
    let onHeightChanged: (CGFloat) -> Void

    @State private var showsOlderCompleted = false
    @State private var errorMessage: String?
    @State private var selectedTaskID: UUID?
    @State private var editingTaskID: UUID?
    @State private var keyboardMonitor: Any?
    @State private var clearAction: ClearAction?
    @State private var currentDate = Date()
    @State private var draftFocused = false
    @StateObject private var dropCoordinator = TaskDropCoordinator()
    @State private var draftScrollRequest = UUID()

    private var todayCompleted: [TaskItem] {
        store.completedTasks(on: currentDate)
    }

    private var olderCompleted: [TaskItem] {
        store.completedTasks(before: currentDate)
    }

    private var visibleOlderCompleted: [TaskItem] {
        showsOlderCompleted ? olderCompleted : []
    }

    private var completedGroups: [CompletedGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleOlderCompleted) {
            calendar.startOfDay(for: $0.completedAt ?? .distantPast)
        }
        return grouped
            .map { CompletedGroup(date: $0.key, tasks: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private var naturalHeight: CGFloat {
        let visibleTasks = store.pendingTasks + todayCompleted + visibleOlderCompleted
        var extraLines = visibleTasks.reduce(0) {
            $0 + Self.additionalLines(for: $1.text)
        }
        extraLines += store.pendingTasks.filter { $0.reminder != nil }.count
        if draftState.isPresented {
            extraLines += Self.additionalLines(for: draftState.text)
        }
        let rows = store.pendingTasks.count +
            todayCompleted.count +
            visibleOlderCompleted.count +
            (draftState.isPresented ? 1 : 0)
        let dateHeaders = showsOlderCompleted ? completedGroups.count : 0
        return Self.contentHeight(
            rowCount: rows,
            additionalLineCount: extraLines,
            dateHeaderCount: dateHeaders
        ) + 58
    }

    private var preferredHeight: CGFloat {
        min(
            max(naturalHeight, WindowCoordinator.mainPanelMinimumHeight),
            WindowCoordinator.mainPanelMaximumHeight
        )
    }

    private var shouldScroll: Bool {
        WindowCoordinator.requiresScrolling(contentHeight: naturalHeight)
    }

    var body: some View {
        Group {
            if let loadError = store.loadError {
                DataRecoveryView(
                    message: loadError.localizedDescription,
                    onRetry: { store.retryLoad() },
                    onQuit: { NSApp.terminate(nil) }
                )
            } else {
                mainList
            }
        }
        .frame(width: WindowCoordinator.mainPanelWidth, height: preferredHeight)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .environment(\.colorScheme, .light)
        .onAppear {
            draftState.syncVisibility(hasPendingTasks: !store.pendingTasks.isEmpty)
            installKeyboardMonitor()
            onHeightChanged(preferredHeight)
        }
        .onDisappear {
            commitDraft()
            removeKeyboardMonitor()
        }
        .onChange(of: preferredHeight) { _, height in
            onHeightChanged(height)
        }
        .onChange(of: store.pendingTasks.count) { _, count in
            if count == 0 && !draftState.isPresented {
                draftState.present(after: nil)
            }
        }
        .onReceive(
            Timer.publish(every: 60, on: .main, in: .common).autoconnect()
        ) { date in
            currentDate = date
        }
        .alert(
            "操作失败",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            clearAction?.title ?? "",
            isPresented: Binding(
                get: { clearAction != nil },
                set: { if !$0 { clearAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(clearAction?.buttonTitle ?? "永久删除", role: .destructive) {
                performClear()
            }
            Button("取消", role: .cancel) {
                clearAction = nil
            }
        } message: {
            Text(clearAction?.message ?? "")
        }
    }

    private var mainList: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)
            if shouldScroll {
                ScrollViewReader { proxy in
                    ScrollView {
                        taskContent
                    }
                    .onChange(of: draftScrollRequest) { _, _ in
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.16)) {
                                proxy.scrollTo("task-draft-row", anchor: .bottom)
                            }
                            DispatchQueue.main.async { draftFocused = true }
                        }
                    }
                }
                .scrollBounceBehavior(.always, axes: .vertical)
            } else {
                taskContent
            }
        }
    }

    private var taskContent: some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    focusDraft(after: store.shortTermTasks.last?.id)
                }
                .onTapGesture {
                    clearFocus()
                }

            VStack(spacing: 2) {
                taskGroupSection(.shortTerm, title: "短期任务")
                taskGroupSection(.longTerm, title: "长期任务")
                completedSection
            }
            .padding(.horizontal, 7)
            .padding(.top, 7)
            .padding(.bottom, 7)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text("今天")
                .font(.system(size: 17, weight: .semibold))
            Text(currentDate, format: .dateTime.month().day().weekday())
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            WindowDragArea()
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        clearFocus()
                    }
                )

            Button {
                commitDraft()
                focusDraft(after: store.shortTermTasks.last?.id)
            } label: {
                HeaderIconLabel(systemName: "plus")
            }
            .buttonStyle(HeaderIconButtonStyle())
            .help("新增待办")

            Menu {
                Button("清空未完成任务") { clearAction = .pending }
                    .disabled(store.pendingTasks.isEmpty)
                Button("清空已完成任务") { clearAction = .completed }
                    .disabled(store.historyTasks.isEmpty)
                Divider()
                Button("清空全部任务", role: .destructive) { clearAction = .all }
                    .disabled(store.tasks.isEmpty)
            } label: {
                HeaderIconLabel(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(HeaderIconButtonStyle())
            .frame(width: 30, height: 30)
            .simultaneousGesture(
                TapGesture().onEnded {
                    commitDraft()
                }
            )
            .help("更多操作")

            Button {
                commitDraft()
                onOpenSettings()
            } label: {
                HeaderIconLabel(systemName: "gearshape")
            }
            .buttonStyle(HeaderIconButtonStyle())
            .help("打开控制台")
        }
        .padding(.leading, 14)
        .padding(.trailing, 9)
        .frame(height: 54)
    }

    private func tasks(in group: TaskGroup) -> [TaskItem] {
        group == .shortTerm ? store.shortTermTasks : store.longTermTasks
    }

    @ViewBuilder
    private func taskGroupSection(_ group: TaskGroup, title: String) -> some View {
        let groupTasks = tasks(in: group)
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(groupTasks.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 29)
        .contentShape(Rectangle())
        .background(
            dropCoordinator.target?.group == group
                ? Color.accentColor.opacity(0.08)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .onDrop(of: [UTType.text], delegate: TaskGroupDropDelegate(
            group: group,
            beforeID: nil,
            store: store,
            coordinator: dropCoordinator,
            errorMessage: $errorMessage
        ))

        ForEach(groupTasks) { item in
            TaskRowView(
                item: item,
                onSave: perform { text in
                    try store.updateText(id: item.id, text: text)
                },
                onComplete: perform { text in
                    try store.complete(id: item.id, finalText: text)
                },
                onDelete: {
                    performAction { try store.delete(id: item.id) }
                    if selectedTaskID == item.id {
                        selectedTaskID = nil
                    }
                },
                onMoveUp: perform { try store.move(id: item.id, by: -1) },
                onMoveDown: perform { try store.move(id: item.id, by: 1) },
                onInsertAfter: {
                    focusDraft(after: item.id, in: item.group)
                },
                onUpdateReminder: perform { reminder in
                    try store.updateReminder(id: item.id, reminder: reminder)
                },
                onChangeGroup: perform {
                    try store.move(
                        id: item.id,
                        to: item.group == .shortTerm ? .longTerm : .shortTerm,
                        before: nil
                    )
                },
                isSelected: selectedTaskID == item.id,
                onSelect: { selectTask(item.id) },
                onEditingChanged: { editing in
                    editingTaskID = editing ? item.id : nil
                }
            )
            .onDrag {
                NSItemProvider(object: item.id.uuidString as NSString)
            } preview: {
                TaskDragPreview()
            }
            .onDrop(
                of: [UTType.text],
                delegate: TaskGroupDropDelegate(
                    group: group,
                    beforeID: item.id,
                    store: store,
                    coordinator: dropCoordinator,
                    errorMessage: $errorMessage
                )
            )

            if draftState.isPresented && draftState.afterID == item.id {
                draftRow
                    .id("task-draft-row")
            }
        }
        if draftState.isPresented && draftState.group == group && draftState.afterID == nil {
            draftRow.id("task-draft-row")
        }
    }

    private var draftRow: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: "circle")
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)
                .frame(width: 28, height: 28)
            TaskTextEditor(
                text: $draftState.text,
                isFocused: $draftFocused,
                onSubmit: continueDraft
            )
                .onAppear {
                    if !store.pendingTasks.isEmpty {
                        DispatchQueue.main.async {
                            draftFocused = true
                        }
                    }
                }
                .onChange(of: draftFocused) { oldValue, newValue in
                    if oldValue && !newValue {
                        commitDraft()
                    }
                }
                .padding(.vertical, 5)
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Color.primary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 9)
        )
    }

    private var completedSection: some View {
        VStack(spacing: 2) {
            HStack {
                Text("已完成")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(showsOlderCompleted ? "隐藏" : "显示") {
                    commitDraft()
                    showsOlderCompleted.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .frame(width: 48, height: 24)
                .background(Color.primary.opacity(0.055), in: Capsule())
            }
            .padding(.horizontal, 10)
            .frame(height: 35)

            ForEach(todayCompleted) { item in
                completedRow(item)
            }

            if showsOlderCompleted {
                ForEach(completedGroups, id: \.date) { group in
                    Text(group.date, format: .dateTime.year().month().day())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .frame(height: 19)
                    ForEach(group.tasks) { item in
                        completedRow(item)
                    }
                }
            }
        }
    }

    private func completedRow(_ item: TaskItem) -> some View {
        CompletedTaskRow(
            item: item,
            onRestore: { performAction { try store.restore(id: item.id) } },
            onDelete: { performAction { try store.delete(id: item.id) } }
        )
    }

    private func clearFocus() {
        commitDraft()
        selectedTaskID = nil
        editingTaskID = nil
        draftFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private func commitDraft() {
        guard draftState.isPresented else { return }
        do {
            try draftState.commitOrDismiss(to: store)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func continueDraft() {
        guard draftState.isPresented else { return }
        do {
            _ = try draftState.submitAndContinue(to: store)
            selectedTaskID = nil
            editingTaskID = nil
            draftScrollRequest = UUID()
            DispatchQueue.main.async {
                draftFocused = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectTask(_ id: UUID) {
        commitDraft()
        selectedTaskID = id
        editingTaskID = nil
        draftFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private func focusDraft(after id: UUID?, in group: TaskGroup = .shortTerm) {
        selectedTaskID = nil
        editingTaskID = nil
        draftState.present(after: id, in: group)
        draftScrollRequest = UUID()
        DispatchQueue.main.async {
            selectedTaskID = nil
            editingTaskID = nil
            draftFocused = true
        }
    }

    static func additionalLines(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let bounds = (text as NSString).boundingRect(
            with: NSSize(
                width: 235,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let lineHeight = font.boundingRectForFont.height
        let lineCount = max(1, Int(round(bounds.height / lineHeight)))
        return max(0, min(lineCount, 6) - 1)
    }

    static func contentHeight(
        rowCount: Int,
        additionalLineCount: Int,
        dateHeaderCount: Int
    ) -> CGFloat {
        104 +
            CGFloat(rowCount * 36) +
            CGFloat(additionalLineCount * 13) +
            CGFloat(dateHeaderCount * 19)
    }

    private func installKeyboardMonitor() {
        guard keyboardMonitor == nil else { return }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard editingTaskID == nil, !draftFocused, let selectedTaskID else {
                return event
            }
            if event.keyCode == 51 || event.keyCode == 117 {
                performAction { try store.delete(id: selectedTaskID) }
                self.selectedTaskID = nil
                return nil
            }
            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }
    }

    private func performClear() {
        guard let clearAction else { return }
        performAction {
            switch clearAction {
            case .pending:
                try store.clearPending()
            case .completed:
                try store.clearHistory()
            case .all:
                try store.clearAll()
            }
        }
        selectedTaskID = nil
        self.clearAction = nil
    }

    private func performAction(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func perform(_ action: @escaping () throws -> Void) -> () -> Void {
        { performAction(action) }
    }

    private func perform<Value>(
        _ action: @escaping (Value) throws -> Void
    ) -> (Value) -> Void {
        { value in performAction { try action(value) } }
    }
}

private struct HeaderIconLabel: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.primary)
            .frame(width: 30, height: 30)
    }
}

private struct TaskDragPreview: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
    }
}

private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DraggingNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class DraggingNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private struct HeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct CompletedGroup {
    let date: Date
    let tasks: [TaskItem]
}

private struct CompletedTaskRow: View {
    let item: TaskItem
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Button(action: onRestore) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            Text(item.text)
                .strikethrough()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .opacity(isHovered ? 1 : 0)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("恢复为未完成", action: onRestore)
            Button("删除", role: .destructive, action: onDelete)
        }
    }
}

private enum ClearAction {
    case pending
    case completed
    case all

    var title: String {
        switch self {
        case .pending: return "清空未完成任务？"
        case .completed: return "清空已完成任务？"
        case .all: return "清空全部任务？"
        }
    }

    var buttonTitle: String {
        switch self {
        case .pending: return "删除所有未完成任务"
        case .completed: return "删除所有已完成任务"
        case .all: return "删除全部任务"
        }
    }

    var message: String {
        "此操作会立即永久删除对应任务，且无法撤销。"
    }
}

private struct TaskGroupDropDelegate: DropDelegate {
    let group: TaskGroup
    let beforeID: UUID?
    let store: TaskStore
    let coordinator: TaskDropCoordinator
    @Binding var errorMessage: String?

    func dropEntered(info: DropInfo) {
        coordinator.hover(group: group, before: beforeID)
    }

    func dropExited(info: DropInfo) {
        coordinator.cancel()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else {
            return false
        }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let value = object as? NSString,
                  let sourceID = UUID(uuidString: value as String) else { return }
            Task { @MainActor in
                do {
                    try withAnimation(
                        .interactiveSpring(response: 0.22, dampingFraction: 0.88)
                    ) {
                        coordinator.hover(group: group, before: beforeID)
                        try coordinator.performDrop(sourceID: sourceID, store: store)
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        return true
    }
}
