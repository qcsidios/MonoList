import SwiftUI

@MainActor
final class ReminderPresentationModel: ObservableObject {
    @Published var remainingSeconds = 3
    @Published var isExpanded = false
    var isPaused = false
}

struct ReminderView: View {
    let totalCount: Int
    let taskTexts: [String]
    @ObservedObject var model: ReminderPresentationModel
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)
                .opacity(model.isExpanded ? 0 : 1)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("待办提醒")
                        .font(.headline)
                    Spacer()
                    Text("\(totalCount) 项")
                        .foregroundStyle(.secondary)
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(taskTexts.enumerated()), id: \.offset) { _, text in
                            HStack(alignment: .top, spacing: 7) {
                                Circle()
                                    .fill(.secondary)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 7)
                                Text(text)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text("\(model.remainingSeconds) 秒后收回")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .opacity(model.isExpanded ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: model.isExpanded ? 14 : 18)
        )
        .animation(.easeInOut(duration: 0.18), value: model.isExpanded)
        .onHover { model.isPaused = $0 }
    }
}
