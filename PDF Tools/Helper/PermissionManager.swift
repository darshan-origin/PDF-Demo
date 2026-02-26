//
//  PermissionManager.swift
//  PDF Tools
//
//  Created by mac on 17/02/26.
//

import Foundation
import AVFoundation
import Photos
import CoreLocation
import UIKit

class PermissionManager {
    static let shared = PermissionManager()
    private init() {}

    // 1. Camera
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    // 2. Photo Library
    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async { completion(status == .authorized) }
        }
    }

    // 3. Open Settings if denied
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
