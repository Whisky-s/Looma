import CryptoKit
import Foundation

struct OperationPath: Codable {
    let path: String
    let beforeDigest: String?
    let afterDigest: String?
}

struct OperationHistoryEntry: Identifiable, Codable {
    let id: String
    let action: String
    let kind: String
    let target: String
    let createdAt: Date
    var status: String
    let paths: [OperationPath]

    var canRollback: Bool {
        status != "已回滚" && paths.contains { $0.beforeDigest != $0.afterDigest }
    }
}

extension ManagerStore {
    var historyRoot: URL { base.appendingPathComponent("history", isDirectory: true) }
    private var historyLimitURL: URL { base.appendingPathComponent("history-limit.json") }

    var historyLimit: Int {
        guard let data = try? Data(contentsOf: historyLimitURL),
              let value = try? JSONDecoder().decode(Int.self, from: data),
              [20, 50, 100].contains(value) else { return 50 }
        return value
    }

    func setHistoryLimit(_ value: Int) throws {
        guard [20, 50, 100].contains(value) else { throw ManagerError.invalid("仅支持保留 20、50 或 100 条记录") }
        try JSONEncoder().encode(value).write(to: historyLimitURL, options: .atomic)
        try pruneHistory()
    }

    func operationHistory() -> [OperationHistoryEntry] {
        let dirs = (try? fm.contentsOfDirectory(at: historyRoot, includingPropertiesForKeys: nil)) ?? []
        return dirs.compactMap { try? Data(contentsOf: $0.appendingPathComponent("entry.json")) }
            .compactMap { try? JSONDecoder().decode(OperationHistoryEntry.self, from: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func withRecordedOperation<T>(action: String, kind: String, target: String, paths: [URL], _ body: () throws -> T) throws -> T {
        historyLock.lock()
        defer { historyLock.unlock() }
        let uniquePaths = Array(Set(paths.map { $0.standardizedFileURL.path })).sorted()
        guard !uniquePaths.isEmpty else { throw ManagerError.invalid("缺少操作路径") }
        let id = UUID().uuidString
        let dir = historyRoot.appendingPathComponent(id, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: historyRoot.path)
        do {
            let before = try uniquePaths.enumerated().map { index, path in
                try snapshot(URL(fileURLWithPath: path), at: dir.appendingPathComponent("before/\(index)"))
            }
            do {
                let result = try body()
                let after = try uniquePaths.enumerated().map { index, path in
                    try snapshot(URL(fileURLWithPath: path), at: dir.appendingPathComponent("after/\(index)"))
                }
                let states = zip(uniquePaths, zip(before, after)).map { path, pair in
                    OperationPath(path: path, beforeDigest: pair.0, afterDigest: pair.1)
                }
                try saveHistoryEntry(OperationHistoryEntry(id: id, action: action, kind: kind, target: target, createdAt: Date(), status: "成功", paths: states))
                try pruneHistory()
                return result
            } catch {
                let after = try? uniquePaths.enumerated().map { index, path in
                    try snapshot(URL(fileURLWithPath: path), at: dir.appendingPathComponent("after/\(index)"))
                }
                let states = uniquePaths.enumerated().map { index, path in
                    OperationPath(path: path, beforeDigest: before[index], afterDigest: after?[index] ?? before[index])
                }
                try? saveHistoryEntry(OperationHistoryEntry(id: id, action: action, kind: kind, target: target, createdAt: Date(), status: "失败", paths: states))
                try? pruneHistory()
                throw error
            }
        } catch {
            if !fm.fileExists(atPath: dir.appendingPathComponent("entry.json").path) { try? fm.removeItem(at: dir) }
            throw error
        }
    }

    func withAtomicContentOperation<T>(action: String, kind: String, target: String, paths: [URL], _ body: () throws -> T) throws -> T {
        historyLock.lock()
        defer { historyLock.unlock() }
        let staging = base.appendingPathComponent("content-rollback-" + UUID().uuidString)
        defer { try? fm.removeItem(at: staging) }
        let unique = Array(Set(paths)).sorted { $0.path < $1.path }
        let digests = try unique.enumerated().map { try snapshot($0.element, at: staging.appendingPathComponent(String($0.offset))) }
        return try withRecordedOperation(action: action, kind: kind, target: target, paths: unique) {
            do { return try body() }
            catch {
                let originalError = error
                for (index, path) in unique.enumerated() {
                    try restoreSnapshot(path: path.path, digest: digests[index], source: staging.appendingPathComponent(String(index)))
                }
                throw originalError
            }
        }
    }

    func rollbackOperation(_ entry: OperationHistoryEntry) throws {
        historyLock.lock()
        defer { historyLock.unlock() }
        guard let current = operationHistory().first(where: { $0.id == entry.id }), current.canRollback else {
            throw ManagerError.invalid("这条操作不能回滚")
        }
        for path in current.paths {
            let actual = try pathDigest(URL(fileURLWithPath: path.path))
            guard actual == path.afterDigest else { throw ManagerError.conflict("文件已被其他操作修改，无法回滚：\(path.path)") }
        }
        let originalDir = historyRoot.appendingPathComponent(current.id)
        for (index, path) in current.paths.enumerated() where path.beforeDigest != nil {
            let snapshot = originalDir.appendingPathComponent("before/\(index)")
            guard try pathDigest(snapshot) == path.beforeDigest else {
                throw ManagerError.invalid("回滚快照不完整：\(path.path)")
            }
        }
        try withRecordedOperation(action: "回滚：\(current.action)", kind: current.kind, target: current.target,
                                  paths: current.paths.map { URL(fileURLWithPath: $0.path) }) {
            do {
                for (index, path) in current.paths.enumerated() {
                    try restoreSnapshot(path: path.path, digest: path.beforeDigest,
                                        source: originalDir.appendingPathComponent("before/\(index)"))
                }
            } catch {
                for (index, path) in current.paths.enumerated() {
                    try? restoreSnapshot(path: path.path, digest: path.afterDigest,
                                         source: originalDir.appendingPathComponent("after/\(index)"))
                }
                throw error
            }
        }
        if fm.fileExists(atPath: originalDir.path) {
            var marked = current
            marked.status = "已回滚"
            try saveHistoryEntry(marked)
        }
    }

    private func saveHistoryEntry(_ entry: OperationHistoryEntry) throws {
        let file = historyRoot.appendingPathComponent(entry.id).appendingPathComponent("entry.json")
        try JSONEncoder().encode(entry).write(to: file, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    private func restoreSnapshot(path: String, digest: String?, source: URL) throws {
        let destination = URL(fileURLWithPath: path)
        if try pathDigest(destination) != nil { try fm.removeItem(at: destination) }
        if digest != nil {
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: destination)
        }
    }

    func pruneHistory() throws {
        guard historyPruningSuspensions == 0 else { return }
        for entry in operationHistory().dropFirst(historyLimit) {
            try fm.removeItem(at: historyRoot.appendingPathComponent(entry.id))
        }
    }

    private func snapshot(_ source: URL, at destination: URL) throws -> String? {
        guard let digest = try pathDigest(source) else { return nil }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.copyItem(at: source, to: destination)
        return digest
    }

    private func pathDigest(_ url: URL) throws -> String? {
        if let link = try? fm.destinationOfSymbolicLink(atPath: url.path) { return "link:" + link }
        guard fm.fileExists(atPath: url.path) else { return nil }
        let attributes = try fm.attributesOfItem(atPath: url.path)
        if attributes[.type] as? FileAttributeType == .typeDirectory {
            let children = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            let parts = try children.map { child in
                child.lastPathComponent + ":" + (try pathDigest(child) ?? "missing")
            }
            return "directory:" + SHA256.hash(data: Data(parts.joined(separator: "\n").utf8)).map { String(format: "%02x", $0) }.joined()
        }
        let data = try Data(contentsOf: url)
        return "file:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
