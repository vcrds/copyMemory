//
//  EmptyClipboardView.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import SwiftUI

enum EmptyClipboardMode {
    case noHistory
    case noResults
}

struct EmptyClipboardView: View {
    let mode: EmptyClipboardMode
    var persistsAcrossLaunches = false

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var title: String {
        switch mode {
        case .noHistory:
            "Nenhuma cópia ainda"
        case .noResults:
            "Nenhum item encontrado"
        }
    }

    private var subtitle: String? {
        switch mode {
        case .noHistory:
            persistsAcrossLaunches
                ? "As cópias ficam salvas neste Mac."
                : "O histórico some ao sair do app."
        case .noResults:
            nil
        }
    }
}

#Preview("Histórico vazio") {
    EmptyClipboardView(mode: .noHistory)
        .frame(width: 320)
}

#Preview("Histórico vazio persistente") {
    EmptyClipboardView(mode: .noHistory, persistsAcrossLaunches: true)
        .frame(width: 320)
}

#Preview("Sem resultados") {
    EmptyClipboardView(mode: .noResults)
        .frame(width: 320)
}
