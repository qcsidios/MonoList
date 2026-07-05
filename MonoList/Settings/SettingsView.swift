import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItemController: LoginItemController
    @ObservedObject var shortcutController: GlobalShortcutController
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var updater: AppUpdater
    let onInstallUpdate: (AppUpdate) -> Void

    @State private var errorMessage: String?
    @State private var clearAction: ClearAction?
    @State private var shortcutMonitor: Any?
    @State private var isRecordingShortcut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                softwareInformation
                Divider()
                reminderSettings
                Divider()
                startupSettings
                Divider()
                shortcutSettings
                Divider()
                dataSettings
            }
            .padding(24)
        }
        .frame(width: 520, height: 560)
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
            Button("永久删除", role: .destructive) {
                performClear()
            }
            Button("取消", role: .cancel) {
                clearAction = nil
            }
        } message: {
            Text(clearAction?.message ?? "")
        }
        .onDisappear {
            stopShortcutRecording()
        }
    }

    private var softwareInformation: some View {
        HStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text("MonoList 一栏")
                    .font(.title2.bold())
                Text("版本 \(appVersion)")
                    .foregroundStyle(.secondary)
                HStack {
                    Button(updater.isChecking ? "正在检测…" : "检测新版本") {
                        Task {
                            await updater.check(manual: true, settings: settings)
                        }
                    }
                    .disabled(updater.isChecking)
                    if let update = updater.availableUpdate {
                        Button("升级到 \(update.version)") {
                            onInstallUpdate(update)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                if !updater.statusText.isEmpty {
                    Text(updater.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var reminderSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提醒").font(.headline)
            Toggle(
                "启用轻提醒",
                isOn: binding(
                    get: { settings.reminderEnabled },
                    update: { $0.reminderEnabled = $1 }
                )
            )
            Picker(
                "提醒间隔",
                selection: binding(
                    get: { settings.reminderIntervalMinutes },
                    update: { $0.reminderIntervalMinutes = $1 }
                )
            ) {
                ForEach([30, 60, 90, 120], id: \.self) {
                    Text("\($0) 分钟").tag($0)
                }
            }
            Picker(
                "提醒位置",
                selection: binding(
                    get: { settings.reminderPosition },
                    update: { $0.reminderPosition = $1 }
                )
            ) {
                ForEach(ReminderPosition.allCases) {
                    Text($0.title).tag($0)
                }
            }
        }
    }

    private var startupSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("开机启动").font(.headline)
            Toggle(
                "登录后自动启动",
                isOn: Binding(
                    get: { loginItemController.status == .enabled },
                    set: { enabled in
                        do {
                            try loginItemController.setEnabled(enabled)
                            try settings.update { $0.launchAtLogin = enabled }
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                )
            )
            Text("系统状态：\(loginItemController.statusText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快捷键").font(.headline)
            Text("列表排序：⌘↑ / ⌘↓")
                .foregroundStyle(.secondary)
            HStack {
                Text(shortcutDescription)
                Spacer()
                Button(isRecordingShortcut ? "请按快捷键…" : "录入快捷键") {
                    isRecordingShortcut ? stopShortcutRecording() : startShortcutRecording()
                }
                if settings.globalShortcut != nil {
                    Button("关闭") {
                        saveShortcut(nil)
                    }
                }
            }
        }
    }

    private var dataSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("数据").font(.headline)
            HStack {
                Button("清空主列表") {
                    clearAction = .pending
                }
                Button("清空全部任务数据", role: .destructive) {
                    clearAction = .all
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.1.0"
    }

    private var shortcutDescription: String {
        guard let shortcut = settings.globalShortcut else {
            return "全局呼出快捷键：关闭"
        }
        return "全局呼出快捷键：\(shortcut.modifiers)-\(shortcut.keyCode)"
    }

    private func binding<Value>(
        get: @escaping () -> Value,
        update: @escaping (inout SettingsValues, Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: get,
            set: { value in
                do {
                    try settings.update { update(&$0, value) }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        )
    }

    private func startShortcutRecording() {
        isRecordingShortcut = true
        try? shortcutController.register(nil)
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = carbonModifiers(for: event.modifierFlags)
            guard flags != 0 else {
                return event
            }
            saveShortcut(
                ShortcutDefinition(
                    keyCode: UInt32(event.keyCode),
                    modifiers: flags
                )
            )
            stopShortcutRecording()
            return nil
        }
    }

    private func stopShortcutRecording() {
        if let shortcutMonitor {
            NSEvent.removeMonitor(shortcutMonitor)
            self.shortcutMonitor = nil
        }
        isRecordingShortcut = false
        if shortcutController.registeredShortcut == nil {
            try? shortcutController.register(settings.globalShortcut)
        }
    }

    private func saveShortcut(_ shortcut: ShortcutDefinition?) {
        let oldShortcut = settings.globalShortcut
        do {
            try shortcutController.register(shortcut)
            try settings.update { $0.globalShortcut = shortcut }
        } catch {
            try? shortcutController.register(oldShortcut)
            errorMessage = error.localizedDescription
        }
    }

    private func performClear() {
        do {
            switch clearAction {
            case .pending:
                try taskStore.clearPending()
            case .all:
                try taskStore.clearAll()
            case nil:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        clearAction = nil
    }

    private func carbonModifiers(for flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

private enum ClearAction {
    case pending
    case all

    var title: String {
        switch self {
        case .pending:
            return "清空主列表？"
        case .all:
            return "清空全部任务数据？"
        }
    }

    var message: String {
        switch self {
        case .pending:
            return "所有未完成任务将被永久删除；历史记录和设置会保留。"
        case .all:
            return "所有未完成任务和历史记录将被永久删除；设置会保留。"
        }
    }
}
