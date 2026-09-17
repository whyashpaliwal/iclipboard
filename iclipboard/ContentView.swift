//
//  ContentView.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26.

import SwiftUI
import Foundation

// MARK: - Supporting Types

struct HUDItemId: Hashable {
    let id: UUID
}

extension ClipboardItem {
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var monitor = ClipboardMonitor.shared
    @State private var searchText = ""
    @State private var isPresented = false
    
    var body: some View {
        if isPresented {
            HUDView(isPresented: $isPresented, searchText: $searchText, isClearAllVisible: $isClearAllVisible, items: monitor.recentItems)
        }
    }
}

// MARK: - HUD View

// MARK: - HUD View

struct HUDView: View {
    @Binding var isPresented: Bool
    @Binding var searchText: String
    @Binding var isClearAllVisible: Bool
    @Namespace private var animation
    
    let items: [ClipboardItem]
    
    // Filtered items based on search
    var filteredItems: [ClipboardItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { item in
            item.text.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Separate pinned and unpinned
    var pinnedItems: [ClipboardItem] {
        filteredItems.filter { $0.isPinned }
    }
    
    var unpinnedItems: [ClipboardItem] {
        filteredItems.filter { !$0.isPinned }
    }
    
    // Pin icon name based on state
    func pinImageForItem(_ item: ClipboardItem) -> String {
        item.isPinned ? "pin.fill" : "pin"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search field
            HUDSearchField(text: $searchText, isClearAllVisible: $isClearAllVisible)
            
            // Divider when search is active
            if !searchText.isEmpty {
                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            
            // Pinned section
            if !pinnedItems.isEmpty {
                HUDSectionHeader(title: "Pinned", animation: animation)
                HUDItemList(items: pinnedItems, animation: animation, isPinned: true)
                    .padding(.bottom, 4)
            }
            
            // Unpinned section
            if !unpinnedItems.isEmpty {
                HUDSectionHeader(title: "Recent", animation: animation)
                HUDItemList(items: unpinnedItems, animation: animation, isPinned: false)
            }
            
            // Clear All button (only show when there are unpinned items to clear)
            if !unpinnedItems.isEmpty && isClearAllVisible {
                HUDClearAllButton {
                    monitor.clearUnpinned()
                    withAnimation { isClearAllVisible = false }
                }
                .transition(.opacity)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HUDBackground())
        .cornerRadius(16)
        .shadow(radius: 8, x: 0, y: 4)
        .padding(16)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isClearAllVisible = true } }
    }
}

// MARK: - HUD Subviews

struct HUDSearchField: View {
    @Binding var text: String
    @Binding var isClearAllVisible: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 18, height: 18)
                
                TextField("Search clips...", text: $text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .textFieldStyle(.plain)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .onChange(of: text) { _, newValue in
                if newValue.isEmpty {
                    withAnimation { isClearAllVisible = false }
                }
            }
            
            if !text.isEmpty {
                Button("Clear") {
                    // Clear search only
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.blue)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct HUDSectionHeader: View {
    let title: String
    let animation: Namespace.ID
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 2)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HUDItemList: View {
    let items: [ClipboardItem]
    let animation: Namespace.ID
    let isPinned: Bool
    
    var body: some View {
        ForEach(items) { item in
            HUDItemCard(item: item, animation: animation)
        }
    }
}

struct HUDItemCard: View {
    let item: ClipboardItem
    let animation: Namespace.ID
    @State private var isHovered = false
    @Namespace private var cardAnimation
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Pin button
            Button(action { togglePin(item) }) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 10))
                    .foregroundColor(item.isPinned ? .yellow : .primary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            
            // Text preview
            VStack(alignment: .leading, spacing: 2) {
                Text(itemText(item))
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(item.formattedTimestamp)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            
            // Delete button
            Button(action { deleteItem(item) }) {
                Image(systemName: "multiply.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor).opacity(isHovered ? 0.3 : 0.15))
                .matchedGeometryEffect(id: "card_\(item.id)", in: animation)
        )
        .cornerRadius(12)
        .onHover { isHovered in withAnimation { self.isHovered = isHovered } }
        .onTapGesture { copyItem(item) }
    }
    
    // Extract just the text preview (first 3 lines worth)
    func itemText(_ item: ClipboardItem) -> String {
        guard !item.text.isEmpty else { return "(empty)" }
        let preview = String(item.text.prefix(3))
        // If the original text has newlines, limit to about 3 lines worth
        let components = preview.components(separatedBy: "\n")
        if components.count > 3 {
            return components[0..<3].joined(separator: "\n")
        }
        return preview
    }
    
    // MARK: - Actions
    
    private func togglePin(_ item: ClipboardItem) {
        AppDelegate.shared.togglePin(item)
        withAnimation(.easeInOut(duration: 0.2)) {
            // We update the model via the AppDelegate shared method
        }
    }
    
    private func deleteItem(_ item: ClipboardItem) {
        monitor.removeItem(item)
    }
    
    private func copyItem(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        
        // Synthesize Cmd+V to auto-paste
        CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true)?.post(.cghidpanetap)
        CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)?.post(.cghidpanetap)
        
        // Close HUD after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation { isPresented = false }
        }
    }
}

struct HUDBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
    }
}

struct HUDClearAllButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("Clear All Unpinned")
                    .font(.system(size: 10, weight: .medium))
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 9))
            }
            .padding(6)
            .background(.regularMaterial)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AppDelegate Extensions for Clipboard Management

extension AppDelegate {
    static func togglePin(_ item: ClipboardItem) {
        if let idx = ClipboardMonitor.shared.recentItems.firstIndex(where: { $0.id == item.id }) {
            ClipboardMonitor.shared.recentItems[idx].isPinned.toggle()
            ClipboardMonitor.shared.saveItems()
        }
    }
    
    static func removeItem(_ item: ClipboardItem) {
        ClipboardMonitor.shared.removeItem(item)
    }
}



