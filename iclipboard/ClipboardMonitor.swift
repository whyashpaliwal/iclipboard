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

        guard let newText = NSPasteboard.general.string(forType: .string) else { return }
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
