//
//  SelectedDocViewer.swift
//  PDF Tools
//
//  Created by mac on 20/02/26.
//

import UIKit
import QuickLook
import WebKit

class SelectedDocViewerVC: UIViewController {
    
    @IBOutlet weak var lbl_selectedFileName: UILabel!
    @IBOutlet weak var txtView_txtFileViewer: UITextView!
    @IBOutlet weak var btn_save: UIButton!
    
    var fileURL = URL(string: "")
    var extractedTableData: [[String]] = []
    var type = ""
    let previewManager = PreviewManager()
    private var pickedDocumentData: Data?
    private var webView: WKWebView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        lbl_selectedFileName.text = fileURL?.lastPathComponent
        if type == "PDF_IMG" { btn_save.setTitle("Make PPT", for: .normal) }
        
        switch type {
        case "TXT": if let t = DOCHelper.shared.readTextFile(from: fileURL!) { txtView_txtFileViewer.text = t }
        case "XLSX": try? extractedTableData = DOCHelper.shared.extractXLSXData(fileURL: fileURL!)
        case "DOCX", "PPT", "PDF_IMG": previewManager.showPreview(from: self, with: fileURL!)
        default: break
        }
    }
    
    @IBAction func onTapped_back(_ sender: Any) { NavigationManager.shared.popViewController(from: self) }
    
    @IBAction func onTapped_makePDF(_ sender: Any) {
        switch type {
        case "TXT": generatePDFfromTXT()
        case "XLSX": generatePDFfromXLSX()
        case "DOCX": generatePDFfromDOCX()
        case "PPT": generatePPTToPDF()
        case "PDF_IMG": convertPDFToImages()
        default: break
        }
    }
}

extension SelectedDocViewerVC {
    func generatePDFfromTXT() {
        performAction { DOCHelper.shared.generatePDFfromText(from: self.txtView_txtFileViewer.text ?? "") }
    }
    
    func generatePDFfromXLSX() {
        guard !extractedTableData.isEmpty else { return }
        performAction { DOCHelper.shared.generatePDFFromTable(data: self.extractedTableData) }
    }
    
    func generatePPTToPDF() {
        Task { if let data = await DOCHelper.shared.generatePDF(from: fileURL!) { self.saveAndOpenPDF(data) } }
    }
    
    func convertPDFToImages() {
        ThreadManager.shared.background {
            if FileStorageManager.saveImagesToDocuments(images: DOCHelper.shared.convertPDFToImages(pdfURL: self.fileURL!)) != nil {
                ThreadManager.shared.main { NavigationManager.shared.popROOTViewController(from: self) }
            }
        }
    }

    private func performAction(_ action: @escaping () -> Data?) {
        ThreadManager.shared.background {
            guard let data = action() else { return }
            ThreadManager.shared.main { self.saveAndOpenPDF(data) }
        }
    }

    func saveAndOpenPDF(_ data: Data) {
        let name = "\(DOCHelper.shared.getCustomFormattedDateTime()).pdf"
        do {
            try FileStorageManager.store(data, at: name, in: .documents)
            let url = FileStorageManager.url(for: name, in: .documents)
            NavigationManager.shared.navigateToPDFViewVC(from: self, url: "\(url)")
        } catch { Logger.print("Save failed: \(error)", level: .error) }
    }
}

extension SelectedDocViewerVC {
    
    func generatePDFfromDOCX() {
        guard let url = fileURL else { return }
        let isScoped = url.startAccessingSecurityScopedResource()
        if let data = try? Data(contentsOf: url) {
            if isScoped { url.stopAccessingSecurityScopedResource() }
            let localURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("temp.docx")
            try? data.write(to: localURL)
            webView?.removeFromSuperview()
            let wv = WKWebView(frame: view.bounds); wv.navigationDelegate = self; wv.alpha = 0.01
            view.addSubview(wv); self.webView = wv; wv.load(URLRequest(url: localURL))
        } else if isScoped { url.stopAccessingSecurityScopedResource() }
    }

    private func createMultiPagePDF() {
        guard let wv = webView else { return }
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792), renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(wv.viewPrintFormatter(), startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: pageRect.insetBy(dx: 20, dy: 20)), forKey: "printableReact")
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, pageRect, nil)
        for i in 0..<renderer.numberOfPages { UIGraphicsBeginPDFPage(); renderer.drawPage(at: i, in: pageRect) }
        UIGraphicsEndPDFContext(); wv.removeFromSuperview(); self.webView = nil
        saveAndOpenPDF(data as Data)
    }
}

extension SelectedDocViewerVC: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.createMultiPagePDF()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.print("Navigation failed: \(error.localizedDescription)", level: .error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.print("Provisional failure: \(error.localizedDescription)", level: .error)
    }
}
