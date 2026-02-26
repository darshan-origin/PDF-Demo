import UIKit
import QuickLook

class DocReaderVC: UIViewController {

    var url: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        previewFile()
    }
    
    private func previewFile() {
        guard url != nil else { return }
        
        let vc = QLPreviewController()
        vc.dataSource = self
        vc.delegate = self
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
}

extension DocReaderVC: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return url == nil ? 0 : 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return url! as NSURL
    }
    
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        navigationController?.popViewController(animated: true)
         NavigationManager.shared.popROOTViewController(from: self)
    }
}
