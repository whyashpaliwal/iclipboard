//
//  ClipboardItem.swift
//  iclipboard
//
//  Created by Yash Paliwal on 12/09/26
//

import Foundation

enum ClipboardItemType: String, Codable, CaseIterable {
    case text
    case image
    case video
    case file
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date

    let type: ClipboardItemType
    let fileURL: URL?
    let cachedURL: URL?
    let thumbnailURL: URL?
    let mimeType: String?
    let size: Int64?

    init(id: UUID = UUID(), text: String = "", timestamp: Date = Date(),
         type: ClipboardItemType = .text, fileURL: URL? = nil,
         cachedURL: URL? = nil, thumbnailURL: URL? = nil,
         mimeType: String? = nil, size: Int64? = nil) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.type = type
        self.fileURL = fileURL
        self.cachedURL = cachedURL
        self.thumbnailURL = thumbnailURL
        self.mimeType = mimeType
        self.size = size
    }
}
