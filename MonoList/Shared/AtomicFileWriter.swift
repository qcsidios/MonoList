import Darwin
import Foundation

protocol AtomicWriting {
    func write(_ data: Data, to destinationURL: URL) throws
}

struct AtomicFileWriter: AtomicWriting {
    func write(_ data: Data, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let directoryURL = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let temporaryURL = directoryURL.appendingPathComponent(
            ".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp"
        )

        do {
            try data.write(to: temporaryURL)
            guard Darwin.rename(temporaryURL.path, destinationURL.path) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }
}
