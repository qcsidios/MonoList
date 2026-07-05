import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItemController: LoginItemController
    @ObservedObject var shortcutController: GlobalShortcutController
    @ObservedObject var updater: AppUpdater
    let onInstallUpdate: (AppUpdate) -> Void

    @State private var errorMessage: String?
    @State private var shortcutMonitor: Any?
    @State private var isRecordingShortcut = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            softwareInformation
            SettingsCard(title: "轻提醒", systemImage: "bell") {
                reminderSettings
            }
            SettingsCard(title: "开机启动", systemImage: "power") {
                startupSettings
            }
            SettingsCard(title: "全局快捷键", systemImage: "keyboard") {
                shortcutSettings
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(width: 480, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
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
        .onDisappear {
            stopShortcutRecording()
        }
    }

    private var softwareInformation: some View {
        HStack(spacing: 14) {
            MonoListLogoView(size: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text("MonoList 一栏")
                    .font(.system(size: 24, weight: .semibold))
                HStack(spacing: 9) {
                    Text("版本 \(appVersion)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Button(updater.isChecking ? "正在检测…" : "检测新版本") {
                        Task {
                            await updater.check(manual: true, settings: settings)
                        }
                    }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(updater.isChecking)
                    if let update = updater.availableUpdate {
                        Button("升级到 \(update.version)") {
                            onInstallUpdate(update)
                        }
                        .buttonStyle(QuietButtonStyle())
                    }
                }
                if !updater.statusText.isEmpty {
                    Text(updater.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .frame(minHeight: 64)
    }

    private var reminderSettings: some View {
        VStack(spacing: 10) {
            settingsRow("启用轻提醒") {
                Toggle(
                    "",
                    isOn: binding(
                        get: { settings.reminderEnabled },
                        update: { $0.reminderEnabled = $1 }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }
            Divider().opacity(0.5)
            settingsRow("提醒间隔") {
                Picker(
                    "",
                    selection: binding(
                        get: { settings.reminderIntervalMinutes },
                        update: { $0.reminderIntervalMinutes = $1 }
                    )
                ) {
                    ForEach([30, 60, 90, 120], id: \.self) {
                        Text("\($0) 分钟").tag($0)
                    }
                }
                .labelsHidden()
                .frame(width: 116)
            }
            settingsRow("提醒位置") {
                Picker(
                    "",
                    selection: binding(
                        get: { settings.reminderPosition },
                        update: { $0.reminderPosition = $1 }
                    )
                ) {
                    ForEach(ReminderPosition.allCases) {
                        Text($0.title).tag($0)
                    }
                }
                .labelsHidden()
                .frame(width: 116)
            }
        }
    }

    private var startupSettings: some View {
        settingsRow("登录后自动启动") {
            Toggle(
                "",
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
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }

    private var shortcutSettings: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(shortcutDescription)
                    .foregroundStyle(settings.globalShortcut == nil ? .secondary : .primary)
                Text("用于随时打开或关闭待办窗口")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button(isRecordingShortcut ? "请按快捷键…" : "录入快捷键") {
                isRecordingShortcut ? stopShortcutRecording() : startShortcutRecording()
            }
            .buttonStyle(QuietButtonStyle())
            if settings.globalShortcut != nil {
                Button("清除") {
                    saveShortcut(nil)
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private func settingsRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            content()
        }
        .frame(minHeight: 26)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.2.0"
    }

    private var shortcutDescription: String {
        guard let shortcut = settings.globalShortcut else {
            return "未设置"
        }
        return "\(modifierText(shortcut.modifiers))\(keyText(shortcut.keyCode))"
    }

    private func modifierText(_ modifiers: UInt32) -> String {
        var value = ""
        if modifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        return value
    }

    private func keyText(_ keyCode: UInt32) -> String {
        let keys: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
            6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
            12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            25: "9", 26: "7", 28: "8", 29: "0",
            31: "O", 32: "U", 34: "I", 35: "P",
            37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            36: "↩", 49: "Space", 51: "⌫",
        ]
        return keys[keyCode] ?? "Key \(keyCode)"
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
            guard flags != 0 else { return event }
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

    private func carbonModifiers(for flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.11 : 0.055),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
    }
}
