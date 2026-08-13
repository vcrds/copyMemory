//
//  ClipboardMonitor.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardMonitor {
    let itemCaptured = PassthroughSubject<ClipboardItem, Never>()

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timerCancellable: AnyCancellable?

    private static let stringTypes: [NSPasteboard.PasteboardType] = [
        .string,
        NSPasteboard.PasteboardType("public.utf8-plain-text"),
        NSPasteboard.PasteboardType("public.utf16-plain-text"),
    ]

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard timerCancellable == nil else { return }

        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollPasteboard()
            }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    deinit {
        timerCancellable?.cancel()
    }

    /// Idle: compara só o `changeCount` (`Int`). Sem leitura de tipos, imagens ou I/O.
    private func pollPasteboard() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard let item = captureItem(from: pasteboard) else { return }
        itemCaptured.send(item)
    }

    func captureItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        captureTextItem(from: pasteboard)
    }

    private func captureTextItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        guard let text = readString(from: pasteboard) else { return nil }

        return ClipboardItem(
            id: UUID(),
            type: .text,
            text: text,
            imageData: nil,
            thumbnail: nil,
            createdAt: Date(),
            contentHash: ClipboardItemContentHash.forText(text)
        )
    }

    private func readString(from pasteboard: NSPasteboard) -> String? {
        for type in Self.stringTypes {
            if let string = pasteboard.string(forType: type), !string.isEmpty {
                return string
            }
        }

        return nil
    }
}
