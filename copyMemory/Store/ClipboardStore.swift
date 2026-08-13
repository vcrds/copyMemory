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

    func insert(_ item: ClipboardItem) {
        items.insert(item, at: 0)

        if items.count > Self.maxItems {
            items.removeLast(items.count - Self.maxItems)
        }
    }
}
