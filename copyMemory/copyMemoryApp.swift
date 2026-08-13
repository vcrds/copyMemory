//
//  copyMemoryApp.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import SwiftUI

@main
struct copyMemoryApp: App {
    var body: some Scene {
        MenuBarExtra("copyMemory", systemImage: "doc.on.clipboard") {
            ClipboardMenuView()
        }
        .menuBarExtraStyle(.window)
    }
}
