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
    @FocusState private var draftFocused: Bool

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
        let extraLines = visibleTasks.reduce(0) {
            $0 + estimatedAdditionalLines(for: $1.text)
        }
        let rows = store.pendingTasks.count +
            todayCompleted.count +
            visibleOlderCompleted.count +
            (draftState.isPresented ? 1 : 0)
        let dateHeaders = showsOlderCompleted ? completedGroups.count : 0
        return 55 +
            14 +
            CGFloat(rows * 42) +
            CGFloat(extraLines * 18) +
            35 +
            CGFloat(dateHeaders * 19)
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
                ScrollView {
                    taskContent
                }
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
                    presentDraft(after: store.pendingTasks.last?.id)
                }
                .onTapGesture {
                    clearFocus()
                }

            VStack(spacing: 2) {
                pendingRows
                if draftState.isPresented && draftState.afterID == nil {
                    draftRow
                }
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

            Spacer()

            Button {
                commitDraft()
                presentDraft(after: store.pendingTasks.last?.id)
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
                Image(systemName: "ellipsis")
                    .frame(width: 30, height: 30)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30, height: 30)
            .background(
                Color.primary.opacity(0.055),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
            )
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

    @ViewBuilder
    private var pendingRows: some View {
        ForEach(store.pendingTasks) { item in
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
                    presentDraft(after: item.id)
                },
                isSelected: selectedTaskID == item.id,
                onSelect: { selectedTaskID = item.id },
                onEditingChanged: { editing in
                    editingTaskID = editing ? item.id : nil
                }
            )
            .onDrag {
                NSItemProvider(object: item.id.uuidString as NSString)
            }
            .onDrop(
                of: [UTType.text],
                delegate: TaskDropDelegate(
                    destinationID: item.id,
                    store: store,
                    errorMessage: $errorMessage
                )
            )

            if draftState.isPresented && draftState.afterID == item.id {
                draftRow
                    .id("task-draft-row")
            }
        }
    }

    private var draftRow: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "circle")
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)
                .frame(width: 28, height: 28)
            TextField("输入待办，按 Enter 保存", text: $draftState.text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($draftFocused)
                .onAppear {
                    if !store.pendingTasks.isEmpty {
                        DispatchQueue.main.async {
                            draftFocused = true
                        }
                    }
                }
                .onSubmit {
                    continueDraft()
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
            DispatchQueue.main.async {
                draftFocused = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentDraft(after id: UUID?) {
        draftState.present(after: id)
        DispatchQueue.main.async {
            draftFocused = true
        }
    }

    private func estimatedAdditionalLines(for text: String) -> Int {
        let explicitLines = text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let estimatedLines = explicitLines.reduce(0) {
            $0 + max(1, Int(ceil(Double($1.count) / 26)))
        }
        return max(0, min(estimatedLines, 6) - 1)
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
    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemName)
            .frame(width: 30, height: 30)
            .background(
                Color.primary.opacity(isHovered ? 0.09 : 0.055),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
            )
            .onHover { isHovered = $0 }
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
        HStack(alignment: .top, spacing: 9) {
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

private struct TaskDropDelegate: DropDelegate {
    let destinationID: UUID
    let store: TaskStore
    @Binding var errorMessage: String?

    func dropEntered(info: DropInfo) {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let value = object as? NSString,
                  let sourceID = UUID(uuidString: value as String) else { return }
            Task { @MainActor in
                var ids = store.pendingTasks.map(\.id)
                guard let source = ids.firstIndex(of: sourceID),
                      let destination = ids.firstIndex(of: destinationID),
                      source != destination else { return }
                ids.move(
                    fromOffsets: IndexSet(integer: source),
                    toOffset: destination > source ? destination + 1 : destination
                )
                do {
                    try store.reorder(ids: ids)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        true
    }
}
