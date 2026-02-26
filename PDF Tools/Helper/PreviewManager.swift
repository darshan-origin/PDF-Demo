//
//  PreviewManager.swift
//  PDF Tools
//
//  Created by mac on 23/02/26.
//

import UIKit
import QuickLook

class PreviewManager: NSObject, QLPreviewControllerDataSource {
    
    var fileURL: URL?

    func showPreview(from controller: UIViewController, with url: URL) {
        self.fileURL = url
        
        let previewController = QLPreviewController()
        previewController.dataSource = self
        
        // Present the previewer
        controller.present(previewController, animated: true, completion: nil)
    }

    // MARK: - QLPreviewControllerDataSource

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return fileURL != nil ? 1 : 0
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return fileURL! as QLPreviewItem
    }
}
