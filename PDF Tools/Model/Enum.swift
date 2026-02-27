//
//  Enum.swift
//  PDF Tools
//
//  Created by mac on 20/02/26.
//

import Foundation
import UniformTypeIdentifiers


public enum FileAction: String, CaseIterable {
    case rename = "Rename"
    case delete = "Delete"
    case setPassword = "Set Password"
    case merge = "Merge"
    case split = "Split"
    case organize = "Organize"
    case copy = "Copy & Paste"
    case move = "Move"
    case info = "Info"
    case compress = "Compress"
    case duplicate = "Duplicate"
    case email = "Email"
    case share = "Share"
    case markTag = "Mark with color tag"
    
    var isDestructive: Bool { self == .delete }
}

public enum FilterAction: String, CaseIterable {
    case createdDate = "Create Date"
    case az = "A - Z"
    case za = "Z - A"
    case size = "Size"
}

enum FileType {
    case all
    case txt
    case pdf
    case image
    case xlsx
    case words
    case pptx
    
    var contentType: UTType {
        switch self {
        case .all:
            return .item   // Allows all file types
        case .txt:
            return .plainText
        case .pdf:
            return .pdf
        case .image:
            return .image
        case .xlsx:
            return .spreadsheet
        case .words:
            return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .pptx:
            return UTType("org.openxmlformats.presentationml.presentation") ?? .presentation
        }
    }
}

enum WorkItem {
    case file(FilesMetaDataModel)
    case folder(FolderModel)
}

enum EditableViewMode {
    case general
    case date
}
