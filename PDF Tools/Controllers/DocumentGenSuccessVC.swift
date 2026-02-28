//
//  DocumentGenSuccessVC.swift
//  PDF Tools
//
//  Created by mac on 19/02/26.
//

import UIKit
import PDFKit

class DocumentGenSuccessVC: UIViewController {
    
    @IBOutlet weak var img_thumbImage: UIImageView!
    @IBOutlet weak var lbl_pdfName: UILabel!
    
    var pdfURL = ""
    let previewManager = PreviewManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
        generateThumbnail()
    }
    
    @IBAction func onTapped_open(_ sender: Any) {
        guard let url = URL(string: pdfURL) else { return }
        if url.pathExtension.lowercased() == "pdf" {
            let previewVC = PDFViewVC(url: url)
            let nav = UINavigationController(rootViewController: previewVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        } else {
            previewManager.showPreview(from: self, with: url)
        }
    }
    
    @IBAction func onTapped_share(_ sender: Any) {
        DOCHelper.shared.shareFile(fileURL: URL(string: pdfURL)!, vc: self)
    }
    
    @IBAction func onTappeD_back(_ sender: Any) {
        NavigationManager.shared.popROOTViewController(from: self)
    }
}

extension DocumentGenSuccessVC {
    func initUI() {
        ThreadManager.shared.main { [self] in
            lbl_pdfName.text = "\(URL(string: pdfURL)!.lastPathComponent)"
            img_thumbImage.layer.borderColor = UIColor.red.cgColor
            img_thumbImage.layer.borderWidth = 5
        }
    }
    
    func generateThumbnail() {
        ThreadManager.shared.main { [self] in
            guard let url = URL(string: pdfURL) else { return }
            let size = CGSize(width: 1024, height: 1024)
            
            if url.pathExtension.lowercased() == "pdf" {
                DOCHelper.shared.generatePdfThumbnailFromUrl(pdfUrl: url, thumbnailSize: size) { thumbnailImage in
                    if let thumbnail = thumbnailImage {
                        self.img_thumbImage.image = thumbnail
                    }
                }
            } else if url.pathExtension.lowercased() == "docx" || url.pathExtension.lowercased() == "pptx" {
                // For DOCX/PPTX, showing a generic icon
                self.img_thumbImage.image = UIImage(systemName: url.pathExtension.lowercased() == "pptx" ? "doc.richtext.fill" : "doc.text.fill")
                self.img_thumbImage.tintColor = url.pathExtension.lowercased() == "pptx" ? .systemOrange : .systemBlue
                self.img_thumbImage.contentMode = .scaleAspectFit
            }
        }
    }
}
