//
//  PasteboardMediaHandler.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26
//

import Cocoa
import Foundation

final class PasteboardMediaHandler {
    static let shared = PasteboardMediaHandler()

    private init() {}

    /// Writes a history item back to the general pasteboard so it pastes
    /// as a real file or image object into Finder, Messages, Pages, etc.
    func write(_ item: ClipboardItem) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(item.text, forType: .string)
            return true

        case .image, .video:
            return writeMedia(item, to: pasteboard)

        case .file:
            return writeFile(item, to: pasteboard)
        }
    }

    private func writeMedia(_ item: ClipboardItem, to pasteboard: NSPasteboard) -> Bool {
        guard let url = item.cachedURL ?? item.fileURL else { return false }

        var types: [NSPasteboard.PasteboardType] = [.fileURL]
        if item.type == .image {
            types.append(contentsOf: [.png, .tiff])
        }

        pasteboard.declareTypes(types, owner: nil)

        // Provide the actual file so Finder / Messages receive a real file object.
        pasteboard.writeObjects([url as NSURL])

        // Also provide image data for apps that expect an image (Pages, Messages).
        if item.type == .image, let image = NSImage(contentsOf: url) {
            if let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
            if let png = pngData(from: image) {
                pasteboard.setData(png, forType: .png)
            }
        }

        return true
    }

    private func writeFile(_ item: ClipboardItem, to pasteboard: NSPasteboard) -> Bool {
        guard let url = item.cachedURL ?? item.fileURL else { return false }
        pasteboard.declareTypes([.fileURL], owner: nil)
        pasteboard.writeObjects([url as NSURL])
        return true
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
