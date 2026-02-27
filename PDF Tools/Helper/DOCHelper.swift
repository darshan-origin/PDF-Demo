//
//  DocumentHelper.swift
//  PDF Tools
//
//  Created by mac on 19/02/26.
//

import UIKit
import PDFKit
import Compression
import Foundation
import MessageUI
import CoreText
import CoreXLSX
import WebKit
import PDFCompressorKit
internal import ZIPFoundation

final class DOCHelper {
    
    static let shared = DOCHelper()
    private var activeDelegates = Set<WebViewPDFDelegate>()
    
    /// create a PDF using arrays of UIImage and return a generated PDF Data
    func createPDF(from images: [UIImage], watermark: UIImage? = nil, quality: CGFloat = 0.8, maxDimension: CGFloat = 2560) -> Data? {
        let pdfData = NSMutableData()
        let defaultPageBounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        UIGraphicsBeginPDFContextToData(pdfData, defaultPageBounds, nil)
        
        for image in images {
            autoreleasepool {
                let imageSize = image.size
                var finalRect = CGRect(origin: .zero, size: imageSize)
                
                if imageSize.width > maxDimension || imageSize.height > maxDimension {
                    let ratio = imageSize.width / imageSize.height
                    if ratio > 1 {
                        finalRect.size = CGSize(width: maxDimension, height: maxDimension / ratio)
                    } else {
                        finalRect.size = CGSize(width: maxDimension * ratio, height: maxDimension)
                    }
                }
                
                UIGraphicsBeginPDFPageWithInfo(finalRect, nil)
                
                if let compressedData = image.jpegData(compressionQuality: quality),
                   let compressedImage = UIImage(data: compressedData) {
                    compressedImage.draw(in: finalRect)
                } else {
                    image.draw(in: finalRect)
                }
                
                if let watermark = watermark {
                    let watermarkWidth = finalRect.width * 0.15
                    let watermarkHeight = (watermark.size.height / watermark.size.width) * watermarkWidth
                    let padding: CGFloat = 20
                    let rect = CGRect(x: finalRect.width - watermarkWidth - padding, y: finalRect.height - watermarkHeight - padding, width: watermarkWidth, height: watermarkHeight)
                    watermark.draw(in: rect, blendMode: .normal, alpha: 0.5)
                }
            }
        }
        UIGraphicsEndPDFContext()
        return pdfData as Data
    }
    
    
    /// share a file using file URL using UIActivityViewController
    func shareFile(fileURL: URL, vc: UIViewController) {
        let itemsToShare: [Any] = [fileURL]
        let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = vc.view
        }
        vc.present(activityViewController, animated: true, completion: nil)
    }
    
    /// generate a thumbnail image of the PDF
    func generatePdfThumbnailFromUrl(pdfUrl: URL, thumbnailSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        
        URLSession.shared.dataTask(with: pdfUrl) { data, response, error in
            guard let data = data, error == nil else {
                Logger.print("Error downloading PDF: \(error?.localizedDescription ?? "Unknown error")", level: .error)
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let lastPath = UUID().uuidString
            do {
                try FileStorageManager.store(data, at: lastPath, in: .temporary)
            } catch {
                Logger.print("Error saving PDF data: \(error.localizedDescription)", level: .error)
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let temporaryPdfUrl = FileStorageManager.url(for: lastPath, in: .temporary)
            
            guard let pdfDocument = PDFDocument(url: temporaryPdfUrl),
                  let pdfPage = pdfDocument.page(at: 0) else {
                DispatchQueue.main.async { completion(nil) }
                FileStorageManager.removeFileIfExists(at: "\(temporaryPdfUrl)", in: .temporary)
                return
            }
            
            let thumbnail = pdfPage.thumbnail(of: thumbnailSize, for: .mediaBox)
            
            DispatchQueue.main.async {
                completion(thumbnail)
                FileStorageManager.removeFileIfExists(at: "\(temporaryPdfUrl)", in: .temporary)
            }
        }.resume()
    }
    
    /// generate a thumbnail image of the PDF and return image but in synchronous way
    func generateThumbnailSync(for url: URL) -> UIImage? {
        let pdfDocument = PDFDocument(url: url)
        let page = pdfDocument?.page(at: 0)
        return page?.thumbnail(of: CGSize(width: 100, height: 100), for: .mediaBox)
    }
    
    /// return data of merged PDF using files URL array
    func mergePDFs(from pdfURLs: [URL]) -> Data? {
        let mergedDocument = PDFDocument()
        var pageInsertionIndex = 0
        for pdfURL in pdfURLs {
            guard let sourceDocument = PDFDocument(url: pdfURL) else {
                Logger.print("Error: Could not open source PDF at URL: \(pdfURL.lastPathComponent)", level: .error)
                continue
            }
            
            for pageIndex in 0..<sourceDocument.pageCount {
                if let page = sourceDocument.page(at: pageIndex) {
                    mergedDocument.insert(page, at: pageInsertionIndex)
                    pageInsertionIndex += 1
                }
            }
        }
        return mergedDocument.dataRepresentation()
    }
    
    
    /// return date and time as custome
    func getCustomFormattedDateTime() -> String {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        
        return dateFormatter.string(from: now)
    }
    
    func compressPDFAndZip(from url: URL, completion: @escaping (Data?) -> Void) {
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let originalURL = tempDir.appendingPathComponent("original.pdf")
            let compressedPDFURL = tempDir.appendingPathComponent("compressed.pdf")
            
            do {
                try data.write(to: originalURL)
                guard let pdfDocument = PDFDocument(url: originalURL) else {
                    completion(nil)
                    return
                }
                
                let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
                
                try renderer.writePDF(to: compressedPDFURL) { context in
                    for index in 0..<pdfDocument.pageCount {
                        guard let page = pdfDocument.page(at: index),
                              let cgPage = page.pageRef else { continue }
                        
                        context.beginPage()
                        let cgContext = context.cgContext
                        
                        cgContext.saveGState()
                        
                        let scale: CGFloat = 0.6
                        cgContext.scaleBy(x: scale, y: scale)
                        cgContext.drawPDFPage(cgPage)
                        
                        cgContext.restoreGState()
                    }
                }
                
                let compressedData = try Data(contentsOf: compressedPDFURL)
                let zippedData = compressedData.withUnsafeBytes { (srcBuffer: UnsafeRawBufferPointer) -> Data? in
                    
                    guard let srcBase = srcBuffer.baseAddress else { return nil }
                    
                    let dstSize = compression_encode_scratch_buffer_size(COMPRESSION_ZLIB)
                    let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: compressedData.count)
                    let scratchBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
                    
                    defer {
                        dstBuffer.deallocate()
                        scratchBuffer.deallocate()
                    }
                    
                    let compressedSize = compression_encode_buffer(
                        dstBuffer,
                        compressedData.count,
                        srcBase.assumingMemoryBound(to: UInt8.self),
                        compressedData.count,
                        scratchBuffer,
                        COMPRESSION_ZLIB
                    )
                    
                    guard compressedSize > 0 else { return nil }
                    
                    return Data(bytes: dstBuffer, count: compressedSize)
                }
                
                completion(zippedData)
                
            } catch {
                Logger.print("PDF COMPRESSION: \(error.localizedDescription)", level: LogLevel.error)
                completion(nil)
            }
            
        }.resume()
    }
    
    /// remove  file last path compenete and return only file name
    func fileName(from fileURL: URL) -> String {
        return fileURL.deletingPathExtension().lastPathComponent
    }
    
    /// read txtfile and return string
    func readTextFile(from fileURL: URL) -> String? {
        let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
        defer { if shouldStopAccessing { fileURL.stopAccessingSecurityScopedResource() } }
        
        do {
            let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
            return fileContents
        } catch {
            Logger.print("Error reading file: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
    
    /// generate text to pdf and return pdf as data
    func generatePDFfromText(from text: String) -> Data? {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 40
        let printableRect = pageBounds.insetBy(dx: margin, dy: margin)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let pdfData = renderer.pdfData { (context) in
            var finished = false
            while !finished {
                let textContainer = NSTextContainer(size: printableRect.size)
                layoutManager.addTextContainer(textContainer)
                
                context.beginPage()
                
                let range = layoutManager.glyphRange(for: textContainer)
                layoutManager.drawGlyphs(forGlyphRange: range, at: printableRect.origin)
                _ = layoutManager.glyphRange(for: layoutManager.textContainers.last!)
                if NSMaxRange(range) >= layoutManager.numberOfGlyphs {
                    finished = true
                }
            }
        }
        return pdfData
    }
    
    func extractXLSXData(fileURL: URL) throws -> [[String]] {
        
        var tableData: [[String]] = []
        let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let data = try Data(contentsOf: fileURL)
        let file = try XLSXFile(data: data)
        let sharedStrings = try? file.parseSharedStrings()
        
        for workbook in try file.parseWorkbooks() {
            let sheets = try file.parseWorksheetPathsAndNames(workbook: workbook)
            
            for sheet in sheets {
                let worksheet = try file.parseWorksheet(at: sheet.path)
                
                guard let rows = worksheet.data?.rows else { continue }
                for row in rows {
                    var rowValues: [String] = []
                    for cell in row.cells {
                        
                        if let sharedStrings = sharedStrings,
                           let string = cell.stringValue(sharedStrings) {
                            rowValues.append(string)
                        } else if let inline = cell.inlineString?.text {
                            rowValues.append(inline)
                        } else if let value = cell.value {
                            rowValues.append(value)
                        } else {
                            rowValues.append("")
                        }
                    }
                    
                    tableData.append(rowValues)
                }
            }
        }
        return tableData
    }
    
    
    
    func generatePDFFromTable(data: [[String]]) -> Data? {
        
        let pdfMetaData = [
            kCGPDFContextCreator: "PDF Tools",
            kCGPDFContextAuthor: "PDF Tools"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),format: format)
        let pdfData = renderer.pdfData { context in
            
            context.beginPage()
            let margin: CGFloat = 20
            let rowHeight: CGFloat = 25
            let columnCount = data.first?.count ?? 1
            let columnWidth = (pageWidth - margin * 2) / CGFloat(columnCount)
            var yPosition: CGFloat = margin
            
            for row in data {
                var xPosition: CGFloat = margin
                for cell in row {
                    let rect = CGRect(x: xPosition, y: yPosition, width: columnWidth, height: rowHeight)
                    
                    context.cgContext.stroke(rect)
                    
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .left
                    
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10),
                        .paragraphStyle: paragraphStyle
                    ]
                    
                    let attributedText = NSAttributedString(string: cell,attributes: attributes)
                    attributedText.draw(in: rect.insetBy(dx: 4, dy: 4))
                    xPosition += columnWidth
                }
                
                yPosition += rowHeight
                if yPosition > pageHeight - margin {
                    context.beginPage()
                    yPosition = margin
                }
            }
        }
        
        return pdfData
    }
    
    func generateMultiPagePDF(from webView: WKWebView, completion: @escaping (Result<Data, Error>) -> Void) {
        let a4Width: CGFloat = 595.2
        let a4Height: CGFloat = 841.8
        let paperSize = CGSize(width: a4Width, height: a4Height)
        let formatter = webView.viewPrintFormatter()
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        
        let padding: CGFloat = 20
        let printableRect = CGRect(x: padding, y: padding, width: a4Width - (padding * 2), height: a4Height - (padding * 2))
        let paperRect = CGRect(origin: .zero, size: paperSize)
        
        renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
        
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: paperRect)
        }
        
        UIGraphicsEndPDFContext()
        
        completion(.success(pdfData as Data))
    }
    
    func generatePDF(from fileURL: URL) async -> Data? {
        
        let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(fileURL.lastPathComponent)
        
        do {
            let data = try Data(contentsOf: fileURL)
            try data.write(to: tempFile)
        } catch {
            Logger.print("Failed writing temp file: \(error)", level: .error)
            return nil
        }
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 612, height: 792))
        
        return await withCheckedContinuation { continuation in
            
            var delegate: WebViewPDFDelegate?
            
            delegate = WebViewPDFDelegate(
                webView: webView
            ) { [weak self] pdfData in
                
                continuation.resume(returning: pdfData)
                
                if let delegate = delegate {
                    self?.activeDelegates.remove(delegate)
                }
            }
            
            if let delegate = delegate {
                self.activeDelegates.insert(delegate)
            }
            
            webView.loadFileURL(tempFile, allowingReadAccessTo: tempDir)
        }
    }
    
    /// get total number of page of selected pdf url
    func getPDFPageCount(fileURL: URL) -> Int {
        guard let pdfDocument = PDFDocument(url: fileURL) else {
            Logger.print("Could not load PDF document at \(fileURL)", level: .error)
            return 0
        }
        return pdfDocument.pageCount
    }
    
    
    /// split pdf
    func splitPdfByPageNumbers(sourceURL: URL, pageNumbers: [Int]) -> Data? {
        guard let sourcePDFDocument = PDFDocument(url: sourceURL) else {
            Logger.print("Error: Could not load source PDF document from URL", level: .error)
            return nil
        }
        
        let newPDFDocument = PDFDocument()
        for pageNumber in pageNumbers.sorted() {
            let pageIndex = pageNumber - 1  // convert 1-based to 0-based
            if pageIndex >= 0 && pageIndex < sourcePDFDocument.pageCount {
                if let page = sourcePDFDocument.page(at: pageIndex) {
                    newPDFDocument.insert(page, at: newPDFDocument.pageCount)  // always append
                } else {
                    Logger.print("Could not get page at index \(pageIndex)", level: .warning)
                }
            } else {
                Logger.print("Invalid page number \(pageNumber) (out of range)", level: .warning)
            }
        }
        return newPDFDocument.dataRepresentation()
    }
    
    
    /// set password to pdf
    func encryptPDFInPlace(at pdfURL: URL, pin: String, name: String) -> Bool {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            Logger.print("Failed to load PDF", level: .error)
            return false
        }
        
        let tempURL = pdfURL.deletingLastPathComponent()
            .appendingPathComponent("\(name).pdf")
        
        let options: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: pin,
            .ownerPasswordOption: pin
        ]
        
        guard pdfDocument.write(to: tempURL, withOptions: options) else {
            Logger.print("Failed to encrypt PDF", level: .error)
            return false
        }
        
        do {
            try FileManager.default.removeItem(at: pdfURL)
            try FileManager.default.moveItem(at: tempURL, to: pdfURL)
            Logger.print("PDF encrypted successfully (same URL)", level: .success)
            return true
            
        } catch {
            Logger.print("File replacement failed: \(error)", level: .error)
            return false
        }
    }
    
    func isPDFPasswordProtected(url: URL) -> Bool {
        if let pdfDocument = PDFDocument(url: url) {
            if pdfDocument.isEncrypted {
                if pdfDocument.isLocked {
                    return true
                }
            }
        }
        return false
    }
    
    func removePassword(from url: URL, password: String, name: String) -> URL? {
        
        guard let document = PDFDocument(url: url) else {
            Logger.print("Unable to load PDF", level: .error)
            return nil
        }
        
        if document.isEncrypted {
            let unlocked = document.unlock(withPassword: password)
            if !unlocked {
                Logger.print("Wrong password", level: .warning)
                return nil
            }
        }
        
        let tempURL = url.deletingLastPathComponent().appendingPathComponent("\(name).pdf")
        
        let success = document.write(to: tempURL)
        
        if success {
            do {
                try FileManager.default.removeItem(at: url)
                try FileManager.default.moveItem(at: tempURL, to: url)
                return url
                
            } catch {
                Logger.print("File replace error: \(error)", level: .error)
                return nil
            }
        }
        
        return nil
    }
    
    func compressPDFAndReturnZip(from inputURL: URL, name: String) throws -> Data {
        
        let compressor = PDFCompressor()
        let tempDirectory = FileManager.default.temporaryDirectory
        let compressedPDFURL = tempDirectory.appendingPathComponent("\(name).pdf")
        let zipURL = tempDirectory.appendingPathComponent("\(name).zip")
        
        try compressor.compress(
            inputURL: inputURL,
            outputURL: compressedPDFURL,
            level: .medium
        )
        
        try FileManager.default.zipItem(at: compressedPDFURL, to: zipURL)
        let xipDATA = try Data(contentsOf: zipURL)
        try? FileManager.default.removeItem(at: compressedPDFURL)
        try? FileManager.default.removeItem(at: zipURL)
        
        return xipDATA
    }

    /// compress pdf size and replace with original
    func compressPDF(at url: URL) throws {
        let compressor = PDFCompressor()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        
        try compressor.compress(
            inputURL: url,
            outputURL: tempURL,
            level: .high
        )
        
        try FileStorageManager.delete(at: url)
        try FileStorageManager.move(from: tempURL, to: url)
    }

    
    func unzipFile(fromWhich: URL, destinationURL: URL) {
        let fileManager = FileManager.default
        do {
            try fileManager.unzipItem(at: fromWhich, to: destinationURL.appendingPathComponent("Unzipped Files"))
            Logger.print("Extraction successful to: \(destinationURL.path)", level: .success)
        } catch {
            Logger.print("Extraction Failed", level: .error)
        }
    }
    
    func renameFolder(oldFolderName: String, newFolderName: String) {
        let fileManager = FileManager.default
        
        do {
            let documentsDirectoryURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            
            let oldFolderURL = documentsDirectoryURL.appendingPathComponent(oldFolderName)
            let newFolderURL = documentsDirectoryURL.appendingPathComponent(newFolderName)
            
            if fileManager.fileExists(atPath: oldFolderURL.path) {
                try fileManager.moveItem(at: oldFolderURL, to: newFolderURL)
            }
        } catch {
            Logger.print("Error renaming folder: \(error)", level: .error)
        }
    }
    
    func removePasswordFromPDF(at url: URL, withPassword password: String) -> Bool {
        
        guard let document = PDFDocument(url: url) else {
            Logger.print("Failed to load PDF.", level: .error)
            return false
        }
        
        if document.isLocked {
            let unlocked = document.unlock(withPassword: password)
            if !unlocked {
                Logger.print("Wrong password.", level: .warning)
                return false
            }
        }
        
        let success = document.write(to: url)
        
        if success {
            Logger.print("Password removed successfully from: \(url.lastPathComponent)", level: .success)
        } else {
            Logger.print("Failed to overwrite the PDF file.", level: .error)
        }
        return success
    }
    
    
    func reorderPDF(sourceURL: URL, pageNumbers: [Int]) -> Data? {
        guard let originalDocument = PDFDocument(url: sourceURL) else {
            Logger.print("Failed to load original PDF", level: .error)
            return nil
        }
        let newDocument = PDFDocument()
        for pageNumber in pageNumbers {
            let pageIndex = pageNumber - 1
            if let page = originalDocument.page(at: pageIndex) {
                newDocument.insert(page, at: newDocument.pageCount)
            }
        }
        return newDocument.dataRepresentation()
    }
    
    
    /// convert pdf pages in to images as return type images array
    func convertPDFToImages(pdfURL: URL) -> [UIImage] {
        guard let pdfDocument = PDFDocument(url: pdfURL) else { return [] }
        var images: [UIImage] = []
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(pageRect)
                ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(image)
        }
        return images
    }
    
    
    func extractText(from url: URL) -> String {
        guard let pdf = PDFDocument(url: url) else { return "" }
        var text = ""
        
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i),
               let pageText = page.string {
                text += pageText + "\n"
            }
        }
        return text
    }
    
    func saveCSV(rows: [[String]], to url: URL) {
        var csvString = ""
        
        for row in rows {
            csvString += row.joined(separator: ",") + "\n"
        }   
        try? csvString.write(to: url, atomically: true, encoding: .utf8)
    }
}
