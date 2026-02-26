//
//  Model.swift
//  PDF Tools
//
//  Created by mac on 17/02/26.
//
import UIKit
import Foundation

struct CameraViewFeatures {
    let title: String
    let isSelected: Bool
}

struct EffectFeatures {
    let title: String
    let icon: UIImage
}

struct FilesMetaDataModel {
    let url: URL
    let name: String
    let thumbnail: UIImage?
    let size: Int64?
    let creationDate: Date?
    let sizeAndTime: String?
    let folderData: [FolderModel]?
    var isProtected: Bool
    var tagColor: UIColor?
}

struct FolderModel {
    let name: String
    let url: URL
    let size: Int64
}
