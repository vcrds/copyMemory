//
//  ClipboardImageProcessor.swift
//  copyMemory
//
//  Created by Vinícius Cardoso on 12/08/26.
//

import AppKit
import Foundation

enum ClipboardImageProcessor {
    static let maxThumbnailSide: CGFloat = 256

    static func thumbnailPNG(from image: NSImage) -> Data? {
        scaledRepresentation(from: image, maxSide: maxThumbnailSide, using: .png)
    }

    static func pixelSize(of image: NSImage) -> (width: Int, height: Int)? {
        guard let cgImage = cgImage(from: image) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }
        return (width, height)
    }

    private static func scaledRepresentation(
        from image: NSImage,
        maxSide: CGFloat,
        using format: NSBitmapImageRep.FileType
    ) -> Data? {
        guard let cgImage = cgImage(from: image) else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        guard width > 0, height > 0 else { return nil }

        let scale = min(1.0, maxSide / max(width, height))
        let targetWidth = max(1, Int((width * scale).rounded(.down)))
        let targetHeight = max(1, Int((height * scale).rounded(.down)))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let scaledImage = context.makeImage() else { return nil }

        let representation = NSBitmapImageRep(cgImage: scaledImage)
        return representation.representation(using: format, properties: [:])
    }

    private static func cgImage(from image: NSImage) -> CGImage? {
        image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
