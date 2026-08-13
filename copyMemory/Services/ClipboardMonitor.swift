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
    }
}
