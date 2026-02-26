//
//  PDFViewVC.swift
//  PDF Tools
//
//  Created by mac on 19/02/26.
//

import UIKit
import PDFKit

class PDFViewVC: UIViewController {
    
    private let pdfURL: URL
    private let pdfView = PDFView()
    
    init(url: URL) {
        self.pdfURL = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPDF()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = true
        view.addSubview(pdfView)
        
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        setupNavigation()
    }
    
    private func setupNavigation() {
        title = "Preview"
        
        if navigationController?.viewControllers.first == self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeTapped)
            )
        }
    }
    
    private func loadPDF() {
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            Logger.print("File not found at path: \(pdfURL.path)", level: .error)
            return
        }

        do {
            let rawData = try Data(contentsOf: pdfURL)
            var finalData = rawData
            let header = String(data: rawData.prefix(10), encoding: .ascii) ?? ""
            
            if header.starts(with: "%PDF-") {
                Logger.print("Format: Raw Binary PDF", level: .info)
            } else if header.contains("JVBERi") {
                Logger.print("Format: Base64 String. Decoding...", level: .info)
                if let b64String = String(data: rawData, encoding: .utf8),
                   let decodedData = Data(base64Encoded: b64String, options: .ignoreUnknownCharacters) {
                    finalData = decodedData
                }
            }
            if let document = PDFDocument(data: finalData) {
                pdfView.document = document
                Logger.print("Successfully loaded PDF", level: .info)
            } else {
                Logger.print("Failed to initialize PDFDocument", level: .error)
            }
        } catch {
            Logger.print("Error reading file: \(error.localizedDescription)", level: .error)
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

