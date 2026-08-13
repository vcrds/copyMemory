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

    private static let imageTypes: [NSPasteboard.PasteboardType] = [
        .png,
        .tiff,
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
        if let textItem = captureTextItem(from: pasteboard) {
            return textItem
        }

        return captureImageItem(from: pasteboard)
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

    private func captureImageItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        guard let payload = readImagePayload(from: pasteboard),
              let thumbnail = ClipboardImageProcessor.thumbnailPNG(from: payload.image) else {
            return nil
        }

        return ClipboardItem(
            id: UUID(),
            type: .image,
            text: nil,
            imageData: payload.data,
            thumbnail: thumbnail,
            createdAt: Date(),
            contentHash: ClipboardItemContentHash.forImageData(payload.data)
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

    private func readImagePayload(from pasteboard: NSPasteboard) -> (data: Data, image: NSImage)? {
        if let type = pasteboard.availableType(from: Self.imageTypes),
           let data = pasteboard.data(forType: type),
           !data.isEmpty,
           let image = NSImage(data: data),
           image.isValid {
            return (data, image)
        }

        if let image = NSImage(pasteboard: pasteboard),
           image.isValid,
           let data = pngData(from: image) {
            return (data, image)
        }

        return nil
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        return representation.representation(using: .png, properties: [:])
    }
}
