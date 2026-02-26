import UIKit
import MessageUI

final class MailHelper: NSObject {
    
    static let shared = MailHelper()
    
    private override init() {}
    
    func shareFileViaMail(
        fileURL: URL,
        from viewController: UIViewController,
        subject: String = "Shared File",
        body: String = "Please find the attached file."
    ) {
        
        guard MFMailComposeViewController.canSendMail() else {
            Logger.print(("Mail services are not available"), level: .warning)
            return
        }
        
        guard let fileData = try? Data(contentsOf: fileURL) else {
            Logger.print("Unable to read file data", level: .warning)
            return
        }
        
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(body, isHTML: false)
        
        let mimeType = mimeTypeForPath(fileURL.path)
        mailComposer.addAttachmentData(fileData,
                                       mimeType: mimeType,
                                       fileName: fileURL.lastPathComponent)
        
        viewController.present(mailComposer, animated: true)
    }
    
    private func mimeTypeForPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "pdf":
            return "application/pdf"
        case "zip":
            return "application/zip"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        default:
            return "application/octet-stream"
        }
    }
}

extension MailHelper: MFMailComposeViewControllerDelegate {
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
