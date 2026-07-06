import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var reminderScheduler: ReminderScheduler
    @ObservedObject var loginItemController: LoginItemController
    @ObservedObject var updater: AppUpdater
    let onInstallUpdate: (AppUpdate) -> Void
    let onTestReminder: () -> Void

    @State private var errorMessage: String?
    @State private var currentDate = Date()

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
        .onReceive(
            Timer.publish(every: 60, on: .main, in: .common).autoconnect()
        ) { date in
            currentDate = date
        }
    }

    private var softwareInformation: some View {
        HStack(alignment: .top, spacing: 14) {
            MonoListLogoView(size: 58)
            VStack(alignment: .leading, spacing: 0) {
                Text("MonoList")
                    .font(.system(size: 28, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 7) {
                    Text("版本 \(appVersion)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(height: 24)
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
            .frame(height: 58)
            Spacer(minLength: 0)
        }
        .frame(height: 58)
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
            settingsRow("提醒时段") {
                HStack(spacing: 6) {
                    SettingsPopupButton(
                        items: Self.startTimeItems.map(Self.timeTitle),
                        selectedTitle: Self.timeTitle(
                            settings.reminderStartMinuteOfDay
                        )
                    ) { title in
                        guard let minute = Self.minuteOfDay(for: title) else {
                            return
                        }
                        updateSettings {
                            $0.reminderStartMinuteOfDay = minute
                        }
                    }
                    .frame(width: 78, height: 26)
                    Text("至")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    SettingsPopupButton(
                        items: Self.endTimeItems.map(Self.timeTitle),
                        selectedTitle: Self.timeTitle(
                            settings.reminderEndMinuteOfDay
                        )
                    ) { title in
                        guard let minute = Self.minuteOfDay(for: title) else {
                            return
                        }
                        updateSettings {
                            $0.reminderEndMinuteOfDay = minute
                        }
                    }
                    .frame(width: 78, height: 26)
                }
            }
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
                .frame(width: 180, height: 26)
            }
            settingsRow("下次提醒") {
                Text(nextReminderText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(nextReminderColor)
                    .lineLimit(1)
                    .frame(width: 180, height: 26, alignment: .center)
                    .modifier(SettingValueBackground())
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
                .frame(width: 180, height: 26)
            }
            settingsRow("提醒测试") {
                Button("立即测试", action: onTestReminder)
                    .buttonStyle(FixedQuietButtonStyle(width: 180))
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
                .font(.system(size: 14, weight: .medium))
            Spacer(minLength: 16)
            content()
                .frame(width: 180, alignment: .trailing)
        }
        .frame(minHeight: 34)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.3.0"
    }

    private var nextReminderText: String {
        guard settings.reminderEnabled else { return "未启用" }
        guard !taskStore.pendingTasks.isEmpty else { return "暂无待办" }
        guard let date = reminderScheduler.nextReminderDate else {
            return "等待调度"
        }
        return Self.nextReminderTitle(for: date, relativeTo: currentDate)
    }

    private var nextReminderColor: Color {
        if settings.reminderEnabled && !taskStore.pendingTasks.isEmpty {
            return .primary
        }
        return .secondary
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

    static let startTimeItems = stride(from: 0, to: 24 * 60, by: 30).map { $0 }
    static let endTimeItems = stride(from: 30, through: 24 * 60, by: 30).map { $0 }

    static func timeTitle(_ minuteOfDay: Int) -> String {
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    static func minuteOfDay(for title: String) -> Int? {
        let parts = title.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return hour * 60 + minute
    }

    static func nextReminderTitle(
        for date: Date,
        relativeTo referenceDate: Date,
        calendar: Calendar = .current
    ) -> String {
        let time = date.formatted(
            .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        )
        if calendar.isDate(date, inSameDayAs: referenceDate) {
            return "今天 \(time)"
        }
        if let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: referenceDate)
        ), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "明天 \(time)"
        }
        let day = date.formatted(.dateTime.month().day())
        return "\(day) \(time)"
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct InlineUpdateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .frame(height: 24)
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
            .modifier(SettingValueBackground(isPressed: configuration.isPressed))
    }
}

private struct SettingsPopupButton: View {
    let items: [String]
    let selectedTitle: String
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(items, id: \.self) { item in
                Button(item) {
                    onSelect(item)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedTitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .frame(height: 26)
            .modifier(SettingValueBackground())
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

private struct SettingValueBackground: ViewModifier {
    var isPressed = false

    func body(content: Content) -> some View {
        content
            .background(
                Color.primary.opacity(isPressed ? 0.10 : 0.045),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
            )
    }
}
