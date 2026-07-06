import Combine
import Foundation

struct AppUpdate: Equatable {
    let version: String
    let dmgURL: URL
}

enum AppUpdateCheckResult: Equatable {
    case available(AppUpdate)
    case upToDate
    case failed(String)
}

@MainActor
final class AppUpdater: ObservableObject {
    static let repository = "qcsidios/MonoList"
    static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/\(repository)/releases/latest"
    )!
    static let latestReleasePageURL = URL(
        string: "https://github.com/\(repository)/releases/latest"
    )!
    static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    @Published private(set) var statusText = ""
    @Published private(set) var availableUpdate: AppUpdate?
    @Published private(set) var isChecking = false
    @Published private(set) var isInstalling = false

    let currentVersion: String
    private let session: URLSession

    init(
        currentVersion: String? = nil,
        session: URLSession = .shared
    ) {
        self.currentVersion = currentVersion ?? Self.bundleShortVersion
        self.session = session
    }

    func check(manual: Bool, settings: AppSettings) async {
        guard !isChecking else {
            return
        }
        if !manual {
            guard Self.shouldAutomaticallyCheck(
                lastCheckedAt: settings.lastAutomaticUpdateCheckAt
            ) else {
                return
            }
            try? settings.update { $0.lastAutomaticUpdateCheckAt = Date() }
        }

        isChecking = true
        if manual {
            statusText = "检查中…"
        }
        defer { isChecking = false }

        let result = await checkForUpdate()
        switch result {
        case let .available(update):
            availableUpdate = update
            statusText = "发现新版本 \(update.version)"
        case .upToDate:
            availableUpdate = nil
            if manual {
                statusText = "已是最新版"
            }
        case let .failed(message):
            if manual {
                statusText = message
            }
        }
    }

    func checkForUpdate() async -> AppUpdateCheckResult {
        let apiResult = await checkGitHubAPI()
        guard case .failed = apiResult else {
            return apiResult
        }
        return await checkLatestReleasePage()
    }

    private func checkGitHubAPI() async -> AppUpdateCheckResult {
        do {
            var request = URLRequest(url: Self.latestReleaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("MonoList", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 12

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  http.url?.scheme == "https" else {
                return .failed("检测新版本失败")
            }
            return Self.parseRelease(data, currentVersion: currentVersion)
        } catch {
            return .failed("检测新版本失败")
        }
    }

    private func checkLatestReleasePage() async -> AppUpdateCheckResult {
        do {
            var request = URLRequest(url: Self.latestReleasePageURL)
            request.setValue("MonoList", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 12
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let responseURL = http.url else {
                return .failed("检测新版本失败")
            }
            let result = Self.parseLatestReleaseURL(
                responseURL,
                currentVersion: currentVersion
            )
            guard case let .available(update) = result else {
                return result
            }

            var assetRequest = URLRequest(url: update.dmgURL)
            assetRequest.httpMethod = "HEAD"
            assetRequest.setValue("MonoList", forHTTPHeaderField: "User-Agent")
            assetRequest.timeoutInterval = 12
            let (_, assetResponse) = try await session.data(for: assetRequest)
            guard let assetHTTP = assetResponse as? HTTPURLResponse,
                  (200..<300).contains(assetHTTP.statusCode),
                  assetHTTP.url?.scheme == "https" else {
                return .failed("更新包无效")
            }
            return result
        } catch {
            return .failed("检测新版本失败")
        }
    }

    func beginInstallation() {
        isInstalling = true
        statusText = "下载并安装中…"
    }

    func installationFailed() {
        isInstalling = false
        statusText = "升级失败"
    }

    static func parseRelease(
        _ data: Data,
        currentVersion: String
    ) -> AppUpdateCheckResult {
        do {
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard !release.draft, !release.prerelease else {
                return .failed("检测新版本失败")
            }
            guard isValidVersionTag(release.tagName) else {
                return .failed("版本号无效")
            }
            guard compareVersions(release.tagName, currentVersion) == .orderedDescending else {
                return .upToDate
            }

            let expectedName = "MonoList-\(release.tagName).dmg"
            let matchingAssets = release.assets.filter { $0.name == expectedName }
            guard matchingAssets.count == 1,
                  let asset = matchingAssets.first,
                  asset.browserDownloadURL.scheme == "https" else {
                return .failed("更新包无效")
            }
            return .available(
                AppUpdate(version: release.tagName, dmgURL: asset.browserDownloadURL)
            )
        } catch {
            return .failed("检测新版本失败")
        }
    }

    static func parseLatestReleaseURL(
        _ url: URL,
        currentVersion: String
    ) -> AppUpdateCheckResult {
        guard url.scheme == "https",
              url.host == "github.com",
              url.pathComponents.count >= 6,
              url.pathComponents.suffix(3).dropLast() == ["releases", "tag"] else {
            return .failed("检测新版本失败")
        }
        let tag = url.lastPathComponent
        guard isValidVersionTag(tag) else {
            return .failed("版本号无效")
        }
        guard compareVersions(tag, currentVersion) == .orderedDescending else {
            return .upToDate
        }
        guard let dmgURL = URL(
            string: "https://github.com/\(repository)/releases/download/\(tag)/MonoList-\(tag).dmg"
        ) else {
            return .failed("更新包无效")
        }
        return .available(AppUpdate(version: tag, dmgURL: dmgURL))
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        guard let left = versionParts(lhs), let right = versionParts(rhs) else {
            return .orderedSame
        }
        for index in 0..<3 {
            if left[index] < right[index] { return .orderedAscending }
            if left[index] > right[index] { return .orderedDescending }
        }
        return .orderedSame
    }

    static func isValidVersionTag(_ tag: String) -> Bool {
        tag.hasPrefix("v") && versionParts(tag) != nil
    }

    static func shouldAutomaticallyCheck(
        lastCheckedAt: Date?,
        now: Date = Date()
    ) -> Bool {
        guard let lastCheckedAt else {
            return true
        }
        return now.timeIntervalSince(lastCheckedAt) >= automaticCheckInterval
    }

    private static func versionParts(_ version: String) -> [Int]? {
        let normalized = version.hasPrefix("v") ? String(version.dropFirst()) : version
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else {
            return nil
        }
        return parts.compactMap { Int($0) }
    }

    private static var bundleShortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.0.0"
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let draft: Bool
        let prerelease: Bool
        let assets: [GitHubAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case draft
            case prerelease
            case assets
        }
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}
