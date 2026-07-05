import Foundation

enum AppError: LocalizedError {
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "保存失败，请重试"
        }
    }
}
