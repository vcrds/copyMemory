//
//  ClipboardItemRow.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem

    private let previewCharacterLimit = 120

    var body: some View {
        Text(displayText)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private var displayText: String {
        guard let text = item.text else { return "" }
        guard text.count > previewCharacterLimit else { return text }
        return String(text.prefix(previewCharacterLimit)) + "…"
    }
}
