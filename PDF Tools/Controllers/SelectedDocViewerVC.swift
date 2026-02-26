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
        Logger.print("Received type >>>>> \(type)", level: .info)
        ThreadManager.shared.main { [self] in
            initUI()
            if type == "TXT" {
                readTxtFile()
            } else if type == "XLSX" {
                readXlsxFile()
            } else if type == "DOCX" {
                readWordsFile()
            } else if type == "PPT" {
                readPPTFile()
            } else if type == "PDF_IMG" {
                btn_save.setTitle("Make PPT", for: .normal)
                readPDF()
            }
        }
    }
    
    @IBAction func onTapped_back(_ sender: Any) {
        NavigationManager.shared.popViewController(from: self)
    }
    
    @IBAction func onTapped_makePDF(_ sender: Any) {
        if type == "TXT" {
            generatePDFfromTXT()
        } else if type == "XLSX" {
            generatePDFfromXLSX()
        } else if type == "DOCX" {
            generatePDFfromDOCX()
        } else if type == "PPT" {
            generatePDF()
        } else if type == "PDF_IMG" {
            generateIMG_PDF()
        }
    }
}

extension SelectedDocViewerVC {
    
    func initUI() {
        lbl_selectedFileName.text = fileURL?.lastPathComponent
    }
    
    // MARK: - TXT
    func readTxtFile() {
        if let fileText =  DOCHelper.shared.readTextFile(from: fileURL!) {
            txtView_txtFileViewer.text = fileText
        } else {
            txtView_txtFileViewer.text = "Could not read file content."
        }
    }
    
    func generatePDFfromTXT() {
        ThreadManager.shared.background {
            Task {
                let textData = DOCHelper.shared.generatePDFfromText(from: self.txtView_txtFileViewer.text ?? "")
                let fetchTimeAndDataForFileName = DOCHelper.shared.getCustomFormattedDateTime()
                try FileStorageManager.store(textData, at: "\(fetchTimeAndDataForFileName).pdf", in: .documents)
                Logger.print("PDF saved successfully at >>>>>> \(String(describing: textData))", level: .success)
                let fileURL = FileStorageManager.url(for: "\(fetchTimeAndDataForFileName).pdf", in: .documents)
                Logger.print("Final stored pdf url: >>>>>> \(fileURL)", level: .success)
                
                ThreadManager.shared.main {
                    NavigationManager.shared.navigateToPDFViewVC(from: self, url: "\(fileURL)")
                }
            }
        }
    }
    
    // MARK: - XLSX
    func readXlsxFile() {
        do {
            extractedTableData = try DOCHelper.shared.extractXLSXData(fileURL: fileURL!)
            Logger.print("Data Extracted. Rows: \(extractedTableData.count)" ,level: .success)
        } catch {
            Logger.print("Extraction failed: \(error)", level: .error)
        }
    }
    
    func generatePDFfromXLSX() {
        ThreadManager.shared.background { [self] in
            Task {
                guard !extractedTableData.isEmpty else {
                    Logger.print("No data available. Please pick an excel file first", level: .warning)
                    return
                }
                
                let fetchTimeAndDataForFileName = DOCHelper.shared.getCustomFormattedDateTime()
                let pdfData = DOCHelper.shared.generatePDFFromTable(data: extractedTableData)
                
                try FileStorageManager.store(pdfData, at: "\(fetchTimeAndDataForFileName).pdf", in: .documents)
                Logger.print("PDF saved successfully at >>>>>> \(String(describing: pdfData))", level: .success)
                
                let fileURL = FileStorageManager.url(for: "\(fetchTimeAndDataForFileName).pdf", in: .documents)
                Logger.print("Final stored pdf: >>>>>> \(fileURL)", level: .success)
                
                ThreadManager.shared.main {
                    NavigationManager.shared.navigateToPDFViewVC(from: self, url: "\(fileURL)")
                }
            }
        }
    }
    
    
    // MARK: - DOCX
    func readWordsFile() {
        previewManager.showPreview(from: self, with: fileURL!)
    }
    
    // MARK: - PPT
    func readPPTFile() {
        previewManager.showPreview(from: self, with: fileURL!)
    }
    
    func generatePDF() {
        Task {
            if let pdfData = await DOCHelper.shared.generatePDF(from: fileURL!) {
                let fileName = DOCHelper.shared.getCustomFormattedDateTime()
                do {
                    try FileStorageManager.store(pdfData, at: "\(fileName).pdf", in: .documents)
                    let finalURL = FileStorageManager.url(for: "\(fileName).pdf",in: .documents)
                    Logger.print("PDF Generated successfully: \(String(describing: fileURL))", level: .success)
                    await MainActor.run {
                        NavigationManager.shared.navigateToPDFViewVC(from: self,url: "\(finalURL)")
                    }
                    
                } catch {
                    Logger.print("Failed saving PDF: \(error)", level: .error)
                }
            }
        }
    }
    
    
    // MARK: - PDF
    
    func readPDF() {
        previewManager.showPreview(from: self, with: fileURL!)
    }
    
    func generateIMG_PDF() {
        ThreadManager.shared.background {
            let data = DOCHelper.shared.convertPDFToImages(pdfURL: self.fileURL!)
            if let urls = FileStorageManager.saveImagesToDocuments(images: data) {
                print("Saved at:", urls)
                ThreadManager.shared.main {
                    NavigationManager.shared.popROOTViewController(from: self)
                }
            }
        }
    }
}

extension SelectedDocViewerVC {
    
    func generatePDFfromDOCX() {
        guard let url = fileURL else { return }
        let isScoped = url.startAccessingSecurityScopedResource()
        
        do {
            let fileData = try Data(contentsOf: url)
            if isScoped { url.stopAccessingSecurityScopedResource() }
            let cacheFolder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let localURL = cacheFolder.appendingPathComponent("temp_convert.docx")
            try fileData.write(to: localURL, options: .atomic)
            setupAndLoadWebView(with: localURL)
            
        } catch {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }
    }

    private func setupAndLoadWebView(with url: URL) {
        if self.webView != nil {
            self.webView?.removeFromSuperview()
        }
        
        let wv = WKWebView(frame: self.view.bounds)
        wv.navigationDelegate = self
        wv.alpha = 0.01
        self.view.addSubview(wv)
        self.webView = wv
        
        let request = URLRequest(url: url)
        wv.load(request)
    }
    
    private func createMultiPagePDF() {
        guard let wv = self.webView else { return }
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let printableRect = pageRect.insetBy(dx: 20, dy: 20)
        let renderer = UIPrintPageRenderer()
        let formatter = wv.viewPrintFormatter()
        
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: pageRect)
        }
        
        UIGraphicsEndPDFContext()
        wv.removeFromSuperview()
        self.webView = nil
        saveOrHandlePDF(pdfData as Data)
    }
    
    func saveOrHandlePDF(_ data: Data) {
        let fileName = DOCHelper.shared.getCustomFormattedDateTime()
        let fullFileName = "\(fileName).pdf"
        
        do {
            try FileStorageManager.store(data, at: fullFileName, in: .documents)
            let finalURL = FileStorageManager.url(for: fullFileName, in: .documents)
            
            Logger.print("PDF Generated successfully", level: .success)
            
            ThreadManager.shared.main {
                NavigationManager.shared.navigateToPDFViewVC(from: self, url: finalURL.absoluteString)
            }
            
        } catch {
            Logger.print("Failed saving PDF: \(error)", level: .error)
        }
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
