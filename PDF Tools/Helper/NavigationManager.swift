//
//  NavigationManager.swift
//  PDF Tools
//
//  Created by mac on 17/02/26.
//

import UIKit

class NavigationManager {
    static let shared = NavigationManager()
    
    private init() {}
    
    func navigateTo(storyboardName: String, vcIdentifier: String, from: UIViewController) {
        let storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: vcIdentifier)
        from.navigationController?.pushViewController(vc, animated: true)
    }
    
    func navigateToCropDocVC(img: UIImage?, imgs: [UIImage]?, from: UIViewController) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CropDocumentVC") as! CropDocumentVC
        vc.capturedCameraImage = img ?? UIImage()
        vc.selectedPassedImages = imgs ?? []
        from.navigationController?.pushViewController(vc, animated: true)
    }
    
    func popViewController(from: UIViewController) {
        from.navigationController?.popViewController(animated: true)
    }
    
    func popROOTViewController(from: UIViewController) {
        from.navigationController?.popToRootViewController(animated: true)
    }
    
    func navigateToExportVC(from: UIViewController, imgs: [UIImage], name: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ExportDocumentPopupVC") as! ExportDocumentPopupVC
        vc.modalTransitionStyle = .crossDissolve
        vc.modalPresentationStyle = .overFullScreen
        vc.fileName = name
        vc.finalGenrableImages = imgs
        from.navigationController?.present(vc, animated: true)
    }
    
    func navigateToPDFViewVC(from: UIViewController, url: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "DocumentGenSuccessVC") as! DocumentGenSuccessVC
        vc.pdfURL = url
        from.navigationController?.pushViewController(vc, animated: true)
    }
    
    func navigateToMErgePDFVC(from: UIViewController, isSplit: Bool, isOrganize: Bool,count: Int?, pdfURL: URL?, url: [FilesMetaDataModel]?) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MergeVC") as! MergeVC
        vc.filesArray = url!
        vc.isSplit = isSplit
        vc.pdfPageCount = count!
        vc.fileURL = pdfURL
        vc.isOrganize = isOrganize
        from.navigationController?.pushViewController(vc, animated: true)
    }
    
    func navigateToDocViewVC(from: UIViewController, url: URL, type: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SelectedDocViewerVC") as! SelectedDocViewerVC
        vc.fileURL = url
        vc.type = type
        from.navigationController?.pushViewController(vc, animated: true)
    }
    
    func navigateToWebViewVC(from: UIViewController) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "WebViewVC") as! WebViewVC
        from.navigationController?.pushViewController(vc, animated: true)
    }
    
    func navigateToMarkTagVC(from: UIViewController, index: Int, selectedColor: UIColor?, completion: @escaping (UIColor?) -> Void) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MarkTagVC") as! MarkTagVC
        vc.modalTransitionStyle = .crossDissolve
        vc.modalPresentationStyle = .overCurrentContext
        vc.selectedColor = selectedColor
        vc.onColorSelected = completion
        from.present(vc, animated: true)
    }

    func navigateToDocReaderVC(from: UIViewController, url: URL) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "DocReaderVC") as! DocReaderVC
        vc.url = url
        from.navigationController?.pushViewController(vc, animated: true)
    }

    func navigateToInfoVC(from: UIViewController, creationDate: String, size: Int64, name: String, page: String) {
        let storyborad = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyborad.instantiateViewController(withIdentifier: "FileInfoVC") as! FileInfoVC
        vc.modalTransitionStyle = .crossDissolve
        vc.modalPresentationStyle = .overCurrentContext
        vc.created = creationDate
        vc.fileSize = size
        vc.name = name
        vc.pages = page
        from.present(vc, animated: true)
    }
    
}
