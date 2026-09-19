//
//  FloatingPanel.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26.
//

import Carbon
import Cocoa

final class HUDPanel: NSPanel {
    private var resignObserver: NSObjectProtocol?

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: backingStoreType,
            defer: flag
        )
        setupPanel()
    }

    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 340, height: 460)
        self.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
    }

    private func setupPanel() {
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        becomesKeyOnlyIfNeeded = false
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.orderOut(nil)
        }
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    deinit {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
    }

    func toggleHUD() {
        if isVisible {
            orderOut(nil)
        } else {
            positionNearCursor()
            makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func toggle() {
        toggleHUD()
    }

    func hide() {
        orderOut(nil)
    }

    private func positionNearCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = activeScreen else {
            center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let minimumX = visibleFrame.minX
        let maximumX = max(minimumX, visibleFrame.maxX - frame.width)
        let minimumY = visibleFrame.minY
        let maximumY = max(minimumY, visibleFrame.maxY - frame.height)

        let origin = NSPoint(
            x: min(max(mouseLocation.x - (frame.width / 2), minimumX), maximumX),
            y: min(max(mouseLocation.y - (frame.height / 2), minimumY), maximumY)
        )
        setFrameOrigin(origin)
    }
}

final class CarbonHotKeyManager {
    static let shared = CarbonHotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var eventHandler: EventHandlerUPP?
    private var onPressed: (() -> Void)?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x484B3031), id: 1)

    private init() {}

    private static let carbonHotKeyHandler: EventHandlerUPP = { _, _, userData in
        guard let userData else {
            return OSStatus(eventNotHandledErr)
        }

        let manager = Unmanaged<CarbonHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        DispatchQueue.main.async {
            manager.onPressed?()
        }
        return noErr
    }

    func register(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed

        guard eventHandlerRef == nil else {
            return
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        eventHandler = CarbonHotKeyManager.carbonHotKeyHandler

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandler,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            eventHandler = nil
            return
        }

        // Keycode: 9 ('V' key, kVK_ANSI_V), Modifiers: cmdKey | shiftKey
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard hotKeyStatus == noErr else {
            unregister()
            return
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }

        eventHandler = nil
        onPressed = nil
    }

    deinit {
        unregister()
    }
}
