//
//  ClipboardItem.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26
//

import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    
    init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}
