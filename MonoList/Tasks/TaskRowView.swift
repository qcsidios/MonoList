import SwiftUI

struct TaskRowView: View {
    let item: TaskItem
    let onSave: (String) -> Void
    let onComplete: (String) -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onInsertAfter: () -> Void
    let onUpdateReminder: (TaskReminder?) -> Void
    let isSelected: Bool
    let onSelect: () -> Void
    let onEditingChanged: (Bool) -> Void

    @State private var text: String
    @State private var originalText: String
    @State private var isEditingMode = false
    @State private var isHovered = false
    @State private var isEditorFocused = false
    @State private var isReminderPopoverPresented = false

    init(
        item: TaskItem,
        onSave: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void,
        onDelete: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onInsertAfter: @escaping () -> Void,
        onUpdateReminder: @escaping (TaskReminder?) -> Void,
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
        self.onUpdateReminder = onUpdateReminder
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onEditingChanged = onEditingChanged
        _text = State(initialValue: item.text)
        _originalText = State(initialValue: item.text)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
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

            VStack(alignment: .leading, spacing: 4) {
                Group {
                    if isEditingMode {
                        TaskTextEditor(
                            text: $text,
                            isFocused: $isEditorFocused
                        ) {
                            finishEditing()
                            onInsertAfter()
                        }
                            .onAppear {
                                DispatchQueue.main.async {
                                    isEditorFocused = true
                                }
                            }
                    } else {
                        Text(text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                TapGesture(count: 2).onEnded {
                                    beginEditing()
                                }
                            )
                    }
                }
                if !isEditingMode {
                    reminderStatusLine
                }
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .opacity(isHovered || isSelected ? 1 : 0)
            }
            .buttonStyle(.plain)
            .help("删除")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            isSelected && !isEditingMode ? Color.primary.opacity(0.055) : .clear,
            in: RoundedRectangle(cornerRadius: 9)
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded(onSelect))
        .onHover { isHovered = $0 }
        .onChange(of: isEditorFocused) { oldValue, newValue in
            if oldValue && !newValue && isEditingMode {
                finishEditing()
            }
        }
        .onChange(of: isSelected) { _, newValue in
            if !newValue && isEditingMode {
                isEditorFocused = false
            }
        }
        .onDisappear {
            if isEditingMode {
                finishEditing()
            }
        }
        .contextMenu {
            Button("设置提醒…") {
                DispatchQueue.main.async {
                    isReminderPopoverPresented = true
                }
            }
            if item.reminder != nil {
                Button("清除提醒") {
                    onUpdateReminder(nil)
                }
            }
            Divider()
            Button("上移", action: onMoveUp)
            Button("下移", action: onMoveDown)
            Divider()
            Button("删除", role: .destructive, action: onDelete)
        }
        .popover(isPresented: $isReminderPopoverPresented, arrowEdge: .trailing) {
            TaskReminderEditor(
                reminder: item.reminder,
                onSave: { reminder in
                    onUpdateReminder(reminder)
                    isReminderPopoverPresented = false
                },
                onClear: {
                    onUpdateReminder(nil)
                    isReminderPopoverPresented = false
                }
            )
        }
    }

    @ViewBuilder
    private var reminderStatusLine: some View {
        if let title = reminderTitle {
            HStack(spacing: 4) {
                Image(systemName: "bell")
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
        }
    }

    private var reminderTitle: String? {
        guard let reminder = item.reminder else { return nil }
        switch reminder.kind {
        case .once:
            guard let date = reminder.date else { return nil }
            return "今天 \(Self.timeTitle(for: date))"
        case .daily:
            return "每天 \(Self.timeTitle(minuteOfDay: reminder.minuteOfDay))"
        }
    }

    private func beginEditing() {
        originalText = text
        onSelect()
        isEditingMode = true
        onEditingChanged(true)
    }

    private func finishEditing() {
        saveIfNeeded()
        isEditorFocused = false
        isEditingMode = false
        onEditingChanged(false)
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

    private static func timeTitle(for date: Date) -> String {
        date.formatted(
            .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        )
    }

    private static func timeTitle(minuteOfDay: Int) -> String {
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}

private enum TaskReminderEditMode: String, CaseIterable, Identifiable {
    case today = "今天"
    case daily = "每天"

    var id: String { rawValue }
}

private struct TaskReminderEditor: View {
    let reminder: TaskReminder?
    let onSave: (TaskReminder) -> Void
    let onClear: () -> Void

    @State private var mode: TaskReminderEditMode
    @State private var hour: Int
    @State private var minute: Int

    init(
        reminder: TaskReminder?,
        onSave: @escaping (TaskReminder) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.reminder = reminder
        self.onSave = onSave
        self.onClear = onClear
        let initialMode: TaskReminderEditMode
        let initialMinuteOfDay: Int
        switch reminder?.kind {
        case .daily:
            initialMode = .daily
            initialMinuteOfDay = reminder?.minuteOfDay ?? Self.nearestUpcomingMinute()
        case .once:
            initialMode = .today
            initialMinuteOfDay = reminder?.date.map(Self.minuteOfDay) ??
                Self.nearestUpcomingMinute()
        case nil:
            initialMode = .today
            initialMinuteOfDay = Self.nearestUpcomingMinute()
        }
        _mode = State(initialValue: initialMode)
        _hour = State(initialValue: initialMinuteOfDay / 60)
        _minute = State(initialValue: initialMinuteOfDay % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提醒我")
                .font(.system(size: 13, weight: .semibold))

            Picker("", selection: $mode) {
                ForEach(TaskReminderEditMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 8) {
                ReminderTimeDropdown(
                    title: String(format: "%02d 时", hour),
                    values: Array(0...23),
                    selectedValue: hour,
                    titleForValue: { String(format: "%02d 时", $0) },
                    onSelect: { hour = $0 }
                )
                ReminderTimeDropdown(
                    title: String(format: "%02d 分", minute),
                    values: stride(from: 0, through: 50, by: 10).map { $0 },
                    selectedValue: minute,
                    titleForValue: { String(format: "%02d 分", $0) },
                    onSelect: { minute = $0 }
                )
            }

            HStack {
                Button("清除提醒", action: onClear)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .disabled(reminder == nil)
                Spacer()
                Button("保存") {
                    onSave(makeReminder())
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(saveDisabled ? .secondary : .primary)
                .disabled(saveDisabled)
            }
        }
        .padding(12)
        .frame(width: 220)
    }

    private var saveDisabled: Bool {
        mode == .today && todayReminderDate <= Date()
    }

    private var todayReminderDate: Date {
        Calendar.current.startOfDay(for: Date())
            .addingTimeInterval(TimeInterval(minuteOfDay * 60))
    }

    private var minuteOfDay: Int {
        hour * 60 + minute
    }

    private func makeReminder() -> TaskReminder {
        switch mode {
        case .today:
            return .once(at: todayReminderDate)
        case .daily:
            return .daily(
                minuteOfDay: minuteOfDay,
                id: reminder?.recurrenceID ?? UUID(),
                lastTriggeredAt: reminder?.lastTriggeredAt
            )
        }
    }

    private static func nearestUpcomingMinute(now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let current = (components.hour ?? 9) * 60 + (components.minute ?? 0)
        let rounded = ((current + 9) / 10) * 10
        return min(rounded, 23 * 60 + 50)
    }

    private static func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func timeTitle(minuteOfDay: Int) -> String {
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}

private struct ReminderTimeDropdown: View {
    let title: String
    let values: [Int]
    let selectedValue: Int
    let titleForValue: (Int) -> String
    let onSelect: (Int) -> Void

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            ZStack {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .frame(height: 28)
            .background(
                Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            onSelect(value)
                            isPresented = false
                        } label: {
                            Text(titleForValue(value))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .frame(height: Self.rowHeight)
                                .background(
                                    value == selectedValue ?
                                        Color.primary.opacity(0.055) : .clear
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(width: 86, height: menuHeight)
        }
    }

    private var menuHeight: CGFloat {
        CGFloat(min(values.count, Self.maxVisibleItems)) * Self.rowHeight + 8
    }

    private static let maxVisibleItems = 8
    private static let rowHeight: CGFloat = 28
}
