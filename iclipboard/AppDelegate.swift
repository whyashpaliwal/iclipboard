//
//  AppDelegate.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26

import Cocoa
import SwiftUI
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {

    private var floatingPanel: FloatingPanel?
    private var keyMonitor: Any?
    private var clipboardMonitor: ClipboardMonitor?
    private var escapeMonitor: Any?
    
    static var shared: AppDelegate {
        NSApp.delegate as! AppDelegate
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupClipboardMonitor()
        registerHotKeyMonitor()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleFloatingPanel),
            name: .toggleFloatingPanel,
            object: nil
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKeyMonitor()
        unregisterClipboardMonitor()
        floatingPanel?.orderOut(nil)
    }
    
    @objc func handleToggleFloatingPanel() {
        if floatingPanel == nil || !floatingPanel!.isPresented {
            floatingPanel = FloatingPanel()
            floatingPanel?.orderFrontRegardless()
            floatingPanel?.show()
        } else {
            floatingPanel?.hide()
            floatingPanel = nil
        }
    }
    
    // MARK: - Hotkey Setup
    
    private func registerHotKeyMonitor() {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  event.modifierFlags.contains(.command),
                  event.modifierFlags.contains(.shift),
                  event.keyCode == 13 else { return }
            
            NotificationCenter.default.post(name: .toggleFloatingPanel, object: nil)
        }
        
        // Escape key to dismiss
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  event.keyCode == 53 else { return } // Escape key
            self?.floatingPanel?.orderOut(nil)
            self?.floatingPanel = nil
        }
    }
    
    private func unregisterHotKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let escapeMonitor = escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
    }
    
    // MARK: - Clipboard Monitor Setup
    
    private func setupClipboardMonitor() {
        clipboardMonitor = ClipboardMonitor()
        clipboardMonitor?.startMonitoring()
    }
    
    private func unregisterClipboardMonitor() {
        clipboardMonitor?.stopMonitoring()
        clipboardMonitor = nil
    }
}