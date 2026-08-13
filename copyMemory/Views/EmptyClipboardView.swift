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

    var body: some View {
        Text(title)
            .multilineTextAlignment(.center)
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
}
