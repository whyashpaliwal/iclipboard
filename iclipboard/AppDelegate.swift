//
//  AppDelegate.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26
//

import Cocoa
import CoreGraphics
import Foundation
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var hudPanel: HUDPanel?
    private let hotKeyManager = CarbonHotKeyManager.shared
    private let clipboardMonitor = ClipboardMonitor.shared
    private let accessibilityManager = AccessibilityManager.shared
    private var previousActiveApp: NSRunningApplication?
    
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

        // Check accessibility status silently without prompting
        accessibilityManager.checkAccessibility()
        clipboardMonitor.startMonitoring()
        hotKeyManager.register(onPressed: { [weak self] in
            self?.toggleHUD()
        })
        
        // Continuously track the frontmost working application
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != NSRunningApplication.current.processIdentifier {
            previousActiveApp = front
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
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

    @objc private func workspaceDidActivateApplication(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if app.processIdentifier != NSRunningApplication.current.processIdentifier,
           app.activationPolicy == .regular {
            previousActiveApp = app
        }
    }
    
    @objc func toggleHUD() {
        // Capture previous active application before presenting HUD
        if hudPanel?.isVisible != true {
            if let frontmost = NSWorkspace.shared.frontmostApplication,
               frontmost.processIdentifier != NSRunningApplication.current.processIdentifier,
               frontmost.activationPolicy == .regular {
                previousActiveApp = frontmost
            }
        }

        if hudPanel == nil {
            let panel = HUDPanel()
            panel.contentView = NSHostingView(
                rootView: ContentView(
                    onClose: { [weak self] in
                        self?.hudPanel?.orderOut(nil)
                    },
                    onPaste: { [weak self] item in
                        self?.pasteAndDismiss(item)
                    }
                )
                .environmentObject(clipboardMonitor)
            )
            hudPanel = panel
        }
        
        hudPanel?.toggleHUD()
    }

    func pasteAndDismiss(_ item: ClipboardItem) {
        // 1. Write the item (text, image, video, or file) back to NSPasteboard.general
        PasteboardMediaHandler.shared.write(item)

        // 2. Immediately dismiss the HUD panel
        hudPanel?.orderOut(nil)

        // 3. Reactivate the target application if needed
        let targetApp = self.previousActiveApp ?? NSWorkspace.shared.runningApplications.first(where: {
            $0.activationPolicy == .regular &&
            $0.processIdentifier != NSRunningApplication.current.processIdentifier &&
            !$0.isTerminated
        })

        if let target = targetApp, target != NSWorkspace.shared.frontmostApplication {
            NSApp.deactivate()
            target.activate(options: [.activateIgnoringOtherApps])
        }

        // 4. Dispatch synthesized Cmd + V after a short delay for focus stability
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let source = CGEventSource(stateID: .combinedSessionState)
            source?.setLocalEventsFilterDuringSuppressionState(
                [.permitLocalMouseEvents, .permitSystemDefinedEvents],
                state: .eventSuppressionStateSuppressionInterval
            )

            let vKeyCode: CGKeyCode = 9 // Virtual key for 'V' (kVK_ANSI_V)

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else { return }

            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand

            // Post to active session and HID tap
            keyDown.post(tap: .cgAnnotatedSessionEventTap)
            keyUp.post(tap: .cgAnnotatedSessionEventTap)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
