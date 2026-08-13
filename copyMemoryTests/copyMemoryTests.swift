//
//  copyMemoryTests.swift
//  copyMemoryTests
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import AppKit
import XCTest
@testable import copyMemory

@MainActor
final class ClipboardItemContentHashTests: XCTestCase {
    func testSameTextProducesSameHash() {
        XCTAssertEqual(
            ClipboardItemContentHash.forText("abc"),
            ClipboardItemContentHash.forText("abc")
        )
    }

    func testDifferentTextProducesDifferentHash() {
        XCTAssertNotEqual(
            ClipboardItemContentHash.forText("abc"),
            ClipboardItemContentHash.forText("xyz")
        )
    }

    func testSameImageDataProducesSameHash() {
        let data = Data([0x01, 0x02, 0x03])
        XCTAssertEqual(
            ClipboardItemContentHash.forImageData(data),
            ClipboardItemContentHash.forImageData(data)
        )
    }

    func testDifferentImageDataProducesDifferentHash() {
        XCTAssertNotEqual(
            ClipboardItemContentHash.forImageData(Data([0x01, 0x02])),
            ClipboardItemContentHash.forImageData(Data([0x03, 0x04]))
        )
    }
}

@MainActor
final class ClipboardStoreTests: XCTestCase {
    func testConsecutiveDedupeKeepsSingleItem() {
        let store = ClipboardStore()
        let item = makeTextItem("duplicate")

        store.insert(item)
        store.insert(makeTextItem("duplicate"))

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.text, "duplicate")
    }

    func testTrimRemovesOldestItemAtMaxCapacity() {
        let store = ClipboardStore()
        let oldest = makeTextItem("item-0")

        store.insert(oldest)
        for index in 1...ClipboardStore.maxItems {
            store.insert(makeTextItem("item-\(index)"))
        }

        XCTAssertEqual(store.items.count, ClipboardStore.maxItems)
        XCTAssertNil(store.items.first { $0.text == "item-0" })
        XCTAssertEqual(store.items.first?.text, "item-\(ClipboardStore.maxItems)")
    }

    func testSelectTextWritesStringToPasteboard() {
        let store = ClipboardStore()
        let item = makeTextItem("hello-select")
        store.insert(item)
        store.select(item)

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "hello-select")
        XCTAssertEqual(store.items.count, 1)
    }

    func testSelectImageWritesImageToPasteboard() throws {
        let store = ClipboardStore()
        let pngData = try makeMinimalPNGData()
        let item = ClipboardItem(
            id: UUID(),
            type: .image,
            text: nil,
            imageData: pngData,
            thumbnail: pngData,
            createdAt: Date(),
            contentHash: ClipboardItemContentHash.forImageData(pngData)
        )
        store.insert(item)
        store.select(item)

        XCTAssertTrue(NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil))
        XCTAssertEqual(store.items.count, 1)
    }
}

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    func testMixedContentPrefersImage() throws {
        let monitor = ClipboardMonitor()
        let pasteboard = NSPasteboard.general
        let pngData = try makeMinimalPNGData()

        pasteboard.clearContents()
        pasteboard.setString("caption", forType: .string)
        XCTAssertTrue(pasteboard.setData(pngData, forType: .png))

        let item = monitor.captureItem(from: pasteboard)

        XCTAssertEqual(item?.type, .image)
        XCTAssertNotNil(item?.imageData)
        XCTAssertNotNil(item?.thumbnail)
        XCTAssertNil(item?.text)
    }
}

private func makeTextItem(_ text: String) -> ClipboardItem {
    ClipboardItem(
        id: UUID(),
        type: .text,
        text: text,
        imageData: nil,
        thumbnail: nil,
        createdAt: Date(),
        contentHash: ClipboardItemContentHash.forText(text)
    )
}

private func makeMinimalPNGData() throws -> Data {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 1,
        pixelsHigh: 1,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "copyMemoryTests", code: 1)
    }

    representation.setColor(.red, atX: 0, y: 0)

    guard let pngData = representation.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "copyMemoryTests", code: 2)
    }

    return pngData
}
