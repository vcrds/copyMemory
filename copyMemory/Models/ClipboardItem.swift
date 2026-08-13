//
//  ClipboardItem.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import CryptoKit
import Foundation

enum ClipboardContentType: String, Equatable, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    let type: ClipboardContentType
    let text: String?
    let imageData: Data?
    let thumbnail: Data?
    let createdAt: Date
    let contentHash: String
}

enum ClipboardItemContentHash {
    static func forText(_ text: String) -> String {
        sha256Hex(of: Data(text.utf8))
    }

    static func forImageData(_ data: Data) -> String {
        sha256Hex(of: data)
    }

    private static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
