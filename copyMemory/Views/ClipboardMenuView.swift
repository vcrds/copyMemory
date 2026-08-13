//
//  ClipboardMenuView.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import AppKit
import SwiftUI

struct ClipboardMenuView: View {
    private let panelWidth: CGFloat = 320
    private let listHeight: CGFloat = 280

    var body: some View {
        VStack(spacing: 0) {
            TextField("Buscar…", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            Color.clear
                .frame(height: listHeight)

            Divider()

            HStack {
                Spacer()

                Button("Sair") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: panelWidth)
    }
}
