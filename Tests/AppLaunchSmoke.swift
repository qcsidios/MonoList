import Foundation

enum SmokeFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message):
            return message
        }
    }
}

@main
struct AppLaunchSmoke {
    static func main() throws {
        let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let contentsURL = appURL.appendingPathComponent("Contents")
        let executableURL = contentsURL.appendingPathComponent("MacOS/MonoList")
        let plistURL = contentsURL.appendingPathComponent("Info.plist")

        try requireDirectory(appURL, message: "MonoList.app 不存在")
        try requireExecutable(executableURL)

        let data = try Data(contentsOf: plistURL)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let plist = object as? [String: Any] else {
            throw SmokeFailure.failed("Info.plist 格式无效")
        }

        try require(plist["CFBundleIdentifier"] as? String == "com.qingcheng.monolist.mac",
                    "Bundle ID 不正确")
        try require(plist["CFBundleExecutable"] as? String == "MonoList",
                    "可执行文件名称不正确")
        try require(plist["CFBundleIconFile"] as? String == "AppIcon.icns",
                    "应用图标配置不正确")
        try require(
            FileManager.default.fileExists(
                atPath: contentsURL.appendingPathComponent("Resources/AppIcon.icns").path
            ),
            "构建产物缺少 AppIcon.icns"
        )
        try require(plist["LSUIElement"] as? Bool != true,
                    "应用必须显示在 Dock，LSUIElement 不能为 true")
        try require(plist["LSMinimumSystemVersion"] as? String == "14.0",
                    "最低系统版本必须为 macOS 14.0")

        print("App launch smoke passed.")
    }

    private static func requireDirectory(_ url: URL, message: String) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        try require(exists && isDirectory.boolValue, message)
    }

    private static func requireExecutable(_ url: URL) throws {
        try require(FileManager.default.isExecutableFile(atPath: url.path),
                    "MonoList 可执行文件不存在或不可执行")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw SmokeFailure.failed(message)
        }
    }
}
