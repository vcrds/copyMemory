//
//  ClipboardItem.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import Foundation

enum ClipboardContentType: String, Equatable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let type: ClipboardContentType
    let text: String?
    let imageData: Data?
    let thumbnail: Data?
    let createdAt: Date
    let contentHash: String
}
