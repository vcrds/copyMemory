//
//  ClipboardStore.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class ClipboardStore {
    static let maxItems = 50
    static let persistenceFlagKey = "clipboardPersistsAcrossLaunches"

    private(set) var items: [ClipboardItem] = []
    private(set) var isWritingOwnContent = false
    var searchQuery = ""

    var persistsAcrossLaunches: Bool {
        didSet {
            guard oldValue != persistsAcrossLaunches else { return }
            userDefaults.set(persistsAcrossLaunches, forKey: Self.persistenceFlagKey)
            if persistsAcrossLaunches {
                persistIfNeeded()
            } else {
                persistence.wipe()
            }
        }
    }

    private weak var monitor: ClipboardMonitor?
    private let persistence: ClipboardPersistence
    private let userDefaults: UserDefaults

    init(
        persistence: ClipboardPersistence = ClipboardPersistence(),
        userDefaults: UserDefaults = .standard
    ) {
        self.persistence = persistence
        self.userDefaults = userDefaults
        self.persistsAcrossLaunches = userDefaults.bool(forKey: Self.persistenceFlagKey)

        if persistsAcrossLaunches {
            items = persistence.load()
            if items.count > Self.maxItems {
                items = Array(items.prefix(Self.maxItems))
            }
        }
    }

    var filteredItems: [ClipboardItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }

        return items.filter { item in
            guard let text = item.text, !text.isEmpty else { return false }
            return text.range(of: query, options: .caseInsensitive) != nil
        }
    }

    func attach(monitor: ClipboardMonitor) {
        self.monitor = monitor
    }

    func beginOwnContentWrite() {
        isWritingOwnContent = true
        monitor?.isWritingOwnContent = true
    }

    func endOwnContentWrite() {
        monitor?.syncChangeCount()
        isWritingOwnContent = false
        monitor?.isWritingOwnContent = false
    }

    func insert(_ item: ClipboardItem) {
        if let latest = items.first, latest.contentHash == item.contentHash {
            return
        }

        items.insert(item, at: 0)

        if items.count > Self.maxItems {
            items.removeLast(items.count - Self.maxItems)
        }

        persistIfNeeded()
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persistIfNeeded()
    }

    func clear() {
        items.removeAll()
        persistIfNeeded()
    }

    func select(_ item: ClipboardItem) {
        guard canWrite(item) else { return }

        beginOwnContentWrite()
        Self.writeToPasteboard(item)
        endOwnContentWrite()
    }

    private func persistIfNeeded() {
        guard persistsAcrossLaunches else { return }
        persistence.save(items)
    }

    private func canWrite(_ item: ClipboardItem) -> Bool {
        switch item.type {
        case .text:
            return item.text != nil
        case .image:
            return item.imageData != nil
        }
    }

    private static func writeToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            guard let text = item.text else { return }
            pasteboard.setString(text, forType: .string)

        case .image:
            guard let imageData = item.imageData else { return }
            if let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image])
            } else {
                pasteboard.setData(imageData, forType: .png)
            }
        }
    }
}

#if DEBUG
extension ClipboardStore {
    static func previewPopulated() -> ClipboardStore {
        let store = isolatedPreviewStore()
        store.insert(ClipboardItemPreviewFactory.text("https://example.com/docs"))
        store.insert(ClipboardItemPreviewFactory.text(String(repeating: "Código SwiftUI com tipografia densa e truncamento natural na largura do menu. ", count: 4)))
        store.insert(ClipboardItemPreviewFactory.image())
        return store
    }

    static func isolatedPreviewStore() -> ClipboardStore {
        ClipboardStore(
            persistence: ClipboardPersistence(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("copyMemory-preview-\(UUID().uuidString)", isDirectory: true)
            ),
            userDefaults: UserDefaults(suiteName: "copyMemory.preview.\(UUID().uuidString)") ?? .standard
        )
    }
}
#endif
