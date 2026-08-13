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
    @FocusState private var isSearchFocused: Bool
    @State private var selectedItemID: ClipboardItem.ID?
    @State private var menuWindow: NSWindow?
    @State private var didSelect = false

    private let panelWidth: CGFloat = 320
    private let listHeight: CGFloat = 280

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            searchField(query: $store.searchQuery)

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
        .background {
            MenuBarExtraWindowReader { menuWindow = $0 }
        }
        .onAppear {
            didSelect = false
            isSearchFocused = true
            selectedItemID = store.filteredItems.first?.id
        }
        .onChange(of: store.filteredItems.map(\.id)) {
            let ids = store.filteredItems.map(\.id)
            if let selectedItemID, ids.contains(selectedItemID) { return }
            selectedItemID = ids.first
        }
        .onKeyPress(.upArrow) {
            moveSelection(offset: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(offset: 1)
            return .handled
        }
    }

    private func searchField(query: Binding<String>) -> some View {
        TextField("Buscar…", text: query)
            .textFieldStyle(.roundedBorder)
            .font(.callout)
            .focused($isSearchFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .onKeyPress(.upArrow) {
                moveSelection(offset: -1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                moveSelection(offset: 1)
                return .handled
            }
            .onSubmit {
                selectFocusedItem()
            }
    }

    @ViewBuilder
    private var content: some View {
        if store.filteredItems.isEmpty {
            EmptyClipboardView(mode: emptyMode)
                .frame(height: listHeight)
        } else {
            ScrollViewReader { proxy in
                List(store.filteredItems) { item in
                    Button {
                        selectAndDismiss(item)
                    } label: {
                        ClipboardItemRow(item: item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(rowBackground(for: item))
                    .id(item.id)
                }
                .listStyle(.plain)
                .frame(height: listHeight)
                .onChange(of: selectedItemID) {
                    guard let selectedItemID else { return }
                    proxy.scrollTo(selectedItemID)
                }
            }
        }
    }

    private var emptyMode: EmptyClipboardMode {
        store.items.isEmpty ? .noHistory : .noResults
    }

    private func rowBackground(for item: ClipboardItem) -> Color {
        selectedItemID == item.id ? Color.accentColor.opacity(0.18) : Color.clear
    }

    private func moveSelection(offset: Int) {
        let items = store.filteredItems
        guard !items.isEmpty else { return }

        let currentIndex = items.firstIndex { $0.id == selectedItemID }
            ?? (offset > 0 ? -1 : items.count)
        let nextIndex = min(max(currentIndex + offset, 0), items.count - 1)
        selectedItemID = items[nextIndex].id
    }

    private func selectFocusedItem() {
        let items = store.filteredItems
        let item = items.first { $0.id == selectedItemID } ?? items.first
        guard let item else { return }
        selectAndDismiss(item)
    }

    private func selectAndDismiss(_ item: ClipboardItem) {
        guard !didSelect else { return }
        didSelect = true
        store.select(item)
        MenuBarExtraDismisser.dismiss(hostWindow: menuWindow)
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
