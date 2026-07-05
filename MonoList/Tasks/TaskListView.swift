import AppKit
import SwiftUI

struct TaskListView: View {
    @ObservedObject var store: TaskStore
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @State private var draft = ""
    @State private var draftSave: DispatchWorkItem?
    @State private var draftAfterID: UUID?
    @State private var isShowingHistory = false
    @State private var errorMessage: String?
    @State private var selectedTaskID: UUID?
    @State private var editingTaskID: UUID?
    @State private var keyboardMonitor: Any?
    @FocusState private var draftFocused: Bool

    var body: some View {
        Group {
            if let loadError = store.loadError {
                DataRecoveryView(
                    message: loadError.localizedDescription,
                    onRetry: { store.retryLoad() },
                    onQuit: { NSApp.terminate(nil) }
                )
            } else if isShowingHistory {
                HistoryView(
                    tasks: store.historyTasks,
                    onBack: { isShowingHistory = false },
                    onRestore: perform { id in try store.restore(id: id) },
                    onDelete: perform { id in try store.delete(id: id) },
                    onClear: perform { try store.clearHistory() }
                )
            } else {
                mainList
            }
        }
        .frame(
            width: WindowCoordinator.mainPanelWidth,
            height: WindowCoordinator.mainPanelMaximumHeight
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
    }

    private var mainList: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    draftAfterID = nil
                    draftFocused = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("新增待办")

                Spacer()

                Button {
                    flushDraft()
                    isShowingHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .help("历史记录")

                Button {
                    flushDraft()
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("设置")
            }
            .buttonStyle(.plain)
            .padding(14)

            Divider()

            if store.pendingTasks.isEmpty {
                Spacer()
                Text("暂无待办")
                    .foregroundStyle(.secondary)
                draftField
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                Spacer()
            } else {
                List {
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
                                flushDraft()
                                draftAfterID = item.id
                                draftFocused = true
                            },
                            isSelected: selectedTaskID == item.id,
                            onSelect: { selectedTaskID = item.id },
                            onEditingChanged: { editing in
                                editingTaskID = editing ? item.id : nil
                            }
                        )
                        if draftAfterID == item.id {
                            draftField
                                .listRowSeparator(.hidden)
                        }
                    }
                    .onMove { indices, destination in
                        var ids = store.pendingTasks.map(\.id)
                        ids.move(fromOffsets: indices, toOffset: destination)
                        do {
                            try store.reorder(ids: ids)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }

                    if draftAfterID == nil {
                        draftField
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .onDisappear {
            flushDraft()
            removeKeyboardMonitor()
        }
        .onAppear {
            installKeyboardMonitor()
        }
    }

    private var draftField: some View {
        TextField("输入待办，按 Enter 保存", text: $draft, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...6)
            .focused($draftFocused)
            .onChange(of: draft) { _, value in
                scheduleDraftSave(value)
            }
            .onSubmit {
                flushDraft()
                draftFocused = true
            }
            .padding(.vertical, 8)
    }

    private func scheduleDraftSave(_ value: String) {
        draftSave?.cancel()
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let workItem = DispatchWorkItem {
            saveDraft(value)
        }
        draftSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func flushDraft() {
        draftSave?.cancel()
        draftSave = nil
        saveDraft(draft)
    }

    private func saveDraft(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return
        }
        do {
            _ = try store.add(text: value, after: draftAfterID)
            draft = ""
            draftAfterID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func installKeyboardMonitor() {
        guard keyboardMonitor == nil else {
            return
        }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard editingTaskID == nil,
                  !draftFocused,
                  let selectedTaskID else {
                return event
            }
            do {
                if event.keyCode == 51 || event.keyCode == 117 {
                    try store.delete(id: selectedTaskID)
                    self.selectedTaskID = store.pendingTasks.first?.id
                    return nil
                }
                if event.modifierFlags.contains(.command), event.keyCode == 126 {
                    try store.move(id: selectedTaskID, by: -1)
                    return nil
                }
                if event.modifierFlags.contains(.command), event.keyCode == 125 {
                    try store.move(id: selectedTaskID, by: 1)
                    return nil
                }
            } catch {
                errorMessage = error.localizedDescription
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

    private func perform(_ action: @escaping () throws -> Void) -> () -> Void {
        {
            do {
                try action()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func perform<Value>(
        _ action: @escaping (Value) throws -> Void
    ) -> (Value) -> Void {
        { value in
            do {
                try action(value)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
