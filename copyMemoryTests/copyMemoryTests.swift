//
//  copyMemoryTests.swift
//  copyMemoryTests
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import AppKit
import Combine
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
        let store = makeIsolatedStore()
        let item = makeTextItem("duplicate")

        store.insert(item)
        store.insert(makeTextItem("duplicate"))

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.text, "duplicate")
    }

    func testTrimRemovesOldestItemAtMaxCapacity() {
        let store = makeIsolatedStore()
        let oldest = makeTextItem("item-0")

        store.insert(oldest)
        for index in 1...ClipboardStore.maxItems {
            store.insert(makeTextItem("item-\(index)"))
        }

        XCTAssertEqual(store.items.count, ClipboardStore.maxItems)
        XCTAssertNil(store.items.first { $0.text == "item-0" })
        XCTAssertEqual(store.items.first?.text, "item-\(ClipboardStore.maxItems)")
    }

    func testSimulatedOwnWriteDoesNotInsert() {
        let store = makeIsolatedStore()
        let monitor = ClipboardMonitor()
        store.attach(monitor: monitor)

        store.beginOwnContentWrite()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("ignored", forType: .string)
        monitor.syncChangeCount()
        store.endOwnContentWrite()

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(store.isWritingOwnContent)
        XCTAssertFalse(monitor.isWritingOwnContent)
    }

    func testSelectTextWritesStringToPasteboard() {
        let store = makeIsolatedStore()
        let monitor = ClipboardMonitor()
        store.attach(monitor: monitor)

        let item = makeTextItem("hello-select")
        store.insert(item)
        store.select(item)

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "hello-select")
        XCTAssertEqual(store.items.count, 1)
        XCTAssertFalse(store.isWritingOwnContent)
        XCTAssertFalse(monitor.isWritingOwnContent)
    }

    func testSelectImageWritesImageToPasteboard() throws {
        let store = makeIsolatedStore()
        let monitor = ClipboardMonitor()
        store.attach(monitor: monitor)

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

    func testSelectDoesNotDuplicateHistoryAfterPoll() async throws {
        let store = makeIsolatedStore()
        let monitor = ClipboardMonitor()
        store.attach(monitor: monitor)

        let unique = "select-own-write-\(UUID().uuidString)"
        let older = makeTextItem(unique)
        let newer = makeTextItem("newer-\(UUID().uuidString)")
        store.insert(older)
        store.insert(newer)

        let subscription = monitor.itemCaptured.sink { store.insert($0) }
        monitor.start()
        defer {
            subscription.cancel()
            monitor.stop()
        }

        store.select(older)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), unique)

        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(store.items.filter { $0.text == unique }.count, 1)
        XCTAssertEqual(store.items.first { $0.text == unique }?.id, older.id)
        XCTAssertFalse(store.isWritingOwnContent)
        XCTAssertFalse(monitor.isWritingOwnContent)
    }

    func testRemoveItemKeepsRemainingOrder() {
        let store = makeIsolatedStore()
        let first = makeTextItem("first")
        let second = makeTextItem("second")
        let third = makeTextItem("third")

        store.insert(first)
        store.insert(second)
        store.insert(third)
        store.remove(second)

        XCTAssertEqual(store.items.map(\.text), ["third", "first"])
    }

    func testClearEmptiesHistory() {
        let store = makeIsolatedStore()
        store.insert(makeTextItem("keep-me-not"))
        store.insert(makeTextItem("also-gone"))

        store.clear()

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.filteredItems.isEmpty)
    }

    func testPersistenceOffDoesNotWriteHistoryFile() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cm-persist-off-\(UUID().uuidString)", isDirectory: true)
        let persistence = ClipboardPersistence(directoryURL: directory)
        let defaults = UserDefaults(suiteName: "cm-persist-off-\(UUID().uuidString)")!

        let store = ClipboardStore(persistence: persistence, userDefaults: defaults)
        store.insert(makeTextItem("ephemeral"))

        XCTAssertFalse(store.persistsAcrossLaunches)
        XCTAssertFalse(FileManager.default.fileExists(atPath: persistence.fileURL.path))
    }

    func testPersistenceOnSurvivesReload() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cm-persist-on-\(UUID().uuidString)", isDirectory: true)
        let persistence = ClipboardPersistence(directoryURL: directory)
        let suiteName = "cm-persist-on-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let store = ClipboardStore(persistence: persistence, userDefaults: defaults)
        store.persistsAcrossLaunches = true
        store.insert(makeTextItem("survives"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: persistence.fileURL.path))

        let reloaded = ClipboardStore(persistence: persistence, userDefaults: defaults)
        XCTAssertEqual(reloaded.items.first?.text, "survives")
        XCTAssertTrue(reloaded.persistsAcrossLaunches)
    }

    func testDisablingPersistenceWipesHistoryFile() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cm-persist-wipe-\(UUID().uuidString)", isDirectory: true)
        let persistence = ClipboardPersistence(directoryURL: directory)
        let defaults = UserDefaults(suiteName: "cm-persist-wipe-\(UUID().uuidString)")!

        let store = ClipboardStore(persistence: persistence, userDefaults: defaults)
        store.persistsAcrossLaunches = true
        store.insert(makeTextItem("secret"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: persistence.fileURL.path))

        store.persistsAcrossLaunches = false
        XCTAssertFalse(FileManager.default.fileExists(atPath: persistence.fileURL.path))
        XCTAssertEqual(store.items.first?.text, "secret")
    }
}

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    private var savedChangeCount: Int = 0

    override func setUp() async throws {
        savedChangeCount = NSPasteboard.general.changeCount
    }

    override func tearDown() async throws {
        NSPasteboard.general.clearContents()
        _ = NSPasteboard.general.changeCount
    }

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

    func testOwnWriteFlagSkipsCapturedItem() async throws {
        let monitor = ClipboardMonitor()
        var capturedItems: [ClipboardItem] = []
        let subscription = monitor.itemCaptured.sink { capturedItems.append($0) }

        monitor.start()
        defer {
            subscription.cancel()
            monitor.stop()
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("first", forType: .string)
        try await Task.sleep(nanoseconds: 600_000_000)

        let capturedBeforeOwnWrite = capturedItems.count

        monitor.isWritingOwnContent = true
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("second", forType: .string)
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(capturedItems.count, capturedBeforeOwnWrite)
        monitor.isWritingOwnContent = false
        monitor.syncChangeCount()
    }
}

@MainActor
final class ClipboardImageProcessorTests: XCTestCase {
    func testSmallImageKeepsOriginalPayload() throws {
        let pngData = try makeMinimalPNGData()
        let image = try XCTUnwrap(NSImage(data: pngData))

        let payload = ClipboardImageProcessor.reusablePayload(from: image, originalData: pngData)

        XCTAssertEqual(payload, pngData)
    }

    func testLargeImagePayloadIsDownscaled() throws {
        let pngData = try makePNGData(width: 3000, height: 2000)
        let image = try XCTUnwrap(NSImage(data: pngData))

        let payload = ClipboardImageProcessor.reusablePayload(from: image, originalData: pngData)
        let storedImage = try XCTUnwrap(NSImage(data: payload))
        let pixelSize = try XCTUnwrap(ClipboardImageProcessor.pixelSize(of: storedImage))

        XCTAssertLessThanOrEqual(max(pixelSize.width, pixelSize.height), Int(ClipboardImageProcessor.maxPayloadSide))
        XCTAssertNotNil(NSImage(data: payload), "re-copiar ainda deve produzir imagem utilizável")
    }

    func testThumbnailRespectsMaxSide() throws {
        let pngData = try makePNGData(width: 1200, height: 800)
        let image = try XCTUnwrap(NSImage(data: pngData))
        let thumbnail = try XCTUnwrap(ClipboardImageProcessor.thumbnailPNG(from: image))
        let thumbImage = try XCTUnwrap(NSImage(data: thumbnail))
        let pixelSize = try XCTUnwrap(ClipboardImageProcessor.pixelSize(of: thumbImage))

        XCTAssertLessThanOrEqual(max(pixelSize.width, pixelSize.height), Int(ClipboardImageProcessor.maxThumbnailSide))
    }
}

@MainActor
private func makeIsolatedStore() -> ClipboardStore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("cm-store-\(UUID().uuidString)", isDirectory: true)
    return ClipboardStore(
        persistence: ClipboardPersistence(directoryURL: directory),
        userDefaults: UserDefaults(suiteName: "cm-store-\(UUID().uuidString)")!
    )
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

private func makePNGData(width: Int, height: Int) throws -> Data {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "copyMemoryTests", code: 3)
    }

    representation.setColor(.systemBlue, atX: 0, y: 0)
    representation.setColor(.systemRed, atX: width - 1, y: height - 1)

    guard let pngData = representation.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "copyMemoryTests", code: 4)
    }

    return pngData
}
