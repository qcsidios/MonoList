import SwiftUI

struct DataRecoveryView: View {
    let message: String
    let onRetry: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text("无法读取任务数据")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("退出", action: onQuit)
                Button("重试", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
    }
}
