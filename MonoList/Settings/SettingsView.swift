import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItemController: LoginItemController
    @ObservedObject var updater: AppUpdater
    let onInstallUpdate: (AppUpdate) -> Void
    let onTestReminder: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            softwareInformation
            SettingsCard(title: "轻提醒", systemImage: "bell") {
                reminderSettings
            }
            SettingsCard(title: "启动", systemImage: "power") {
                startupSettings
            }
        }
        .padding(16)
        .frame(width: WindowCoordinator.settingsWindowWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.white)
        .environment(\.colorScheme, .light)
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

    private var softwareInformation: some View {
        HStack(spacing: 12) {
            MonoListLogoView(size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text("MonoList")
                    .font(.system(size: 20, weight: .semibold))
                HStack(spacing: 7) {
                    Text("版本 \(appVersion)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button(updater.isChecking ? "检测中…" : "检测新版本") {
                        Task {
                            await updater.check(manual: true, settings: settings)
                        }
                    }
                    .buttonStyle(InlineUpdateButtonStyle())
                    .disabled(updater.isChecking)

                    if !updater.statusText.isEmpty {
                        Text(updater.statusText)
                            .font(.system(size: 11))
                            .foregroundStyle(updateStatusColor)
                            .lineLimit(1)
                    }
                    if let update = updater.availableUpdate {
                        Button(updater.isInstalling ? "升级中…" : "升级") {
                            onInstallUpdate(update)
                        }
                        .buttonStyle(InlineUpdateButtonStyle())
                        .disabled(updater.isInstalling)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 52)
    }

    private var reminderSettings: some View {
        VStack(spacing: 8) {
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
            settingsRow("提醒声音") {
                Toggle(
                    "",
                    isOn: binding(
                        get: { settings.reminderSoundEnabled },
                        update: { $0.reminderSoundEnabled = $1 }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }
            Divider().opacity(0.4)
            settingsRow("提醒间隔") {
                SettingsPopupButton(
                    items: [30, 60, 90, 120].map { "\($0) 分钟" },
                    selectedTitle: "\(settings.reminderIntervalMinutes) 分钟"
                ) { title in
                    guard let interval = Int(
                        title.split(separator: " ").first ?? ""
                    ) else {
                        return
                    }
                    updateSettings {
                        $0.reminderIntervalMinutes = interval
                    }
                }
                .frame(width: 116, height: 26)
            }
            settingsRow("提醒位置") {
                SettingsPopupButton(
                    items: ReminderPosition.supportedCases.map(\.title),
                    selectedTitle: settings.reminderPosition.title
                ) { title in
                    guard let position = ReminderPosition.supportedCases.first(
                        where: { $0.title == title }
                    ) else {
                        return
                    }
                    updateSettings {
                        $0.reminderPosition = position
                    }
                }
                .frame(width: 116, height: 26)
            }
            settingsRow("提醒测试") {
                Button("立即测试", action: onTestReminder)
                    .buttonStyle(FixedQuietButtonStyle(width: 116))
            }
        }
    }

    private var startupSettings: some View {
        settingsRow("开机后自动启动") {
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

    private func settingsRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            content()
        }
        .frame(minHeight: 28)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.3.0"
    }

    private var updateStatusColor: Color {
        if updater.availableUpdate != nil {
            return .green
        }
        if updater.statusText.contains("失败") ||
            updater.statusText.contains("无法") {
            return .red
        }
        return .secondary
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

    private func updateSettings(_ mutation: (inout SettingsValues) -> Void) {
        do {
            try settings.update(mutation)
        } catch {
            errorMessage = error.localizedDescription
        }
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
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct InlineUpdateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.10 : 0.055),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }
}

private struct FixedQuietButtonStyle: ButtonStyle {
    let width: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .regular))
            .frame(width: width, height: 26)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.10 : 0.055),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }
}

private struct SettingsPopupButton: NSViewRepresentable {
    let items: [String]
    let selectedTitle: String
    let onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = .small
        button.font = .systemFont(ofSize: 12)
        button.alignment = .center
        button.bezelStyle = .rounded
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        return button
    }

    func updateNSView(
        _ button: NSPopUpButton,
        context: Context
    ) {
        context.coordinator.onSelect = onSelect
        if button.itemTitles != items {
            button.removeAllItems()
            button.addItems(withTitles: items)
        }
        button.selectItem(withTitle: selectedTitle)
    }

    final class Coordinator: NSObject {
        var onSelect: (String) -> Void

        init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }

        @objc
        func selectionChanged(_ sender: NSPopUpButton) {
            guard let title = sender.selectedItem?.title else { return }
            onSelect(title)
        }
    }
}
