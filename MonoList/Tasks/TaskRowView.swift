import SwiftUI

struct TaskRowView: View {
    let item: TaskItem
    let onSave: (String) -> Void
    let onComplete: (String) -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onInsertAfter: () -> Void
    let isSelected: Bool
    let onSelect: () -> Void
    let onEditingChanged: (Bool) -> Void

    @State private var text: String
    @State private var isHovered = false
    @State private var pendingSave: DispatchWorkItem?
    @State private var suppressDisappearSave = false
    @FocusState private var isEditing: Bool

    init(
        item: TaskItem,
        onSave: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void,
        onDelete: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onInsertAfter: @escaping () -> Void,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onEditingChanged: @escaping (Bool) -> Void
    ) {
        self.item = item
        self.onSave = onSave
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onInsertAfter = onInsertAfter
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onEditingChanged = onEditingChanged
        _text = State(initialValue: item.text)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Button {
                pendingSave?.cancel()
                suppressDisappearSave = true
                onComplete(text)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("标记为完成")

            TextField("待办内容", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isEditing)
                .onChange(of: text) { _, newValue in
                    scheduleSave(newValue)
                }
                .onSubmit {
                    flushSave()
                    onInsertAfter()
                }

            if isHovered {
                Button {
                    suppressDisappearSave = true
                    pendingSave?.cancel()
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("删除")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            isSelected && !isEditing ? Color.accentColor.opacity(0.12) : .clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded(onSelect))
        .onHover { isHovered = $0 }
        .onChange(of: isEditing) { _, value in
            onEditingChanged(value)
        }
        .contextMenu {
            Button("上移", action: onMoveUp)
            Button("下移", action: onMoveDown)
            Divider()
            Button("删除", role: .destructive) {
                suppressDisappearSave = true
                pendingSave?.cancel()
                onDelete()
            }
        }
        .onDisappear {
            if !suppressDisappearSave {
                flushSave()
            }
        }
    }

    private func scheduleSave(_ value: String) {
        pendingSave?.cancel()
        let workItem = DispatchWorkItem {
            onSave(value)
        }
        pendingSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func flushSave() {
        pendingSave?.cancel()
        pendingSave = nil
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(normalized.isEmpty ? item.text : text)
    }
}
