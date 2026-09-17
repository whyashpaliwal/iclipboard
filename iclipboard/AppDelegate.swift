//
//  AppDelegate.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26

import Cocoa
import SwiftUI
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var floatingPanel: NSWindow?
    var hotKeyMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupHotKeyMonitor()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cleanupHotKeyMonitor()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed() -> Bool {
        true
    }
    
    @objc func toggleFloatingPanel() {
        if floatingPanel == nil {
            let contentRect = NSRect(x: 0, y: 0, width: 400, height: 300)
            floatingPanel = NSWindow(contentRect: contentRect,
                                     styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                                     backing: .buffered, defer: false)
            floatingPanel?.level = .floating
            floatingPanel?.isOpaque = false
            floatingPanel?.backgroundColor = .clear
            floatingPanel?.hasShadow = true
            floatingPanel?.center()
            floatingPanel?.makeKeyAndOrderFront(nil)
        } else {
            floatingPanel?.orderOut(nil)
            floatingPanel = nil
        }
    }
    
    private func setupHotKeyMonitor() {
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command),
               event.modifierFlags.contains(.shift),
               event.keyCode == 13 {
                self.toggleFloatingPanel()
            }
        }
    }
    
    private func cleanupHotKeyMonitor() {
        if let monitor = hotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}