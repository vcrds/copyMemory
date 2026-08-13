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
    private var monitorSubscription: AnyCancellable?

    init() {
        store.attach(monitor: monitor)
        monitorSubscription = monitor.itemCaptured.sink { [store] item in
            store.insert(item)
        }
        monitor.start()
    }

    deinit {
        monitorSubscription?.cancel()
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
