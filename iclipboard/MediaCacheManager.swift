//
//  MediaCacheManager.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26
//

import AVFoundation
import Cocoa
import Foundation

final class MediaCacheManager {
    static let shared = MediaCacheManager()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let thumbnailMaxSize = CGSize(width: 240, height: 240)
    private let videoThumbnailTime = CMTime(seconds: 1, preferredTimescale: 600)

    private init() {
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            fatalError("Unable to locate Application Support directory")
        }
        cacheDirectory = appSupport.appendingPathComponent(
            "com.yashpaliwal.iclipboard/media", isDirectory: true
        )
        try? fileManager.createDirectory(
            at: cacheDirectory, withIntermediateDirectories: true
        )
    }

    /// Copies the original media file to the app cache and generates a thumbnail.
    /// Returns the cached file URL and an optional thumbnail URL.
    func cacheMedia(originalURL: URL, mimeType: String)
        -> (cachedURL: URL, thumbnailURL: URL?)
    {
        let fileName = UUID().uuidString
            + (originalURL.pathExtension.isEmpty ? "" : "." + originalURL.pathExtension)
        let destURL = cacheDirectory.appendingPathComponent(fileName)

        if !fileManager.fileExists(atPath: destURL.path) {
            try? fileManager.copyItem(at: originalURL, to: destURL)
        }

        var thumbnailURL: URL?
        if mimeType.hasPrefix("image/") {
            thumbnailURL = generateAndCacheThumbnail(for: destURL, isVideo: false)
        } else if mimeType.hasPrefix("video/") {
            thumbnailURL = generateAndCacheThumbnail(for: destURL, isVideo: true)
        }

        return (destURL, thumbnailURL)
    }

    /// Caches an in-memory NSImage (e.g. copied from a browser) as a file + thumbnail.
    func cacheImage(_ image: NSImage, mimeType: String)
        -> (cachedURL: URL, thumbnailURL: URL?)
    {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            return (URL(string: "")!, nil)
        }

        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")
        try? pngData.write(to: tempURL)

        let result = cacheMedia(originalURL: tempURL, mimeType: mimeType)
        try? fileManager.removeItem(at: tempURL)
        return result
    }

    private func generateAndCacheThumbnail(for url: URL, isVideo: Bool) -> URL? {
        let thumbURL = cacheDirectory.appendingPathComponent(url.lastPathComponent + ".thumb.png")

        if fileManager.fileExists(atPath: thumbURL.path) {
            return thumbURL
        }

        let thumbnail: NSImage?
        if isVideo {
            thumbnail = generateVideoThumbnail(from: url)
        } else {
            thumbnail = NSImage(contentsOf: url)?.thumbnail(maxSize: thumbnailMaxSize)
        }

        guard let image = thumbnail,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            return nil
        }

        try? pngData.write(to: thumbURL)
        return thumbURL
    }

    private func generateVideoThumbnail(from url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = thumbnailMaxSize
        guard let cgImage = try? generator.copyCGImage(
            at: videoThumbnailTime, actualTime: nil
        ) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: .zero)
    }

    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(
            at: cacheDirectory, withIntermediateDirectories: true
        )
    }
}

extension NSImage {
    func thumbnail(maxSize: CGSize) -> NSImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxSize.width / size.width, maxSize.height / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        guard let rep = bestRepresentation(
            for: NSRect(origin: .zero, size: newSize), context: nil, hints: nil
        ) else {
            return nil
        }
        let thumbnail = NSImage(size: newSize)
        thumbnail.addRepresentation(rep)
        thumbnail.size = newSize
        return thumbnail
    }
}
