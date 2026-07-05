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

    private var preferredHeight: CGFloat {
        let baseHeight = WindowCoordinator.preferredMainPanelHeight(
            pendingCount: store.pendingTasks.count,
            todayCompletedCount: todayCompleted.count,
            olderVisibleCount: visibleOlderCompleted.count
        )
        let visibleTasks = store.pendingTasks + todayCompleted + visibleOlderCompleted
        let additionalLines = visibleTasks.reduce(0) {
            $0 + estimatedAdditionalLines(for: $1.text)
        }
        return min(
            baseHeight + CGFloat(additionalLines) * 18,
            WindowCoordinator.mainPanelMaximumHeight
        )
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.24), value: preferredHeight)
        .onAppear {
            installKeyboardMonitor()
            onHeightChanged(preferredHeight)
        }
        .onDisappear(perform: removeKeyboardMonitor)
        .onChange(of: preferredHeight) { _, height in
            onHeightChanged(height)
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
            Divider().opacity(0.55)
            ScrollView {
                LazyVStack(spacing: 3) {
                    pendingRows
                    if draftState.afterID == nil {
                        draftRow
                    }
                    completedSection
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: 18)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            draftState.move(after: store.pendingTasks.last?.id)
                            draftFocused = true
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .top)
                .contentShape(Rectangle())
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("今天")
                    .font(.system(size: 17, weight: .semibold))
                Text(Date(), format: .dateTime.month().day().weekday())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("更多操作")

            Button(action: onOpenSettings) {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("打开控制台")
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 9)
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
                onDelete: perform { try store.delete(id: item.id) },
                onMoveUp: perform { try store.move(id: item.id, by: -1) },
                onMoveDown: perform { try store.move(id: item.id, by: 1) },
                onInsertAfter: {
                    draftState.move(after: item.id)
                    draftFocused = true
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

            if draftState.afterID == item.id {
                draftRow
            }
        }
    }

    private var draftRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle")
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)
                .frame(width: 28, height: 28)
            TextField("输入待办，按 Enter 保存", text: $draftState.text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($draftFocused)
                .onSubmit {
                    do {
                        _ = try draftState.submit(to: store)
                        draftFocused = true
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .padding(.vertical, 5)
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    private var completedSection: some View {
        if !store.historyTasks.isEmpty {
            HStack {
                Text("已完成")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !olderCompleted.isEmpty {
                    Button(showsOlderCompleted ? "隐藏" : "显示") {
                        showsOlderCompleted.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
            }
            .padding(.horizontal, 11)
            .padding(.top, 8)
            .padding(.bottom, 2)

            ForEach(todayCompleted) { item in
                completedRow(item, showsDate: false)
            }

            if showsOlderCompleted {
                ForEach(completedGroups, id: \.date) { group in
                    Text(group.date, format: .dateTime.year().month().day())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 11)
                        .padding(.top, 5)
                    ForEach(group.tasks) { item in
                        completedRow(item, showsDate: false)
                    }
                }
            }
        }
    }

    private func completedRow(_ item: TaskItem, showsDate: Bool) -> some View {
        CompletedTaskRow(
            item: item,
            showsDate: showsDate,
            onRestore: { performAction { try store.restore(id: item.id) } },
            onDelete: { performAction { try store.delete(id: item.id) } }
        )
    }

    private var completedGroups: [CompletedGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: olderCompleted) { item in
            calendar.startOfDay(for: item.completedAt ?? .distantPast)
        }
        return grouped
            .map { CompletedGroup(date: $0.key, tasks: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func estimatedAdditionalLines(for text: String) -> Int {
        let explicitLines = text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let estimatedLines = explicitLines.reduce(0) {
            $0 + max(1, Int(ceil(Double($1.count) / 28)))
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
                self.selectedTaskID = store.pendingTasks.first?.id
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

private struct CompletedGroup {
    let date: Date
    let tasks: [TaskItem]
}

private struct CompletedTaskRow: View {
    let item: TaskItem
    let showsDate: Bool
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onRestore) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showsDate, let completedAt = item.completedAt {
                    Text(completedAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 5)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .opacity(isHovered ? 1 : 0)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
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
