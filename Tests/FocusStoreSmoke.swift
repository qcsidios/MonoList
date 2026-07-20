import Foundation

enum FocusSmokeFailure: Error {
    case failed(String)
}

struct FocusFailWriter: AtomicWriting {
    func write(_ data: Data, to destinationURL: URL) throws {
        throw CocoaError(.fileWriteNoPermission)
    }
}

@main
struct FocusStoreSmoke {
    @MainActor
    static func main() throws {
        let fixture = try FocusFixture()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let beforeBoundary = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 20, hour: 3, minute: 59)
        )!
        let afterBoundary = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 20, hour: 4)
        )!
        try require(
            FocusStore.dayKey(for: beforeBoundary, calendar: calendar) == "2026-07-19",
            "凌晨四点前应属于前一天"
        )
        try require(
            FocusStore.dayKey(for: afterBoundary, calendar: calendar) == "2026-07-20",
            "凌晨四点应切换到新一天"
        )

        let ids = [UUID(), UUID(), UUID(), UUID()]
        let store = FocusStore(fileURL: fixture.fileURL, calendar: calendar)
        try store.setSelection(
            Array(ids.prefix(3)),
            existingTaskIDs: Set(ids),
            completedTaskIDs: [],
            at: afterBoundary
        )
        try require(store.taskIDs(at: afterBoundary) == Array(ids.prefix(3)),
                    "今日专注顺序没有保存")

        let reloaded = FocusStore(fileURL: fixture.fileURL, calendar: calendar)
        try require(reloaded.taskIDs(at: afterBoundary) == Array(ids.prefix(3)),
                    "重启后今日专注没有恢复")

        do {
            try reloaded.setSelection(
                [ids[1], ids[2], ids[3]],
                existingTaskIDs: Set(ids),
                completedTaskIDs: [ids[0]],
                at: afterBoundary
            )
            throw FocusSmokeFailure.failed("已完成专注任务不应允许移出")
        } catch FocusStoreError.completedTaskLocked {
            // 预期失败。
        }

        try reloaded.setSelection(
            [ids[0], ids[2]],
            existingTaskIDs: Set(ids),
            completedTaskIDs: [ids[0]],
            at: afterBoundary
        )
        try require(reloaded.taskIDs(at: afterBoundary) == [ids[0], ids[2]],
                    "保留完成项的调整没有生效")

        let nextDay = calendar.date(byAdding: .day, value: 1, to: afterBoundary)!
        try require(!reloaded.isActive(at: nextDay), "跨日后不应自动沿用昨日专注")
        try require(reloaded.suggestedTaskIDs(at: nextDay) == [ids[0], ids[2]],
                    "跨日后没有保留昨日候选")

        reloaded.reconcile(existingTaskIDs: [ids[2]])
        try require(reloaded.suggestedTaskIDs(at: nextDay) == [ids[2]],
                    "已删除任务没有从昨日候选中清理")

        let damagedURL = fixture.directoryURL.appendingPathComponent("damaged.json")
        try Data("not-json".utf8).write(to: damagedURL)
        let damaged = FocusStore(fileURL: damagedURL, calendar: calendar)
        try require(damaged.selection == nil && damaged.loadError != nil,
                    "损坏专注记录应被隔离")

        let failing = FocusStore(
            fileURL: fixture.directoryURL.appendingPathComponent("failure.json"),
            writer: FocusFailWriter(),
            calendar: calendar
        )
        do {
            try failing.setSelection(
                [ids[0]],
                existingTaskIDs: Set(ids),
                completedTaskIDs: [],
                at: afterBoundary
            )
            throw FocusSmokeFailure.failed("写入失败不应更新内存状态")
        } catch is CocoaError {
            // 预期失败。
        }
        try require(failing.selection == nil && failing.isWritePaused,
                    "写入失败后状态没有保持可信")

        print("Focus store smoke passed.")
    }

    private static func require(_ condition: @autoclosure () -> Bool,
                                _ message: String) throws {
        guard condition() else { throw FocusSmokeFailure.failed(message) }
    }
}

private struct FocusFixture {
    let directoryURL: URL
    let fileURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonoListFocusStoreTests-\(UUID().uuidString)")
        fileURL = directoryURL.appendingPathComponent("focus.json")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }
}
