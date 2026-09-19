//
//  ContentView.swift
//  iclipboard
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var monitor: ClipboardMonitor
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @State private var searchText = ""
    private let onClose: (() -> Void)?

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }
    
    private var filteredClips: [ClipboardItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return monitor.history
        } else {
            return monitor.history.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(.ultraThinMaterial)
                
                Button("Close") {
                    onClose?()
                }
                .buttonStyle(.bordered)
            }
            .padding(8)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredClips) { clip in
                        HStack {
                            Text(clip.text.prefix(30).description)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button("Del", role: .destructive) {
                                monitor.removeItem(clip)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .padding(2)
            }
        }
        .frame(width: 400, height: 300)
    }
}
