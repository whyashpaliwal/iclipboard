//
//  AppDelegate.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26
//

import Cocoa
import SwiftUI
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var hudPanel: HUDPanel?
    private let hotKeyManager = CarbonHotKeyManager.shared
    private let clipboardMonitor = ClipboardMonitor.shared
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

        _ = accessibilityManager.checkAccessibility()
        clipboardMonitor.startMonitoring()
        hotKeyManager.register(onPressed: { [weak self] in
            self?.toggleHUD()
        })
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityStatusChanged(_:)),
            name: NSNotification.Name("AccessibilityStatusChanged"),
            object: nil
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        clipboardMonitor.stopMonitoring()
        hudPanel?.orderOut(nil)
        hudPanel = nil
    }
    
    func applicationShouldTerminateAfterLastWindowClosed() -> Bool {
        true
    }
    
    @objc func toggleHUD() {
        if hudPanel == nil {
            let panel = HUDPanel()
            panel.contentView = NSHostingView(
                rootView: ContentView(onClose: { [weak self] in
                    self?.hudPanel?.orderOut(nil)
                })
                .environmentObject(clipboardMonitor)
            )
            hudPanel = panel
        }
        
        hudPanel?.toggleHUD()
    }
    
    private func showAccessibilityPrompt() {
        let promptPanel = HUDPanel()
        promptPanel.contentView = NSHostingView(rootView: AccessibilityPromptView(onOpenSettings: {
            AccessibilityManager.shared.openAccessibilitySettings()
        }))
        promptPanel.contentView?.frame = promptPanel.contentView?.bounds ?? .zero
        promptPanel.toggleHUD()
    }
    
    @objc private func accessibilityStatusChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            if AccessibilityManager.shared.isAccessibilityGranted {
                _ = self.accessibilityManager.checkAccessibility()
            }
        }
    }
}

// SwiftUI view for the accessibility prompt
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
