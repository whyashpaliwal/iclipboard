//
//  AccessibilityManager.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26
//

import Foundation
import ApplicationServices
import SwiftUI
import Combine

final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published var isAccessibilityGranted: Bool = false
    
    private var pollingTimer: Timer?
    
    private init() {
        checkAccessibility()
    }
    
    @discardableResult
    func checkAccessibility() -> Bool {
        // Check silently without triggering system permission dialogs
        let isTrusted = AXIsProcessTrusted()
        
        DispatchQueue.main.async {
            self.isAccessibilityGranted = isTrusted
        }
        
        if isTrusted {
            stopPolling()
        } else {
            startPolling()
        }
        
        return isTrusted
    }
    
    private func startPolling() {
        guard pollingTimer == nil else { return }
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let isTrusted = AXIsProcessTrusted()
            
            DispatchQueue.main.async {
                if self.isAccessibilityGranted != isTrusted {
                    self.isAccessibilityGranted = isTrusted
                    
                    if isTrusted {
                        self.stopPolling()
                    }
                }
            }
        }
        
        if let timer = pollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
