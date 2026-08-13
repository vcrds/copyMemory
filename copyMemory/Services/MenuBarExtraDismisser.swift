//
//  MenuBarExtraDismisser.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import AppKit
import SwiftUI

/// Fecha ou abre o painel do `MenuBarExtra`.
/// SwiftUI ainda não expõe `isPresented` estável (Xcode 26); este bridge usa só APIs públicas.
enum MenuBarExtraDismisser {
    @MainActor
    static func dismiss(hostWindow: NSWindow?) {
        let capturedWindow = hostWindow
        Task { @MainActor in
            if let button = statusBarButton() {
                button.performClick(nil)
                return
            }

            let window = capturedWindow ?? NSApp.keyWindow
            window?.resignKey()
            window?.orderOut(nil)
            statusBarButton()?.highlight(false)
        }
    }

    /// Abre o painel com o app em background (atalho global). Não cola no app em foco.
    @MainActor
    static func present() {
        NSApp.activate(ignoringOtherApps: true)

        if let panel = visibleMenuPanel() {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        statusBarButton()?.performClick(nil)
    }

    @MainActor
    private static func visibleMenuPanel() -> NSWindow? {
        NSApp.windows.first { window in
            window.isVisible
                && window.canBecomeKey
                && window.frame.width >= 280
                && window.frame.height >= 120
        }
    }

    @MainActor
    private static func statusBarButton() -> NSStatusBarButton? {
        for window in NSApp.windows {
            if let button = firstStatusBarButton(in: window.contentView) {
                return button
            }
        }
        return nil
    }

    @MainActor
    private static func firstStatusBarButton(in view: NSView?) -> NSStatusBarButton? {
        guard let view else { return nil }
        if let button = view as? NSStatusBarButton {
            return button
        }
        for subview in view.subviews {
            if let button = firstStatusBarButton(in: subview) {
                return button
            }
        }
        return nil
    }
}

struct MenuBarExtraWindowReader: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onResolve = onResolve
        return view
    }

    func updateNSView(_ nsView: ReaderView, context: Context) {
        nsView.onResolve = onResolve
    }

    final class ReaderView: NSView {
        var onResolve: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onResolve?(window)
        }
    }
}
