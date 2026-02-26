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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
        generateThumbnail()
    }
    
    @IBAction func onTapped_open(_ sender: Any) {
        let previewVC = PDFViewVC(url: URL(string: pdfURL)!)
        let nav = UINavigationController(rootViewController: previewVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)

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
            if let url = URL(string: pdfURL) {
                let size = CGSize(width: 1024, height: 1024)
                DOCHelper.shared.generatePdfThumbnailFromUrl(pdfUrl: url, thumbnailSize: size) { thumbnailImage in
                    if let thumbnail = thumbnailImage {
                        Logger.print("Thumbnail generated successfully!", level: .success)
                        self.img_thumbImage.image = thumbnail
                    } else {
                        Logger.print("Failed to generate thumbnail.", level: .error)
                    }
                }
            }
        }
    }
}
