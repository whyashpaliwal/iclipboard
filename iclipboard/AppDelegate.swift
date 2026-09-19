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
    
    private let accessibilityManager = AccessibilityManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let currentPID = NSRunningApplication.current.processIdentifier
        let runningApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.yashpaliwal.iclipboard"
        )
        guard !runningApps.contains(where: { $0.processIdentifier != currentPID }) else {
            NSApplication.shared.terminate(nil)
            return
        }

        // Check accessibility permissions on launch
        _ = accessibilityManager.checkAccessibility()
        
        // Only set up hotkey monitor if accessibility is granted
        // (The hotkey monitor requires accessibility permissions to work globally)
        if accessibilityManager.isAccessibilityGranted {
            setupHotKeyMonitor()
        }
        
        // Observe accessibility status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityStatusChanged(_:)),
            name: NSNotification.Name("AccessibilityStatusChanged"),
            object: nil
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cleanupHotKeyMonitor()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed() -> Bool {
        true
    }
    
    @objc func toggleFloatingPanel() {
        // Only allow toggling if accessibility is granted
        guard AccessibilityManager.shared.isAccessibilityGranted else {
            // Show the floating panel with accessibility prompt
            showAccessibilityPrompt()
            return
        }
        
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
    
    private func showAccessibilityPrompt() {
        // Create a panel with the accessibility prompt content
        let contentRect = NSRect(x: 0, y: 0, width: 440, height: 280)
        let promptPanel = NSWindow(contentRect: contentRect,
                                    styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                                    backing: .buffered, defer: false)
        promptPanel.level = .floating
        promptPanel.isOpaque = false
        promptPanel.backgroundColor = .clear
        promptPanel.hasShadow = true
        promptPanel.center()
        
        // Host the accessibility prompt view
        let promptView = AccessibilityPromptView(onOpenSettings: {
            AccessibilityManager.shared.openAccessibilitySettings()
        })
        promptPanel.contentView = NSHostingView(rootView: promptView)
        
        promptPanel.makeKeyAndOrderFront(nil)
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
    
    @objc private func accessibilityStatusChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            if AccessibilityManager.shared.isAccessibilityGranted {
                // Accessibility granted - set up hotkey monitor if not already set up
                if self.hotKeyMonitor == nil {
                    self.setupHotKeyMonitor()
                }
            } else {
                // Accessibility revoked - clean up hotkey monitor
                self.cleanupHotKeyMonitor()
            }
        }
    }
}

// SwiftUI view for the accessibility prompt
import SwiftUI

struct AccessibilityPromptView: View {
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Heading
            Text("Accessibility Access Required")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            // Description
            Text("iclipboard needs Accessibility permissions to listen to the global shortcut (Command + Shift + V) and automatically paste text into your active apps.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Open Settings button
            Button(action: {
                AccessibilityManager.shared.openAccessibilitySettings()
            }) {
                Text("Open System Settings")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            
            // Note
            Text("After enabling, return to iclipboard - it will automatically detect the permission.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 440, height: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
}