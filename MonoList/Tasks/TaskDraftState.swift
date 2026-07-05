import Combine
import Foundation

@MainActor
final class TaskDraftState: ObservableObject {
    @Published var text = ""
    @Published var afterID: UUID?

    @discardableResult
    func submit(to store: TaskStore) throws -> TaskItem? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let item = try store.add(text: text, after: afterID)
        text = ""
        afterID = nil
        return item
    }

    func move(after id: UUID?) {
        afterID = id
    }
}
