//
//  copyMemoryApp.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import Combine
import SwiftUI

@MainActor
final class AppServices {
    let store = ClipboardStore()
    let monitor = ClipboardMonitor()
    let hotKey = HotKeyService()
    private var monitorSubscription: AnyCancellable?

    init() {
        store.attach(monitor: monitor)
        monitorSubscription = monitor.itemCaptured.sink { [store] item in
            store.insert(item)
        }
        monitor.start()
        hotKey.register {
            Task { @MainActor in
                MenuBarExtraDismisser.present()
            }
        }
    }

    deinit {
        monitorSubscription?.cancel()
        hotKey.unregister()
    }
}

@main
struct copyMemoryApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        MenuBarExtra("copyMemory", systemImage: "doc.on.clipboard") {
            ClipboardMenuView()
                .environment(services.store)
        }
        .menuBarExtraStyle(.window)
    }
}
