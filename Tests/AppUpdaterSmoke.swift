import Foundation

@main
struct AppUpdaterSmoke {
    @MainActor
    static func main() throws {
        precondition(AppUpdater.compareVersions("v1.2.0", "1.1.9") == .orderedDescending)
        precondition(AppUpdater.compareVersions("v1.0.0", "1.0.0") == .orderedSame)
        precondition(AppUpdater.isValidVersionTag("v0.1.0"))
        precondition(!AppUpdater.isValidVersionTag("1.0"))
        precondition(!AppUpdater.isValidVersionTag("v1.0.0-beta"))

        let validJSON = """
        {
          "tag_name": "v0.2.0",
          "draft": false,
          "prerelease": false,
          "assets": [
            {
              "name": "MonoList-v0.2.0.dmg",
              "browser_download_url": "https://github.com/qcsidios/MonoList/releases/download/v0.2.0/MonoList-v0.2.0.dmg"
            }
          ]
        }
        """.data(using: .utf8)!
        let result = AppUpdater.parseRelease(validJSON, currentVersion: "0.1.0")
        guard case let .available(update) = result else {
            preconditionFailure("有效 Release 没有返回升级")
        }
        precondition(update.version == "v0.2.0")

        let duplicateJSON = String(data: validJSON, encoding: .utf8)!
            .replacingOccurrences(
                of: "]",
                with: ",{\"name\":\"MonoList-v0.2.0.dmg\",\"browser_download_url\":\"https://example.com/duplicate.dmg\"}]"
            )
            .data(using: .utf8)!
        guard case .failed = AppUpdater.parseRelease(
            duplicateJSON,
            currentVersion: "0.1.0"
        ) else {
            preconditionFailure("重复 DMG 不应进入升级")
        }

        precondition(AppUpdater.shouldAutomaticallyCheck(lastCheckedAt: nil))
        precondition(!AppUpdater.shouldAutomaticallyCheck(
            lastCheckedAt: Date(),
            now: Date()
        ))
        print("App updater smoke passed.")
    }
}
