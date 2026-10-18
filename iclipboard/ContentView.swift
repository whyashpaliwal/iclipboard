//
//  ContentView.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26
//

import Cocoa
import CoreGraphics
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var monitor: ClipboardMonitor
    @Environment(\.colorScheme) private var colorScheme
    private let onClose: (() -> Void)?
    private let onPaste: ((ClipboardItem) -> Void)?

    init(onClose: (() -> Void)? = nil, onPaste: ((ClipboardItem) -> Void)? = nil) {
        self.onClose = onClose
        self.onPaste = onPaste
    }

    private var glassBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.08)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Glass Header
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)

                Text("Clipboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text("\(monitor.history.count) / 10")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        Capsule()
                            .stroke(glassBorderColor, lineWidth: 0.5)
                    )

                Spacer()

                HeaderClearButton(isDisabled: monitor.history.isEmpty) {
                    monitor.clearHistory()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Scrollable Cards or Empty State
            if monitor.history.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.04))
                            .frame(width: 60, height: 60)
                            .blur(radius: 8)

                        Image(systemName: "tray")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.secondary.opacity(0.7))
                    }

                    Text("No clipboard clips yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(monitor.history) { item in
                            LiquidGlassCardView(item: item) {
                                pasteItem(item)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(width: 340, height: 460)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            LinearGradient(
                colors: [Color.white.opacity(0.18), Color.white.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(glassBorderColor, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
    }

    private func pasteItem(_ item: ClipboardItem) {
        if let onPaste = onPaste {
            onPaste(item)
        } else {
            // Fallback implementation
            _ = PasteboardMediaHandler.shared.write(item)

            onClose?()
            NSApp.deactivate()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let source = CGEventSource(stateID: .combinedSessionState)
                let vKeyCode: CGKeyCode = 9 // Virtual key code for 'V'

                guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
                      let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else { return }

                keyDown.flags = .maskCommand
                keyUp.flags = .maskCommand

                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
                keyDown.post(tap: .cgAnnotatedSessionEventTap)
                keyUp.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }
}

// MARK: - Header Clear Button
struct HeaderClearButton: View {
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                Text("Clear")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isDisabled ? .secondary.opacity(0.4) : (isHovered ? .primary : .secondary))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isHovered && !isDisabled ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Liquid Glass Card
struct LiquidGlassCardView: View {
    let item: ClipboardItem
    let onSelect: () -> Void
    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                if let thumbnail = thumbnail, item.type != .text {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if item.type != .text {
                    Text(item.text)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(item.text)
                        .font(.system(size: 13, weight: .regular))
                        .lineLimit(3)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Spacer()
                    if item.type != .text {
                        Text(item.type.rawValue.capitalized)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Text(relativeTimeString(from: item.timestamp))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(GlassCardButtonStyle(isHovered: $isHovered))
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))

                if isHovered {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isHovered ? Color.white.opacity(0.28) : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
                .shadow(
                    color: isHovered ? Color.white.opacity(0.25) : Color.clear,
                    radius: isHovered ? 4 : 0
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isHovered = hovering
            }
        }
        .onAppear(perform: loadThumbnail)
    }

    private func loadThumbnail() {
        guard let url = item.thumbnailURL else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let image = NSImage(contentsOf: url)
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 5 {
            return "Just now"
        } else if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            let minutes = max(1, seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = max(1, seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = max(1, seconds / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Glass Card Button Style
struct GlassCardButtonStyle: ButtonStyle {
    @Binding var isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : (isHovered ? 1.015 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
    }
}
