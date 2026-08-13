//
//  ClipboardItemRow.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import AppKit
import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem

    private let previewCharacterLimit = 120
    private let thumbnailSide: CGFloat = 36

    var body: some View {
        Group {
            switch item.type {
            case .text:
                textRow
            case .image:
                imageRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var textRow: some View {
        Text(displayText)
            .font(.callout)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private var imageRow: some View {
        HStack(spacing: 8) {
            thumbnailView
                .frame(width: thumbnailSide, height: thumbnailSide)

            Text(imageLabel)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailData = item.thumbnail,
           let image = NSImage(data: thumbnailData) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: thumbnailSide, maxHeight: thumbnailSide)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .overlay {
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var displayText: String {
        guard let text = item.text else { return "" }
        guard text.count > previewCharacterLimit else { return text }
        return String(text.prefix(previewCharacterLimit)) + "…"
    }

    private var imageLabel: String {
        if let data = item.thumbnail ?? item.imageData,
           let image = NSImage(data: data),
           image.size.width > 0,
           image.size.height > 0 {
            return "\(Int(image.size.width))×\(Int(image.size.height))"
        }

        return "Imagem"
    }
}

#if DEBUG
#Preview("Texto") {
    List {
        ClipboardItemRow(item: ClipboardItemPreviewFactory.text("Texto curto copiado"))
        ClipboardItemRow(item: ClipboardItemPreviewFactory.text(String(repeating: "Linha longa de código ou link copiado recentemente. ", count: 5)))
    }
    .listStyle(.plain)
    .frame(width: 320, height: 160)
}

#Preview("Imagem") {
    List {
        ClipboardItemRow(item: ClipboardItemPreviewFactory.image())
    }
    .listStyle(.plain)
    .frame(width: 320, height: 80)
}

enum ClipboardItemPreviewFactory {
    static func text(_ value: String) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            type: .text,
            text: value,
            imageData: nil,
            thumbnail: nil,
            createdAt: Date(),
            contentHash: ClipboardItemContentHash.forText(value)
        )
    }

    static func image(text: String? = nil) -> ClipboardItem {
        let pngData = minimalPNGData()
        return ClipboardItem(
            id: UUID(),
            type: .image,
            text: text,
            imageData: pngData,
            thumbnail: pngData,
            createdAt: Date(),
            contentHash: ClipboardItemContentHash.forImageData(pngData)
        )
    }

    private static func minimalPNGData() -> Data {
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 120,
            pixelsHigh: 80,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        representation.setColor(.systemBlue, atX: 0, y: 0)
        return representation.representation(using: .png, properties: [:])!
    }
}
#endif

