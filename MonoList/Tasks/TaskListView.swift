import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct TaskListView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var focusStore: FocusStore
    @ObservedObject var draftState: TaskDraftState
    let onClose: () -> Void
    let onOpenSettings: () -> Void
    let onFocusInteraction: () -> Void
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
    @State private var taskRowHeights: [UUID: CGFloat] = [:]
    @State private var displayMode: MainContentMode = .list
    @State private var selectionOrigin: FocusSelectionOrigin = .list
    @State private var focusSelectionDraft: [UUID] = []
    @State private var focusSelectionSnapshot: [UUID] = []
    @State private var focusDraggingID: UUID?
    @State private var focusKeyboardID: UUID?
    @State private var focusCapturePresented = false
    @State private var focusCaptureText = ""
    @State private var focusCaptureFocused = false
    @State private var focusToastVisible = false

    init(
        store: TaskStore,
        focusStore: FocusStore,
        draftState: TaskDraftState,
        onClose: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onFocusInteraction: @escaping () -> Void,
        onHeightChanged: @escaping (CGFloat) -> Void
    ) {
        self.store = store
        self.focusStore = focusStore
        self.draftState = draftState
        self.onClose = onClose
        self.onOpenSettings = onOpenSettings
        self.onFocusInteraction = onFocusInteraction
        self.onHeightChanged = onHeightChanged
        _displayMode = State(initialValue: focusStore.isActive() ? .focus : .list)
    }

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

    private var activeFocusIDs: [UUID] {
        focusStore.taskIDs(at: currentDate)
    }

    private var activeFocusTasks: [TaskItem] {
        let tasksByID = Dictionary(uniqueKeysWithValues: store.tasks.map { ($0.id, $0) })
        return activeFocusIDs.compactMap { tasksByID[$0] }
    }

    private var pendingFocusTasks: [TaskItem] {
        activeFocusTasks.filter { $0.status == .pending }
    }

    private var lockedFocusTasks: [TaskItem] {
        activeFocusTasks.filter { $0.status == .history }
    }

    private var currentFocusTask: TaskItem? {
        activeFocusTasks.first { $0.status == .pending }
    }

    private var focusSelectableTasks: [TaskItem] {
        store.shortTermTasks + store.longTermTasks
    }

    private var shouldShowFocusEntry: Bool {
        !focusStore.isActive(at: currentDate) && !store.pendingTasks.isEmpty
    }

    private var yesterdaySuggestionIDs: Set<UUID> {
        Set(focusStore.suggestedTaskIDs(at: currentDate))
    }

    private var naturalHeight: CGFloat {
        var extraLines = (todayCompleted + visibleOlderCompleted).reduce(0) {
            $0 + Self.additionalLines(for: $1.text)
        }
        if draftState.isPresented {
            extraLines += Self.additionalLines(for: draftState.text)
        }
        let pendingAdditionalHeight = store.pendingTasks.reduce(CGFloat.zero) {
            height, item in
            if let measuredHeight = taskRowHeights[item.id] {
                return height + max(0, measuredHeight - 36)
            }
            let addedRows = Self.additionalLines(for: item.text) +
                (item.reminder == nil ? 0 : 1)
            return height + CGFloat(addedRows * 17)
        }
        let rows = store.pendingTasks.count +
            todayCompleted.count +
            visibleOlderCompleted.count +
            (draftState.isPresented ? 1 : 0)
        let dateHeaders = showsOlderCompleted ? completedGroups.count : 0
        let focusEntryHeight: CGFloat = shouldShowFocusEntry ? 45 : 0
        return Self.contentHeight(
            rowCount: rows,
            additionalLineCount: extraLines,
            dateHeaderCount: dateHeaders
        ) + pendingAdditionalHeight + 58 + focusEntryHeight
    }

    private var preferredHeight: CGFloat {
        if displayMode == .focus {
            return Self.focusContentHeight(
                for: activeFocusTasks,
                showsCapture: focusCapturePresented
            )
        }
        if displayMode == .selection {
            let selectionRows = store.pendingTasks.count + lockedFocusTasks.count
            return min(
                max(190 + CGFloat(selectionRows * 38), 280),
                WindowCoordinator.mainPanelMaximumHeight
            )
        }
        return min(
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
                mainContent
            }
        }
        .frame(width: WindowCoordinator.mainPanelWidth, height: preferredHeight)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .environment(\.colorScheme, .light)
        .onAppear {
            focusStore.reconcile(existingTaskIDs: Set(store.tasks.map(\.id)))
            if focusStore.isActive(at: currentDate) {
                displayMode = .focus
                focusKeyboardID = currentFocusTask?.id
            }
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
        .onChange(of: store.tasks) { _, tasks in
            focusStore.reconcile(existingTaskIDs: Set(tasks.map(\.id)))
            if displayMode == .focus && !focusStore.isActive(at: currentDate) {
                displayMode = .list
            }
        }
        .onReceive(
            Timer.publish(every: 60, on: .main, in: .common).autoconnect()
        ) { date in
            currentDate = date
            if displayMode != .list && !focusStore.isActive(at: date) {
                displayMode = .list
            }
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

    @ViewBuilder
    private var mainContent: some View {
        switch displayMode {
        case .list:
            mainList
        case .selection:
            focusSelectionView
        case .focus:
            focusView
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

            VStack(spacing: 0) {
                if shouldShowFocusEntry {
                    focusEntry
                }
                taskGroupSection(.shortTerm, title: "短期任务")
                taskGroupSection(.longTerm, title: "长期任务")
                completedSection
            }
            .padding(.horizontal, 7)
            .padding(.top, 7)
            .padding(.bottom, 7)
            .frame(maxWidth: .infinity, alignment: .top)
            .onPreferenceChange(TaskRowHeightPreferenceKey.self) { heights in
                taskRowHeights = heights
            }
        }
    }

    private var header: some View {
        Group {
            if focusStore.isActive(at: currentDate) {
                activeFocusListHeader
            } else {
                standardListHeader
            }
        }
    }

    private var standardListHeader: some View {
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

    private var activeFocusListHeader: some View {
        HStack(spacing: 7) {
            Text("全部待办")
                .font(.system(size: 15, weight: .semibold))
            WindowDragArea()
                .frame(maxWidth: .infinity)
                .frame(height: 30)
            Button("返回专注") {
                commitDraft()
                displayMode = .focus
                focusKeyboardID = currentFocusTask?.id
                onFocusInteraction()
            }
            .buttonStyle(FocusHeaderTextButtonStyle())

            Menu {
                Button("新增待办") {
                    commitDraft()
                    focusDraft(after: store.shortTermTasks.last?.id)
                }
                Button("打开控制台") {
                    commitDraft()
                    onOpenSettings()
                }
                Divider()
                Button("清空未完成任务") { clearAction = .pending }
                    .disabled(store.pendingTasks.isEmpty)
                Button("清空已完成任务") { clearAction = .completed }
                    .disabled(store.historyTasks.isEmpty)
                Button("清空全部任务", role: .destructive) { clearAction = .all }
                    .disabled(store.tasks.isEmpty)
            } label: {
                HeaderIconLabel(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(HeaderIconButtonStyle())
            .frame(width: 30, height: 30)
            .help("更多操作")
        }
        .padding(.leading, 14)
        .padding(.trailing, 9)
        .frame(height: 52)
    }

    private var focusEntry: some View {
        Button {
            commitDraft()
            if focusStore.isActive(at: currentDate) {
                displayMode = .focus
                focusKeyboardID = currentFocusTask?.id
                onFocusInteraction()
            } else {
                beginFocusSelection(origin: .list)
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: focusStore.isActive(at: currentDate)
                      ? "play.fill" : "list.number")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 6))
                Text(focusStore.isActive(at: currentDate)
                     ? "继续专注" : "选择今日专注")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 39)
            .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 3)
        .padding(.bottom, 6)
    }

    private func focusOrder(for id: UUID) -> Int? {
        guard focusStore.isActive(at: currentDate),
              let index = activeFocusIDs.firstIndex(of: id) else {
            return nil
        }
        return index + 1
    }

    private var focusSelectionView: some View {
        VStack(spacing: 0) {
            focusSelectionHeader
            Divider().opacity(0.45)
            ScrollView {
                VStack(spacing: 0) {
                    if !lockedFocusTasks.isEmpty {
                        focusSelectionSectionTitle("已完成 · 今日专注", count: lockedFocusTasks.count)
                        ForEach(lockedFocusTasks) { item in
                            focusSelectionRow(item, locked: true)
                        }
                    }
                    focusSelectionGroup(.shortTerm, title: "短期任务")
                    focusSelectionGroup(.longTerm, title: "长期任务")
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 7)
            }
            Divider().opacity(0.45)
            HStack(spacing: 8) {
                Text("已选 \(focusSelectionDraft.count) 件")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if focusSelectionDraft.count == 3 {
                    Text("已到上限")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("清空") {
                    focusSelectionDraft.removeAll()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .disabled(focusSelectionDraft.isEmpty)

                Button(focusSelectionPrimaryTitle) {
                    saveFocusSelection()
                }
                .buttonStyle(FocusPrimaryButtonStyle())
                .disabled(selectionOrigin == .list && focusSelectionDraft.isEmpty)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
        }
    }

    private var focusSelectionHeader: some View {
        HStack(spacing: 7) {
            Text(selectionOrigin == .focus ? "调整今日专注" : "选择今日专注")
                .font(.system(size: 17, weight: .semibold))
            Text("\(focusSelectionDraft.count)/3")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            WindowDragArea()
                .frame(maxWidth: .infinity)
                .frame(height: 30)
            Button("取消") {
                cancelFocusSelection()
            }
            .buttonStyle(FocusHeaderTextButtonStyle())
        }
        .padding(.leading, 14)
        .padding(.trailing, 9)
        .frame(height: 54)
    }

    private func focusSelectionGroup(_ group: TaskGroup, title: String) -> some View {
        let groupTasks = tasks(in: group)
        return VStack(spacing: 0) {
            focusSelectionSectionTitle(title, count: groupTasks.count)
            ForEach(groupTasks) { item in
                focusSelectionRow(item, locked: false)
            }
        }
    }

    private func focusSelectionSectionTitle(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 29)
    }

    private func focusSelectionRow(_ item: TaskItem, locked: Bool) -> some View {
        let order = focusSelectionDraft.firstIndex(of: item.id).map { $0 + 1 }
        let canAdd = focusSelectionDraft.count < 3
        let suggested = yesterdaySuggestionIDs.contains(item.id) && order == nil
        return HStack(spacing: 9) {
            Group {
                if let order {
                    Text("\(order)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.primary, in: Circle())
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(canAdd ? .secondary : .tertiary)
                        .frame(width: 20, height: 20)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(.system(size: 13))
                    .foregroundStyle(locked || (!canAdd && order == nil) ? .secondary : .primary)
                    .strikethrough(locked)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if locked || suggested {
                    Text(locked ? "已完成 · 当天保留" : "昨天专注")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
            } else {
                Color.clear.frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(focusSelectionRowBackground(order: order, itemID: item.id),
                    in: RoundedRectangle(cornerRadius: 9))
        .onTapGesture {
            guard !locked else { return }
            focusKeyboardID = item.id
            toggleFocusSelection(item.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            locked
                ? "\(item.text)，已完成，当天保留"
                : "\(item.text)\(order.map { "，专注第 \($0) 项" } ?? "，未选择")"
        )
        .accessibilityHint(locked ? "已锁定" : "按空格选择或取消")
        .onDrag {
            guard order != nil else { return NSItemProvider() }
            focusDraggingID = item.id
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: FocusSelectionDropDelegate(
                targetID: item.id,
                draggingID: $focusDraggingID,
                orderedIDs: $focusSelectionDraft
            )
        )
    }

    private func focusSelectionRowBackground(order: Int?, itemID: UUID) -> Color {
        if focusKeyboardID == itemID {
            return Color.accentColor.opacity(0.10)
        }
        return order != nil ? Color.primary.opacity(0.035) : .clear
    }

    private var focusView: some View {
        VStack(spacing: 0) {
            focusHeader
            Divider().opacity(0.45)
            if focusCapturePresented {
                focusCaptureRow
                Divider().opacity(0.35)
            }
            focusTaskContent
        }
        .overlay(alignment: .bottom) {
            if focusToastVisible {
                HStack(spacing: 7) {
                    Text("已加入短期任务")
                    Button("调整今日专注") {
                        beginFocusSelection(origin: .focus)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(Color.primary.opacity(0.94), in: RoundedRectangle(cornerRadius: 9))
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var focusHeader: some View {
        let progress = currentFocusTask.flatMap { item in
            activeFocusTasks.firstIndex(where: { $0.id == item.id }).map { $0 + 1 }
        } ?? activeFocusTasks.count
        let allCompleted = !activeFocusTasks.isEmpty && currentFocusTask == nil
        return HStack(spacing: 7) {
            Text(allCompleted ? "今日完成" : "今日专注")
                .font(.system(size: 15, weight: .semibold))
            Text("\(progress)/\(activeFocusTasks.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            WindowDragArea()
                .frame(maxWidth: .infinity)
                .frame(height: 30)
            Button("全部") {
                displayMode = .list
                onFocusInteraction()
            }
            .buttonStyle(FocusQuietTextButtonStyle())
            .accessibilityHint("查看全部待办，可通过返回专注回到当前进度")
            Menu {
                Button("调整今日专注") {
                    beginFocusSelection(origin: .focus)
                }
                Button("新增待办") {
                    focusCapturePresented = true
                    focusCaptureFocused = true
                }
                Button("打开控制台") {
                    onOpenSettings()
                }
                Divider()
                Button("结束专注") {
                    endFocus()
                }
            } label: {
                HeaderIconLabel(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(HeaderIconButtonStyle())
            .frame(width: 30, height: 30)
            .help("更多操作")
            .accessibilityLabel("更多操作")
        }
        .padding(.leading, 17)
        .padding(.trailing, 9)
        .frame(height: 52)
    }

    private var focusCaptureRow: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: "circle")
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)
                .frame(width: 28, height: 28)
            TaskTextEditor(
                text: $focusCaptureText,
                isFocused: $focusCaptureFocused,
                onSubmit: submitFocusCapture
            )
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.025))
    }

    private var focusTaskContent: some View {
        VStack(spacing: 0) {
            if let currentFocusTask {
                HStack(alignment: .top, spacing: 13) {
                    Button {
                        completeFocusTask(currentFocusTask)
                    } label: {
                        Image(systemName: "circle")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(
                                focusKeyboardID == currentFocusTask.id
                                    ? .primary : .secondary
                            )
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("完成当前任务")
                    VStack(alignment: .leading, spacing: 7) {
                        Text("当前")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        Text(currentFocusTask.text)
                            .font(.system(size: 19, weight: .semibold))
                            .lineLimit(3)
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 21)
                .padding(.bottom, 22)
                .contextMenu {
                    Button("删除", role: .destructive) {
                        deleteFocusTask(currentFocusTask)
                    }
                }
                if pendingFocusTasks.count > 1 {
                    Divider().opacity(0.45)
                    Text("接下来")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 57)
                        .padding(.top, 12)
                        .padding(.bottom, 3)
                    ForEach(pendingFocusTasks.dropFirst()) { item in
                        focusFollowingRow(item)
                    }
                }
            } else {
                VStack(spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .medium))
                    Text("今天的专注已完成")
                        .font(.system(size: 16, weight: .semibold))
                    Text("剩余待办仍在“全部”里")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            }
            Spacer(minLength: 8)
        }
    }

    private func focusFollowingRow(_ item: TaskItem) -> some View {
        return HStack(spacing: 10) {
            Button {
                completeFocusTask(item)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(
                        focusKeyboardID == item.id ? .primary : .secondary
                    )
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("完成任务")
            Text(item.text)
                .font(.system(size: 14))
                .lineLimit(2)
                .lineSpacing(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .frame(minHeight: 47)
        .contentShape(Rectangle())
        .contextMenu {
            Button("删除", role: .destructive) {
                deleteFocusTask(item)
            }
        }
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
            dropCoordinator.target?.group == group &&
                dropCoordinator.target?.highlightsGroupHeader == true
                ? Color.accentColor.opacity(0.08)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .onDrop(of: [UTType.text], delegate: TaskGroupDropDelegate(
            group: group,
            upperBeforeID: nil,
            lowerBeforeID: nil,
            rowHeight: 29,
            highlightsGroupHeader: true,
            sessionID: dropCoordinator.sessionID,
            store: store,
            coordinator: dropCoordinator,
            errorMessage: $errorMessage
        ))

        ForEach(Array(groupTasks.enumerated()), id: \.element.id) { index, item in
            TaskRowView(
                item: item,
                onSave: { text in
                    performAction { try store.updateText(id: item.id, text: text) }
                    if activeFocusIDs.contains(item.id) { onFocusInteraction() }
                },
                onComplete: { text in
                    performAction { try store.complete(id: item.id, finalText: text) }
                    if activeFocusIDs.contains(item.id) { onFocusInteraction() }
                },
                onDelete: {
                    performAction { try store.delete(id: item.id) }
                    if activeFocusIDs.contains(item.id) { onFocusInteraction() }
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
                focusOrder: focusOrder(for: item.id),
                isSelected: selectedTaskID == item.id,
                onSelect: { selectTask(item.id) },
                onEditingChanged: { editing in
                    editingTaskID = editing ? item.id : nil
                }
            )
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TaskRowHeightPreferenceKey.self,
                        value: [item.id: proxy.size.height]
                    )
                }
            }
            .overlay(alignment: .top) {
                if dropCoordinator.target == TaskDropTarget(
                    group: group,
                    beforeID: item.id
                ) {
                    TaskDragInsertionIndicator()
                }
            }
            .overlay(alignment: .bottom) {
                if index == groupTasks.count - 1,
                   dropCoordinator.target == TaskDropTarget(
                       group: group,
                       beforeID: nil
                   ) {
                    TaskDragInsertionIndicator()
                }
            }
            .onDrag {
                dropCoordinator.beginDragging(task: item)
                return NSItemProvider(object: item.id.uuidString as NSString)
            } preview: {
                TaskDragPreview(text: item.text)
            }
            .onDrop(
                of: [UTType.text],
                delegate: TaskGroupDropDelegate(
                    group: group,
                    upperBeforeID: item.id,
                    lowerBeforeID: groupTasks.indices.contains(index + 1)
                        ? groupTasks[index + 1].id
                        : nil,
                    rowHeight: taskRowHeights[item.id] ?? 36,
                    highlightsGroupHeader: false,
                    sessionID: dropCoordinator.sessionID,
                    store: store,
                    coordinator: dropCoordinator,
                    errorMessage: $errorMessage
                )
            )

            if draftState.isPresented && draftState.afterID == item.id {
                draftDropRow(
                    group: group,
                    beforeID: groupTasks.indices.contains(index + 1)
                        ? groupTasks[index + 1].id
                        : nil
                )
            }
        }
        if draftState.isPresented && draftState.group == group && draftState.afterID == nil {
            draftDropRow(group: group, beforeID: nil)
        }
    }

    private func draftDropRow(group: TaskGroup, beforeID: UUID?) -> some View {
        draftRow
            .id("task-draft-row")
            .onDrop(
                of: [UTType.text],
                delegate: TaskGroupDropDelegate(
                    group: group,
                    upperBeforeID: beforeID,
                    lowerBeforeID: beforeID,
                    rowHeight: 36,
                    highlightsGroupHeader: false,
                    sessionID: dropCoordinator.sessionID,
                    store: store,
                    coordinator: dropCoordinator,
                    errorMessage: $errorMessage
                )
            )
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
            onRestore: {
                performAction { try store.restore(id: item.id) }
                if activeFocusIDs.contains(item.id) { onFocusInteraction() }
            },
            onDelete: {
                performAction { try store.delete(id: item.id) }
                if activeFocusIDs.contains(item.id) { onFocusInteraction() }
            }
        )
    }

    private func beginFocusSelection(origin: FocusSelectionOrigin) {
        commitDraft()
        selectionOrigin = origin
        let currentIDs = focusStore.taskIDs(at: currentDate)
        focusSelectionDraft = origin == .focus ? currentIDs : []
        focusSelectionSnapshot = currentIDs
        focusKeyboardID = focusSelectionDraft.first ?? focusSelectableTasks.first?.id
        displayMode = .selection
        onFocusInteraction()
    }

    private func cancelFocusSelection() {
        focusSelectionDraft = focusSelectionSnapshot
        displayMode = selectionOrigin == .focus ? .focus : .list
        focusKeyboardID = currentFocusTask?.id
        onFocusInteraction()
    }

    private func toggleFocusSelection(_ id: UUID) {
        if let index = focusSelectionDraft.firstIndex(of: id) {
            focusSelectionDraft.remove(at: index)
            return
        }
        guard focusSelectionDraft.count < 3 else { return }
        focusSelectionDraft.append(id)
    }

    private func saveFocusSelection() {
        do {
            if focusSelectionDraft.isEmpty {
                endFocus()
                return
            }
            try focusStore.setSelection(
                focusSelectionDraft,
                existingTaskIDs: Set(store.tasks.map(\.id)),
                completedTaskIDs: Set(store.historyTasks.map(\.id)),
                at: currentDate
            )
            displayMode = .focus
            focusKeyboardID = currentFocusTask?.id
            onFocusInteraction()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func endFocus() {
        do {
            try focusStore.clearSelection()
            focusSelectionDraft.removeAll()
            focusSelectionSnapshot.removeAll()
            focusKeyboardID = nil
            focusCapturePresented = false
            focusCaptureText = ""
            focusCaptureFocused = false
            displayMode = .list
            onFocusInteraction()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var focusSelectionPrimaryTitle: String {
        if selectionOrigin == .focus && focusSelectionDraft.isEmpty {
            return "结束专注"
        }
        return selectionOrigin == .focus ? "完成调整" : "开始专注"
    }

    private func submitFocusCapture() {
        let normalized = focusCaptureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            focusCapturePresented = false
            focusCaptureFocused = false
            return
        }
        do {
            _ = try store.add(text: normalized, group: .shortTerm)
            focusCaptureText = ""
            focusCapturePresented = false
            focusCaptureFocused = false
            onFocusInteraction()
            withAnimation(.easeOut(duration: 0.18)) {
                focusToastVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeOut(duration: 0.18)) {
                    focusToastVisible = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completeFocusTask(_ item: TaskItem) {
        performAction { try store.complete(id: item.id) }
        onFocusInteraction()
    }

    private func toggleFocusTaskCompletion(_ item: TaskItem) {
        if item.status == .history {
            performAction { try store.restore(id: item.id) }
        } else {
            performAction { try store.complete(id: item.id) }
        }
        onFocusInteraction()
    }

    private func deleteFocusTask(_ item: TaskItem) {
        performAction { try store.delete(id: item.id) }
        onFocusInteraction()
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

    static func focusContentHeight(
        for tasks: [TaskItem],
        showsCapture: Bool = false
    ) -> CGFloat {
        let pendingTasks = tasks.filter { $0.status == .pending }
        let captureHeight: CGFloat = showsCapture ? 44 : 0
        guard let currentTask = pendingTasks.first else {
            return 201 + captureHeight
        }

        let currentExtraLines = focusAdditionalLines(
            for: currentTask.text,
            fontSize: 19,
            width: 241,
            limit: 3
        )
        let followingTasks = Array(pendingTasks.dropFirst().prefix(2))
        let followingExtraHeight = followingTasks.reduce(CGFloat.zero) { height, task in
            let extraLines = focusAdditionalLines(
                for: task.text,
                fontSize: 14,
                width: 248,
                limit: 2
            )
            return height + 47 + CGFloat(extraLines * 20)
        }
        let followingSectionHeight: CGFloat = followingTasks.isEmpty
            ? 0
            : 31 + followingExtraHeight
        let height = 155 +
            CGFloat(currentExtraLines * 27) +
            followingSectionHeight +
            captureHeight
        return min(
            max(ceil(height), WindowCoordinator.mainPanelMinimumHeight),
            WindowCoordinator.mainPanelMaximumHeight
        )
    }

    private static func focusAdditionalLines(
        for text: String,
        fontSize: CGFloat,
        width: CGFloat,
        limit: Int
    ) -> Int {
        guard !text.isEmpty else { return 0 }
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let bounds = (text as NSString).boundingRect(
            with: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let lineHeight = font.boundingRectForFont.height
        let lineCount = max(1, Int(ceil(bounds.height / lineHeight)))
        return max(0, min(lineCount, limit) - 1)
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
            if displayMode == .selection {
                return handleFocusSelectionKey(event)
            }
            if displayMode == .focus && !focusCaptureFocused {
                return handleFocusViewKey(event)
            }
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

    private func handleFocusSelectionKey(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 {
            cancelFocusSelection()
            return nil
        }
        if (event.keyCode == 36 || event.keyCode == 76),
           event.modifierFlags.contains(.command),
           selectionOrigin == .focus || !focusSelectionDraft.isEmpty {
            saveFocusSelection()
            return nil
        }
        if event.keyCode == 125 || event.keyCode == 126 {
            moveFocusKeyboard(
                through: focusSelectableTasks.map(\.id),
                direction: event.keyCode == 125 ? 1 : -1
            )
            return nil
        }
        if event.keyCode == 49,
           let focusKeyboardID,
           focusSelectableTasks.contains(where: { $0.id == focusKeyboardID }) {
            toggleFocusSelection(focusKeyboardID)
            return nil
        }
        return event
    }

    private func handleFocusViewKey(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 125 || event.keyCode == 126 {
            moveFocusKeyboard(
                through: activeFocusTasks.map(\.id),
                direction: event.keyCode == 125 ? 1 : -1
            )
            return nil
        }
        if event.keyCode == 49,
           let item = focusKeyboardTask ?? currentFocusTask {
            toggleFocusTaskCompletion(item)
            focusKeyboardID = currentFocusTask?.id
            return nil
        }
        return event
    }

    private var focusKeyboardTask: TaskItem? {
        guard let focusKeyboardID else { return nil }
        return activeFocusTasks.first { $0.id == focusKeyboardID }
    }

    private func moveFocusKeyboard(through ids: [UUID], direction: Int) {
        guard !ids.isEmpty else {
            focusKeyboardID = nil
            return
        }
        guard let focusKeyboardID,
              let index = ids.firstIndex(of: focusKeyboardID) else {
            self.focusKeyboardID = direction > 0 ? ids.first : ids.last
            return
        }
        let nextIndex = min(max(index + direction, 0), ids.count - 1)
        self.focusKeyboardID = ids[nextIndex]
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

private enum MainContentMode {
    case list
    case selection
    case focus
}

private enum FocusSelectionOrigin {
    case list
    case focus
}

private struct FocusHeaderTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.09 : 0.055),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct FocusQuietTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? Color.primary : Color.secondary)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(
                configuration.isPressed ? Color.primary.opacity(0.06) : .clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct FocusPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.white : Color.secondary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                isEnabled ? Color.primary : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct FocusSelectionDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingID: UUID?
    @Binding var orderedIDs: [UUID]

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != targetID,
              let sourceIndex = orderedIDs.firstIndex(of: draggingID),
              let targetIndex = orderedIDs.firstIndex(of: targetID) else {
            return
        }
        withAnimation(.easeOut(duration: 0.16)) {
            let moved = orderedIDs.remove(at: sourceIndex)
            orderedIDs.insert(moved, at: targetIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropExited(info: DropInfo) {}
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
    let text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
            Text(text)
                .font(.system(size: 13))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .frame(width: 300)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
        .shadow(color: .black.opacity(0.14), radius: 6, y: 2)
    }
}

private struct TaskDragInsertionIndicator: View {
    var body: some View {
        Capsule()
            .fill(Color.accentColor.opacity(0.72))
            .frame(height: 2)
        .padding(.horizontal, 8)
        .transition(.opacity)
        .allowsHitTesting(false)
    }
}

private struct TaskRowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]

    static func reduce(
        value: inout [UUID: CGFloat],
        nextValue: () -> [UUID: CGFloat]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
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
    let upperBeforeID: UUID?
    let lowerBeforeID: UUID?
    let rowHeight: CGFloat
    let highlightsGroupHeader: Bool
    let sessionID: UUID?
    let store: TaskStore
    let coordinator: TaskDropCoordinator
    @Binding var errorMessage: String?

    func dropEntered(info: DropInfo) {
        updateTarget(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateTarget(info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        guard let sessionID else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            coordinator.clearTarget(sessionID: sessionID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let sessionID else { return false }
        updateTarget(info)
        guard let target = coordinator.finishDrop(sessionID: sessionID) else {
            coordinator.clearTarget(sessionID: sessionID)
            return false
        }
        guard let provider = info.itemProviders(for: [UTType.text]).first else {
            return false
        }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            Task { @MainActor in
                guard let value = object as? NSString,
                      let sourceID = UUID(uuidString: value as String) else {
                    return
                }
                do {
                    try withAnimation(
                        .easeOut(duration: 0.16)
                    ) {
                        try store.move(
                            id: sourceID,
                            to: target.group,
                            before: target.beforeID
                        )
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        return true
    }

    private func updateTarget(_ info: DropInfo) {
        guard let sessionID else { return }
        let target = coordinator.dropTarget(
            group: group,
            upperBeforeID: upperBeforeID,
            lowerBeforeID: lowerBeforeID,
            locationY: info.location.y,
            rowHeight: rowHeight,
            highlightsGroupHeader: highlightsGroupHeader
        )
        guard coordinator.target != target else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            coordinator.hover(
                group: target.group,
                before: target.beforeID,
                highlightsGroupHeader: target.highlightsGroupHeader,
                sessionID: sessionID
            )
        }
    }
}
