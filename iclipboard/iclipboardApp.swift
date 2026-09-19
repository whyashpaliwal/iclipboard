//
//  iclipboardApp.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26
//

import SwiftUI

@main
struct iclipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("iclipboard", systemImage: "doc.on.clipboard") {
            Button("Toggle Clipboard") {
                appDelegate.toggleHUD()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
