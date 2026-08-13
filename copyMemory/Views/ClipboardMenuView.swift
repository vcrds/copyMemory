//
//  ClipboardMenuView.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import AppKit
import SwiftUI

struct ClipboardMenuView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("copyMemory")

            Divider()

            Button("Sair") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
    }
}
