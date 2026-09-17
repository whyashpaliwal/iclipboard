//
//  FloatingPanel.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26.

import Cocoa

final class FloatingPanel: NSPanel {

    var isPresented: Bool {
        get { _isPresented }
        set { _isPresented = newValue }
    }
    private var _isPresented = false

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        setupPanel()
    }
    
convenience init() {
        let screen = NSScreen.main
        guard let screen = screen else {
            self.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView], backing: .buffered, defer: false)
            return
        }
        let contentRect = NSRect(
            x: screen.frame.midX - 400 / 2,
            y: screen.frame.midY - 300 / 2,
            width: 400,
            height: 300
        )
        self.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView], backing: .buffered, defer: false)
    }
    
    private func setupPanel() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        
        styleMask = [.nonactivatingPanel, .borderless, .fullSizeContentView]
        collectionBehavior = .canJoinAllSpaces
        
        ignoresMouseEvents = false
        
        backgroundColor = NSColor.clear
        
        self.delegate = self
    }
    
    deinit {
        HotKeyManager.shared.unregisterHotKey()
    }
    
    func show() {
        orderFrontRegardless()
        isPresented = true
        
        centerOnActiveScreenOrCursor()
        
        makeKeyAndOrderFront(nil)
        
        becomeFirstResponder()
    }
    
    func hide() {
        orderOut(self)
        isPresented = false
    }
    
    func centerOnActiveScreenOrCursor() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        let cursorPosition = NSEvent.mouseLocation
        let isCursorInScreen = cursorPosition.x >= screenFrame.minX && cursorPosition.x <= screenFrame.maxX && cursorPosition.y >= screenFrame.minY && cursorPosition.y <= screenFrame.maxY
        
        var centerPoint: NSPoint
        
        if isCursorInScreen {
            centerPoint = cursorPosition
        } else {
            centerPoint = NSPoint(x: screenFrame.midX, y: screenFrame.midY)
        }
        
        let panelWidth = frame.width
        let panelHeight = frame.height
        let x = centerPoint.x - panelWidth / 2
        let y = centerPoint.y - panelHeight / 2
        
        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}

extension FloatingPanel: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        orderOut(self)
        _isPresented = false
    }
}

final class HotKeyManager {
    static let shared = HotKeyManager()
    
    private init() {}
    
    func registerHotKey() {}
    func unregisterHotKey() {}
    func handleHotKey() {
        NotificationCenter.default.post(name: .toggleFloatingPanel, object: nil)
    }
}

extension Notification.Name {
    static let toggleFloatingPanel = Notification.Name("toggleFloatingPanel")
}