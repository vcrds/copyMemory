//
//  ClipboardStore.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class ClipboardStore {
    static let maxItems = 50

    private(set) var items: [ClipboardItem] = []
    private(set) var isWritingOwnContent = false

    private weak var monitor: ClipboardMonitor?

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
    }
}
