//
//  ContentView.swift
//  iclipboard

import SwiftUI

struct ContentView: View {
    @State private var isPresented = false
    @State private var clips: [String] = []
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
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(clips, id: \ .self) { clip in
                        HStack {
                            Button("Pin") { /* toggle pin */ }
                                .buttonStyle(.borderless)
                            
                            Text(clip .prefix(30) .description)
                            
                            Button("Del", role: .destructive) { /* remove */ }
                                .buttonStyle(.borderless)
                        }
                    }
                    .padding(2)
                }
            }
            .frame(width: 400, height: 300)
        }
    }
}