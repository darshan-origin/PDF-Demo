//
//  HomeVC.swift
//  PDF Tools
//
//  Created by mac on 17/02/26.
//

import UIKit
import LocalAuthentication

class HomeVC: UIViewController, UIDocumentPickerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        authenticateUser()
    }
    
    @IBAction func onTapped_scan(_ sender: Any) {
        PermissionManager.shared.requestCameraPermission { granted in
            if granted {
                Logger.print("Camera Allowed", level: .success)
                NavigationManager.shared.navigateTo(storyboardName: "Main", vcIdentifier: "CameraHandlerVC", from: self)
            } else {
                Logger.print("Camera Denied", level: .error)
                PermissionManager.shared.openSettings()
            }
        }
    }
    
    @IBAction func onTapped_textToPdf(_ sender: Any) {
        DocumentPickerHelper.openDoc(type: .txt, from: self) { selectedURL in
            if let url = selectedURL {
                Logger.print("Completion URL: \(url)", level: .success)
                NavigationManager.shared.navigateToDocViewVC(from: self, url: url, type: "TXT")
            }
        }
    }
    
    @IBAction func onTapped_xlsxToPdf(_ sender: Any) {
        DocumentPickerHelper.openDoc(type: .xlsx, from: self) { selectedURL in
            if let url = selectedURL {
                Logger.print("Completion URL: \(url)", level: .success)
                NavigationManager.shared.navigateToDocViewVC(from: self, url: url, type: "XLSX")
            }
        }
    }
    
    @IBAction func onTapped_webToPdf(_ sender: Any) {
        NavigationManager.shared.navigateToWebViewVC(from: self)
    }
    
    @IBAction func onTapped_wordsToPdf(_ sender: Any) {
        DocumentPickerHelper.openDoc(type: .words, from: self) { selectedURL in
            if let url = selectedURL {
                Logger.print("Completion URL: \(url)", level: .success)
                NavigationManager.shared.navigateToDocViewVC(from: self, url: url, type: "DOCX")
            }
        }
    }
    
    @IBAction func onTapped_pptToPdf(_ sender: Any) {
        DocumentPickerHelper.openDoc(type: .pptx, from: self) { selectedURL in
            if let url = selectedURL {
                Logger.print("Completion URL: \(url)", level: .success)
                NavigationManager.shared.navigateToDocViewVC(from: self, url: url, type: "PPT")
            }
        }
    }
    
    @IBAction func onTapped_PDFto_IMAGES(_ sender: Any) {
        DocumentPickerHelper.openDoc(type: .pdf, from: self) { selectedURL in
            if let url = selectedURL {
                Logger.print("Completion URL: \(url)", level: .success)
                NavigationManager.shared.navigateToDocViewVC(from: self, url: url, type: "PDF_IMG")
            }
            
        }
    }
    
    @IBAction func onTapped_DOCviewer(_ sender: Any) {
        DocumentPickerHelper.openDoc(type: .all, from: self) { url in
            NavigationManager.shared.navigateToDocReaderVC(from: self, url: url!)
        }
    }
}

extension HomeVC {
    func authenticateUser() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            
            let reason = "Use Face ID to unlock the app"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        print("Authentication successful")
                    } else {
                        print("Authentication failed")
                    }
                }
            }
        } else {
            print("Biometric authentication not available")
        }
    }
}
