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
    @State private var originalText: String
    @State private var isHovered = false
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
        _originalText = State(initialValue: item.text)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                onComplete(text)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("标记为完成")

            Group {
                if isEditing {
                    TextField("待办内容", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .focused($isEditing)
                        .onSubmit {
                            saveIfNeeded()
                            isEditing = false
                            onInsertAfter()
                        }
                } else {
                    Text(text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            originalText = text
                            isEditing = true
                        }
                }
            }
            .padding(.vertical, 5)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .opacity(isHovered || isSelected ? 1 : 0)
            }
            .buttonStyle(.plain)
            .help("删除")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            isSelected && !isEditing ? Color.primary.opacity(0.06) : .clear,
            in: RoundedRectangle(cornerRadius: 9)
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded(onSelect))
        .onHover { isHovered = $0 }
        .onChange(of: isEditing) { oldValue, newValue in
            if oldValue && !newValue {
                saveIfNeeded()
            }
            onEditingChanged(newValue)
        }
        .contextMenu {
            Button("上移", action: onMoveUp)
            Button("下移", action: onMoveDown)
            Divider()
            Button("删除", role: .destructive, action: onDelete)
        }
    }

    private func saveIfNeeded() {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            text = originalText
            return
        }
        guard text != originalText else { return }
        onSave(text)
        originalText = text
    }
}
