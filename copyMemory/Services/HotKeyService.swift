//
//  HotKeyService.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import Carbon
import Foundation

/// Atalho global que abre o painel (não cola no app em foco; sem Accessibility).
/// Padrão: ⌥⌘V (Option+Command+V).
nonisolated final class HotKeyService: @unchecked Sendable {
    static let defaultShortcutDisplayName = "⌥⌘V"

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onPressed: (() -> Void)?

    private let hotKeyID = EventHotKeyID(signature: OSType(0x634D656D), id: 1) // 'cMem'

    func register(_ onPressed: @escaping () -> Void) {
        unregister()
        self.onPressed = onPressed
        HotKeyCallbackBox.shared.service = self

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        var handler: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            nil,
            &handler
        )
        guard installStatus == noErr else { return }
        handlerRef = handler

        var hotKey: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard registerStatus == noErr else {
            unregister()
            return
        }
        hotKeyRef = hotKey
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        if HotKeyCallbackBox.shared.service === self {
            HotKeyCallbackBox.shared.service = nil
        }
        onPressed = nil
    }

    fileprivate func handleHotKeyPressed() {
        onPressed?()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}

/// Ponte não isolada para o callback C do Carbon.
nonisolated private final class HotKeyCallbackBox: @unchecked Sendable {
    static let shared = HotKeyCallbackBox()
    weak var service: HotKeyService?
}

nonisolated private func hotKeyEventHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }

    var eventHotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &eventHotKeyID
    )
    guard status == noErr, eventHotKeyID.signature == OSType(0x634D656D) else {
        return OSStatus(eventNotHandledErr)
    }

    DispatchQueue.main.async {
        HotKeyCallbackBox.shared.service?.handleHotKeyPressed()
    }
    return noErr
}
