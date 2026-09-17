//
//  ClipboardMonitor.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26

import Foundation
import Cocoa
import Combine

final class ClipboardMonitor: ObservableObject {
    // MARK: - Shared Instance
    
    static let shared = ClipboardMonitor()
    
    // Published properties for SwiftUI observation
    @Published var recentItems: [ClipboardItem] = []
    @Published var isMonitoring = false
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let defaultsKey = "savedClipboardItems"
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        timer?.tolerance = 0.2
    }
    
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        if let newString = NSPasteboard.general.string(forType: .string), !newString.isEmpty {
            addItem(text: newString)
        }
    }
    
    private func addItem(text: String) {
        // Skip if identical to last item
        if let last = recentItems.first, last.text == text { return }
        
        let newItem = ClipboardItem(text: text)
        recentItems.insert(newItem, at: 0)
        
        // Keep only last 50 items
        if recentItems.count > 50 {
            recentItems.removeLast(recentItems.count - 50)
        }
        
        saveItems()
        objectWillChange.send()
    }
    
    private func saveItems() {
        let encoded = recentItems.map { item -> [String: Any] in
            [
                "id": item.id.uuidString,
                "text": item.text,
                "isPinned": item.isPinned
            ]
        }
        UserDefaults.standard.set(encoded, forKey: defaultsKey)
    }
    
    private func loadSavedItems() {
        guard let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [[String: Any]] else { return }
        recentItems = saved.compactMap { dict in
            guard let id = UUID(uuidString: dict["id"] as? String ?? ""),
                  let text = dict["text"] as? String else { return nil }
            return ClipboardItem(id: id, text: text, isPinned: dict["isPinned"] as? Bool ?? false)
        }
    }
    
    func removeItem(_ item: ClipboardItem) {
        recentItems.removeAll { $0.id == item.id }
        saveItems()
        objectWillChange.send()
    }
    
    func togglePin(_ item: ClipboardItem) {
        if let index = recentItems.firstIndex(where: { $0.id == item.id }) {
            recentItems[index].isPinned.toggle()
            saveItems()
            objectWillChange.send()
        }
    }
    
    func clearUnpinned() {
        recentItems.removeAll { !$0.isPinned }
        saveItems()
        objectWillChange.send()
    }
}