//
//  ClipboardMenuView.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import AppKit
import SwiftUI

struct ClipboardMenuView: View {
    @Environment(ClipboardStore.self) private var store

    private let panelWidth: CGFloat = 320
    private let listHeight: CGFloat = 280

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            TextField("Buscar…", text: $store.searchQuery)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            content

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

    @ViewBuilder
    private var content: some View {
        if store.filteredItems.isEmpty {
            EmptyClipboardView(mode: emptyMode)
                .frame(height: listHeight)
        } else {
            List(store.filteredItems) { item in
                ClipboardItemRow(item: item)
            }
            .listStyle(.plain)
            .frame(height: listHeight)
        }
    }

    private var emptyMode: EmptyClipboardMode {
        store.items.isEmpty ? .noHistory : .noResults
    }
}

#Preview("Lista com itens") {
    ClipboardMenuView()
        .environment(ClipboardStore.previewPopulated())
}

#Preview("Histórico vazio") {
    ClipboardMenuView()
        .environment(ClipboardStore.isolatedPreviewStore())
}

#Preview("Busca sem resultados") {
    let store = ClipboardStore.previewPopulated()
    store.searchQuery = "zzzz"
    return ClipboardMenuView()
        .environment(store)
}
