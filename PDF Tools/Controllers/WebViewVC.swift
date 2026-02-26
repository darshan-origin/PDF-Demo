//
//  WebViewVC.swift
//  PDF Tools
//
//  Created by mac on 23/02/26.
//

import UIKit
import WebKit

class WebViewVC: UIViewController {
    
    @IBOutlet weak var webView: WKWebView!
    
    @IBOutlet weak var view_topNAv: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configwebView()
    }
    
    @IBAction func onTapped_back(_ sender: Any) {
        NavigationManager.shared.popROOTViewController(from: self)
    }
    
    @IBAction func onTapped_generatePDF(_ sender: Any) {
        genratePDF()
    }
}

extension WebViewVC {
    func configwebView() {
        ThreadManager.shared.main { [self] in
            let urlString = "https://www.google.com"
            if let url = URL(string: urlString) {
                let request = URLRequest(url: url)
                webView.load(request)
                webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Logger.print("Webview is now loaded, now it able to generate PDF", level: .success)
    }
    
    func genratePDF() {
        ThreadManager.shared.main { [self] in
            DOCHelper.shared.generateMultiPagePDF(from: webView) { result in
                switch result {
                case .success(let pdfData):
                    Logger.print("PDF Generated. Size: \(pdfData.count)", level: .success)
                    ThreadManager.shared.background {
                        Task {
                            let fetchTimeAndDataForFileName = DOCHelper.shared.getCustomFormattedDateTime()
                            try FileStorageManager.store(pdfData, at: "\(fetchTimeAndDataForFileName).pdf", in: .documents)
                            Logger.print("PDF saved successfully at >>>>>> \(String(describing: pdfData))", level: .success)
                            let fileURL = FileStorageManager.url(for: "\(fetchTimeAndDataForFileName).pdf", in: .documents)
                            Logger.print("FINAL STORED PDF URL: >>>>>> \(fileURL)", level: .success)
                            
                            ThreadManager.shared.main {
                                NavigationManager.shared.navigateToPDFViewVC(from: self, url: "\(fileURL)")
                            }

                        }
                    }
                    
                case .failure(let error):
                    Logger.print("PDF Error: \(error)", level: .error)
                }
            }
        }
    }
}
