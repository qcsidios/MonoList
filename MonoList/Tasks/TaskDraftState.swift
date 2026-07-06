import Combine
import Foundation

@MainActor
final class TaskDraftState: ObservableObject {
    @Published var text = ""
    @Published var afterID: UUID?
    @Published private(set) var isPresented = true

    @discardableResult
    func submit(to store: TaskStore) throws -> TaskItem? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let item = try store.add(text: text, after: afterID)
        text = ""
        afterID = nil
        isPresented = false
        return item
    }

    func present(after id: UUID?) {
        afterID = id
        isPresented = true
    }

    func syncVisibility(hasPendingTasks: Bool) {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isPresented = true
        } else {
            isPresented = !hasPendingTasks
        }
    }

    func dismissIfEmpty() {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        afterID = nil
        isPresented = false
    }
}
