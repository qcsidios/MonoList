import Foundation

enum TestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message):
            return message
        }
    }
}

struct AlwaysFailWriter: AtomicWriting {
    func write(_ data: Data, to destinationURL: URL) throws {
        throw CocoaError(.fileWriteNoPermission)
    }
}

@main
struct TaskStoreSmoke {
    @MainActor
    static func main() throws {
        try testAddCompleteRestoreAndReload()
        try testStableHistoryOrder()
        try testDeleteAndClearScopes()
        try testWriteFailureKeepsCommittedState()
        try testUnknownSchemaDoesNotOverwriteFile()
        try testDamagedFileDoesNotGetOverwritten()
        print("Task store smoke passed.")
    }

    @MainActor
    private static func testAddCompleteRestoreAndReload() throws {
        let fixture = try Fixture()
        let store = TaskStore(fileURL: fixture.fileURL)
        let first = try store.add(text: "第一条")
        let second = try store.add(text: "第二条", after: first.id)
        let third = try store.add(text: "第三条")

        try require(store.pendingTasks.map(\.text) == ["第一条", "第二条", "第三条"],
                    "新增位置不正确")

        let completionDate = Date(timeIntervalSince1970: 100)
        try store.complete(id: second.id, at: completionDate)
        try require(store.pendingTasks.map(\.text) == ["第一条", "第三条"],
                    "完成任务后主列表不正确")
        try require(store.historyTasks.map(\.text) == ["第二条"],
                    "完成任务没有进入历史记录")

        try store.restore(id: second.id, at: Date(timeIntervalSince1970: 200))
        try require(store.pendingTasks.map(\.id) == [first.id, third.id, second.id],
                    "恢复任务没有加入主列表底部")

        let reloaded = TaskStore(fileURL: fixture.fileURL)
        try require(reloaded.pendingTasks.map(\.id) == [first.id, third.id, second.id],
                    "重启后任务顺序没有保持")
    }

    @MainActor
    private static func testStableHistoryOrder() throws {
        let fixture = try Fixture()
        let store = TaskStore(fileURL: fixture.fileURL)
        let ids = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        ]

        for (index, id) in ids.enumerated() {
            _ = try store.add(
                text: "任务\(index)",
                id: id,
                createdAt: Date(timeIntervalSince1970: Double(index))
            )
            try store.complete(id: id, at: Date(timeIntervalSince1970: 300))
        }

        try require(store.historyTasks.map(\.id) == [ids[1], ids[0]],
                    "相同完成时间没有按稳定任务 ID 升序排列")
    }

    @MainActor
    private static func testDeleteAndClearScopes() throws {
        let fixture = try Fixture()
        let store = TaskStore(fileURL: fixture.fileURL)
        let pending = try store.add(text: "未完成")
        let history = try store.add(text: "已完成")
        try store.complete(id: history.id)
        try store.delete(id: pending.id)
        try require(store.pendingTasks.isEmpty, "单条删除失败")
        try require(store.historyTasks.count == 1, "单条删除影响了历史记录")

        _ = try store.add(text: "保留前清空")
        try store.clearPending()
        try require(store.pendingTasks.isEmpty && store.historyTasks.count == 1,
                    "清空主列表范围不正确")

        try store.clearHistory()
        try require(store.historyTasks.isEmpty, "清空历史记录失败")

        _ = try store.add(text: "全部清空")
        try store.clearAll()
        try require(store.pendingTasks.isEmpty && store.historyTasks.isEmpty,
                    "清空全部任务失败")
    }

    @MainActor
    private static func testWriteFailureKeepsCommittedState() throws {
        let fixture = try Fixture()
        let seedStore = TaskStore(fileURL: fixture.fileURL)
        _ = try seedStore.add(text: "已提交")
        let oldData = try Data(contentsOf: fixture.fileURL)

        let failingStore = TaskStore(fileURL: fixture.fileURL, writer: AlwaysFailWriter())
        do {
            _ = try failingStore.add(text: "不能保存")
            throw TestFailure.failed("写入失败时操作不应成功")
        } catch is CocoaError {
            // 预期失败。
        }

        try require(failingStore.pendingTasks.map(\.text) == ["已提交"],
                    "写入失败后界面状态没有恢复")
        try require(failingStore.isWritePaused, "写入失败后没有暂停修改")
        try require(try Data(contentsOf: fixture.fileURL) == oldData,
                    "写入失败覆盖了原文件")
    }

    @MainActor
    private static func testUnknownSchemaDoesNotOverwriteFile() throws {
        let fixture = try Fixture()
        let original = Data(#"{"schemaVersion":99,"tasks":[]}"#.utf8)
        try original.write(to: fixture.fileURL)

        let store = TaskStore(fileURL: fixture.fileURL)
        try require(store.loadError != nil, "未知 schemaVersion 没有进入恢复状态")
        try require(try Data(contentsOf: fixture.fileURL) == original,
                    "未知 schemaVersion 文件被覆盖")

        do {
            _ = try store.add(text: "禁止写入")
            throw TestFailure.failed("恢复状态下不应允许修改")
        } catch is TaskStoreError {
            // 预期失败。
        }
    }

    @MainActor
    private static func testDamagedFileDoesNotGetOverwritten() throws {
        let fixture = try Fixture()
        let original = Data("不是有效的 JSON".utf8)
        try original.write(to: fixture.fileURL)

        let store = TaskStore(fileURL: fixture.fileURL)
        try require(store.loadError != nil, "损坏文件没有进入恢复状态")
        try require(try Data(contentsOf: fixture.fileURL) == original,
                    "损坏文件被覆盖")
    }

    private static func require(_ condition: @autoclosure () throws -> Bool,
                                _ message: String) throws {
        guard try condition() else {
            throw TestFailure.failed(message)
        }
    }
}

private struct Fixture {
    let directoryURL: URL
    let fileURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonoListTaskStoreTests-\(UUID().uuidString)")
        fileURL = directoryURL.appendingPathComponent("tasks.json")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }
}
