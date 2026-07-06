import Foundation

@main
struct AppUpdaterSmoke {
    @MainActor
    static func main() async throws {
        precondition(AppUpdater.compareVersions("v1.2.0", "1.1.9") == .orderedDescending)
        precondition(AppUpdater.compareVersions("v1.0.0", "1.0.0") == .orderedSame)
        precondition(AppUpdater.isValidVersionTag("v0.1.0"))
        precondition(!AppUpdater.isValidVersionTag("1.0"))
        precondition(!AppUpdater.isValidVersionTag("v1.0.0-beta"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReleaseURLProtocol.self]
        let session = URLSession(configuration: configuration)
        ReleaseURLProtocol.requestedHosts = []
        let networkUpdater = AppUpdater(
            currentVersion: "0.4.7",
            session: session
        )
        let networkResult = await networkUpdater.checkForUpdate()
        guard case let .available(networkUpdate) = networkResult else {
            preconditionFailure("Release 页面没有返回升级")
        }
        precondition(networkUpdate.version == "v0.4.8")
        precondition(!ReleaseURLProtocol.requestedHosts.contains("api.github.com"))
        let fallbackResult = AppUpdater.parseLatestReleaseURL(
            URL(string: "https://github.com/qcsidios/MonoList/releases/tag/v0.4.6")!,
            currentVersion: "0.4.5"
        )
        guard case let .available(fallbackUpdate) = fallbackResult else {
            preconditionFailure("GitHub Release 跳转没有返回升级")
        }
        precondition(fallbackUpdate.version == "v0.4.6")
        precondition(
            fallbackUpdate.dmgURL.absoluteString ==
                "https://github.com/qcsidios/MonoList/releases/download/v0.4.6/MonoList-v0.4.6.dmg"
        )

        precondition(AppUpdater.shouldAutomaticallyCheck(lastCheckedAt: nil))
        precondition(!AppUpdater.shouldAutomaticallyCheck(
            lastCheckedAt: Date(),
            now: Date()
        ))
        let updater = AppUpdater(currentVersion: "0.4.3")
        updater.beginInstallation()
        precondition(updater.isInstalling)
        precondition(updater.statusText == "下载并安装中…")
        updater.installationFailed()
        precondition(!updater.isInstalling)
        precondition(updater.statusText == "升级失败")
        print("App updater smoke passed.")
    }
}

private final class ReleaseURLProtocol: URLProtocol {
    static var requestedHosts: [String] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.requestedHosts.append(url.host ?? "")

        let response: HTTPURLResponse
        if url.path.hasSuffix("/releases/latest") {
            response = HTTPURLResponse(
                url: url,
                statusCode: 302,
                httpVersion: nil,
                headerFields: [
                    "Location": "https://github.com/qcsidios/MonoList/releases/tag/v0.4.8"
                ]
            )!
        } else {
            response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        }
        if let location = response.value(forHTTPHeaderField: "Location"),
           let redirectURL = URL(string: location) {
            client?.urlProtocol(
                self,
                wasRedirectedTo: URLRequest(url: redirectURL),
                redirectResponse: response
            )
        } else {
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
