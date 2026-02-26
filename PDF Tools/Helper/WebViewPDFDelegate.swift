import WebKit

final class WebViewPDFDelegate: NSObject, WKNavigationDelegate {
    
    private let completion: (Data?) -> Void
    private weak var webView: WKWebView?
    
    init(webView: WKWebView,
         completion: @escaping (Data?) -> Void) {
        
        self.webView = webView
        self.completion = completion
        super.init()
        
        webView.navigationDelegate = self
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let printableRect = CGRect(x: 36, y: 36, width: 540, height: 720)
        
        let formatter = webView.viewPrintFormatter()
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        
        UIGraphicsEndPDFContext()
        
        completion(pdfData as Data)
        cleanup()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.print("webView didFail: \(error.localizedDescription)", level: .error)
        completion(nil)
        cleanup()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.print("webView didFailProvisionalNavigation: \(error.localizedDescription)", level: .error)
        completion(nil)
        cleanup()
    }
    
    private func cleanup() {
        webView?.navigationDelegate = nil
        webView = nil
    }
    
    // MARK: - Hashable (needed for Set storage)
    
    static func == (lhs: WebViewPDFDelegate, rhs: WebViewPDFDelegate) -> Bool {
        lhs === rhs
    }
}
