//
//  ContentView.swift
//  iclipboard

import SwiftUI

struct ContentView: View {
    @State private var isPresented = false
    @State private var clips: [[String: String]] = []
    @State private var searchText = ""
    
    var body: some View {
        if isPresented {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(.ultraThinMaterial)
                    
                    Button("Close") { isPresented = false }
                        .buttonStyle(.bordered)
                }
                .padding(8)
                
                List(clips) { clip in
                    HStack {
                        Button(isPinned(clip) ? "Unpin" : "Pin") {
                            // Toggle pin - would need to modify clips array
                        }
                        .buttonStyle(.borderless)
                        
                        Text(clip["text", default: ""] .prefix(30) .description)
                        
                        Button("Del", role: .destructive) { /* remove */ }
                            .buttonStyle(.borderless)
                    }
                }
                .listStyle(.plain)
            }
            .frame(width: 400, height: 300)
        }
    }
    
    func isPinned(_ clip: [String: String]) -> Bool {
        clip["isPinned", default: "false"] == "true"
    }
}