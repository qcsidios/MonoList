import Combine
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var errorMessage: String?

    var statusText: String {
        switch status {
        case .enabled:
            return "已启用"
        case .requiresApproval:
            return "需用户批准"
        case .notRegistered:
            return "关闭"
        case .notFound:
            return "注册失败"
        @unknown default:
            return "未知状态"
        }
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
            errorMessage = nil
        } catch {
            refresh()
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
