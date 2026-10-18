//
//  ClipboardMonitor.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26
//

import Cocoa
import Combine
import Foundation

final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published var history: [ClipboardItem] = []
    @Published var isMonitoring = false

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let defaultsKey = "savedClipboardHistory"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadSavedHistory()
        self.lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount

        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }

    func checkForChanges() {
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        let pasteboard = NSPasteboard.general

        // Rich media takes priority; falls back to plain text otherwise.
        if let candidate = detectMedia(from: pasteboard) {
            processMedia(candidate)
            return
        }

        // Existing text-only logic (unchanged).
        guard let newText = pasteboard.string(forType: .string) else { return }
        processNewText(newText)
    }

    func processNewText(_ text: String) {
        // Ignore empty text and whitespace-only strings
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let performUpdate = { [weak self] in
            guard let self = self else { return }

            // Ignore text matching history.first?.text
            guard text != self.history.first?.text else { return }

            // If the text already exists lower in the history list, remove that older duplicate
            self.history.removeAll { $0.text == text }

            // Insert the new ClipboardItem at index 0 (top)
            let newItem = ClipboardItem(text: text)
            self.history.insert(newItem, at: 0)

            // Strictly enforce a 10-item limit: if history.count > 10, drop the oldest entry from the bottom
            while self.history.count > 10 {
                self.history.removeLast()
            }

            self.saveHistory()
        }

        if Thread.isMainThread {
            performUpdate()
        } else {
            DispatchQueue.main.async(execute: performUpdate)
        }
    }

    /// Detects rich media on the pasteboard (files copied from Finder or image
    /// data copied from a browser). Text-only pasteboards return nil.
    private enum MediaCandidate {
        case file(url: URL, mimeType: String)
        case image(image: NSImage, mimeType: String)
    }

    private func detectMedia(from pasteboard: NSPasteboard) -> MediaCandidate? {
        guard let types = pasteboard.types else { return nil }

        // 1. Files copied from Finder (PNG, HEIC, MOV, MP4, etc.)
        if types.contains(.fileURL) {
            let urls = pasteboard.readObjects(
                forClasses: [NSURL.self], options: nil
            ) as? [URL] ?? []
            if let url = urls.first {
                let mime = mimeType(for: url)
                if mime.hasPrefix("image/") || mime.hasPrefix("video/") {
                    return .file(url: url, mimeType: mime)
                }
            }
        }

        // 2. Image data copied directly (e.g. from a web browser)
        if let image = NSImage(pasteboard: pasteboard) {
            let mime: String
            if types.contains(.png) {
                mime = "image/png"
            } else if types.contains(.tiff) {
                mime = "image/tiff"
            } else {
                mime = "image/png"
            }
            return .image(image: image, mimeType: mime)
        }

        return nil
    }

    /// Processes a media candidate on a background queue so the main thread
    /// is never blocked by file I/O, thumbnail generation, or video frame extraction.
    private func processMedia(_ candidate: MediaCandidate) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let item: ClipboardItem

            switch candidate {
            case .file(let url, let mimeType):
                let isVideo = mimeType.hasPrefix("video/")
                let result = MediaCacheManager.shared.cacheMedia(
                    originalURL: url, mimeType: mimeType
                )
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
                item = ClipboardItem(
                    text: url.lastPathComponent,
                    type: isVideo ? .video : .image,
                    fileURL: url,
                    cachedURL: result.cachedURL,
                    thumbnailURL: result.thumbnailURL,
                    mimeType: mimeType,
                    size: size
                )

            case .image(let image, let mimeType):
                let result = MediaCacheManager.shared.cacheImage(
                    image, mimeType: mimeType
                )
                let size = (try? result.cachedURL.resourceValues(
                    forKeys: [.fileSizeKey]
                ))?.fileSize.map(Int64.init) ?? 0
                item = ClipboardItem(
                    text: "Image",
                    type: .image,
                    cachedURL: result.cachedURL,
                    thumbnailURL: result.thumbnailURL,
                    mimeType: mimeType,
                    size: size
                )
            }

            DispatchQueue.main.async {
                self.insertMediaItem(item)
            }
        }
    }

    private func insertMediaItem(_ item: ClipboardItem) {
        guard item != history.first else { return }
        history.removeAll { $0.text == item.text && $0.type == item.type }
        history.insert(item, at: 0)
        while history.count > 10 {
            history.removeLast()
        }
        saveHistory()
    }

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "tiff", "tif": return "image/tiff"
        case "heic", "heif": return "image/heic"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "mov": return "video/quicktime"
        case "mp4", "m4v": return "video/mp4"
        case "avi": return "video/x-msvideo"
        case "mkv": return "video/x-matroska"
        default: return "application/octet-stream"
        }
    }

    func removeItem(_ item: ClipboardItem) {
        let performUpdate = { [weak self] in
            guard let self = self else { return }
            self.history.removeAll { $0.id == item.id }
            self.saveHistory()
        }

        if Thread.isMainThread {
            performUpdate()
        } else {
            DispatchQueue.main.async(execute: performUpdate)
        }
    }

    func clearHistory() {
        let performUpdate = { [weak self] in
            guard let self = self else { return }
            self.history.removeAll()
            self.saveHistory()
        }

        if Thread.isMainThread {
            performUpdate()
        } else {
            DispatchQueue.main.async(execute: performUpdate)
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            userDefaults.set(data, forKey: defaultsKey)
        } catch {
            print("Failed to encode clipboard history: \(error)")
        }
    }

    private func loadSavedHistory() {
        guard let data = userDefaults.data(forKey: defaultsKey) else { return }
        do {
            let items = try JSONDecoder().decode([ClipboardItem].self, from: data)
            self.history = Array(items.prefix(10))
        } catch {
            print("Failed to decode clipboard history: \(error)")
        }
    }

    deinit {
        stopMonitoring()
    }
}
