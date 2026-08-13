//
//  ClipboardPersistence.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import Foundation

/// Persistência opcional em Application Support (JSON). Sem I/O quando a flag está desligada.
nonisolated struct ClipboardPersistence: Sendable {
    let directoryURL: URL
    let fileURL: URL

    private static let folderName = "com.vinicius.copyMemory"
    private static let fileName = "history.json"

    init(directoryURL: URL? = nil) {
        let directory = directoryURL ?? Self.defaultDirectoryURL()
        self.directoryURL = directory
        self.fileURL = directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    func load() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode(PersistedClipboardHistory.self, from: data).items
        } catch {
            return []
        }
    }

    func save(_ items: [ClipboardItem]) {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(PersistedClipboardHistory(items: items))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Falha ao persistir histórico: \(error.localizedDescription)")
        }
    }

    func wipe() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func defaultDirectoryURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent(folderName, isDirectory: true)
    }
}

private struct PersistedClipboardHistory: Codable {
    var items: [ClipboardItem]
}
