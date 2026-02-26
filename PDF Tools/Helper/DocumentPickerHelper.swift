//
//  Untitled.swift
//  PDF Tools
//
//  Created by mac on 20/02/26.
//

import UIKit
import UniformTypeIdentifiers

final class DocumentPickerHelper: NSObject {
    
    private static var pickerCompletion: ((URL?) -> Void)?
    
    static func openDoc(
        type: FileType,
        from viewController: UIViewController,
        completion: ((URL?) -> Void)? = nil
    ) {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [type.contentType]
        )
        
        documentPicker.allowsMultipleSelection = false
        documentPicker.delegate = self.shared
        pickerCompletion = completion
        viewController.present(documentPicker, animated: true)
    }
    
    private static let shared = DocumentPickerHelper()
}

extension DocumentPickerHelper: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        guard let url = urls.first else {
            Self.pickerCompletion?(nil)
            return
        }
        
        Logger.print("Selected File Name: \(url.lastPathComponent)", level: .success)
        
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            Logger.print("Selected File Data Size: \(data.count) bytes", level: .success)
        } catch {
            Logger.print("Failed to read file data: \(error.localizedDescription)", level: .error)
        }
        
        Self.pickerCompletion?(url)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Logger.print("Document Picker Cancelled", level: .debug)
        Self.pickerCompletion?(nil)
    }
}
