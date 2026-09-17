//
//  ClipboardItem.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26

import Foundation

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let text: String
    var isPinned: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), text: String, isPinned: Bool = false, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isPinned = isPinned
        self.timestamp = timestamp
    }
}