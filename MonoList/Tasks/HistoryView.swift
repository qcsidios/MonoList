import SwiftUI

struct HistoryView: View {
    let tasks: [TaskItem]
    let onBack: () -> Void
    let onRestore: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onClear: () -> Void

    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Label("返回", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                Text("历史记录")
                    .font(.headline)
                Spacer()
                Button("清空") {
                    showClearConfirmation = true
                }
                .buttonStyle(.plain)
                .disabled(tasks.isEmpty)
            }
            .padding(14)

            Divider()

            if tasks.isEmpty {
                Spacer()
                Text("暂无历史记录")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(tasks) { item in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.text)
                                        .lineLimit(2)
                                    Text(item.completedAt ?? .now, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("恢复") {
                                    onRestore(item.id)
                                }
                                .buttonStyle(.plain)
                                Button {
                                    onDelete(item.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "清空历史记录？",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除全部历史记录", role: .destructive, action: onClear)
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有已完成任务将被永久删除，且无法撤销。")
        }
    }
}
