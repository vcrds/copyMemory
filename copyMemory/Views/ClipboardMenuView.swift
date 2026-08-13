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
    @State private var hoveredItemID: ClipboardItem.ID?
    @State private var isConfirmingClear = false

    private let panelWidth: CGFloat = 320
    private let listHeight: CGFloat = 280

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            searchField(query: $store.searchQuery)

            Divider()

            content

            Divider()

            footer
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
            EmptyClipboardView(
                mode: emptyMode,
                persistsAcrossLaunches: store.persistsAcrossLaunches
            )
        } else {
            ScrollViewReader { proxy in
                List(store.filteredItems) { item in
                    historyRow(for: item)
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

    private var footer: some View {
        @Bindable var store = store

        return VStack(alignment: .leading, spacing: 8) {
            Toggle("Manter histórico ao sair", isOn: $store.persistsAcrossLaunches)
                .toggleStyle(.checkbox)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Limpar histórico") {
                    isConfirmingClear = true
                }
                .disabled(store.items.isEmpty)

                Spacer()

                Button("Sair") {
                    NSApplication.shared.terminate(nil)
                }
            }

            Text("Atalho \(HotKeyService.defaultShortcutDisplayName)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .confirmationDialog(
            "Limpar todo o histórico?",
            isPresented: $isConfirmingClear
        ) {
            Button("Limpar", role: .destructive) {
                store.clear()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(
                store.persistsAcrossLaunches
                    ? "Os itens salvos neste Mac também serão apagados."
                    : "Esta ação vale só para a sessão atual."
            )
        }
    }

    private func historyRow(for item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            Button {
                selectAndDismiss(item)
            } label: {
                ClipboardItemRow(item: item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                store.remove(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Remover")
            .opacity(hoveredItemID == item.id ? 1 : 0)
            .allowsHitTesting(hoveredItemID == item.id)
        }
        .onHover { hovering in
            hoveredItemID = hovering ? item.id : (hoveredItemID == item.id ? nil : hoveredItemID)
        }
        .contextMenu {
            Button("Remover", role: .destructive) {
                store.remove(item)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Remover", role: .destructive) {
                store.remove(item)
            }
        }
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

#if DEBUG
#Preview("Lista com itens") {
    ClipboardMenuView()
        .environment(ClipboardStore.previewPopulated())
}

#Preview("Histórico vazio") {
    ClipboardMenuView()
        .environment(ClipboardStore.isolatedPreviewStore())
}

#Preview("Busca sem resultados") {
    ClipboardMenuView()
        .environment({
            let store = ClipboardStore.previewPopulated()
            store.searchQuery = "zzzz"
            return store
        }())
}
#endif
