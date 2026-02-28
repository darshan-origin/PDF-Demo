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
        let shouldStopAccessing = pdfURL.startAccessingSecurityScopedResource()
        defer { if shouldStopAccessing { pdfURL.stopAccessingSecurityScopedResource() } }
        
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
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer { if shouldStopAccessing { url.stopAccessingSecurityScopedResource() } }
        
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

    func generateDOCXFromPDF(at url: URL) -> Data? {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer { if shouldStopAccessing { url.stopAccessingSecurityScopedResource() } }
        
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        var pagesData: [PDFFidelityPage] = []
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let blocks = extractTextBlocks(from: page)
            let background = renderPageBackground(page: page, excluding: blocks)
            pagesData.append(PDFFidelityPage(background: background, textBlocks: blocks, size: page.bounds(for: .mediaBox).size))
        }
        
        return createEditableDOCX(pages: pagesData)
    }

    func generatePPTXFromPDF(at url: URL) -> Data? {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer { if shouldStopAccessing { url.stopAccessingSecurityScopedResource() } }
        
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        var pagesData: [PDFFidelityPage] = []
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let blocks = extractTextBlocks(from: page)
            let background = renderPageBackground(page: page, excluding: blocks)
            pagesData.append(PDFFidelityPage(background: background, textBlocks: blocks, size: page.bounds(for: .mediaBox).size))
        }
        
        return createEditablePPTX(pages: pagesData)
    }

    private struct PDFFidelityPage {
        let background: UIImage
        let textBlocks: [PDFTextBlock]
        let size: CGSize
    }

    private struct PDFTextBlock {
        var text: String
        var frame: CGRect
        var fontSize: CGFloat
    }

    private func extractTextBlocks(from page: PDFPage) -> [PDFTextBlock] {
        var blocks: [PDFTextBlock] = []
        guard let selection = page.selection(for: page.bounds(for: .mediaBox)) else { return [] }
        
        let selections = selection.selectionsByLine()
        for lineSelection in selections {
            let text = lineSelection.string ?? ""
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            
            let bounds = lineSelection.bounds(for: page)
            // PDFKit sometimes returns extremely large bounds for empty characters/spaces
            if bounds.height > 100 || bounds.width > 2000 { continue }
            
            // Reduced font size multiplier to prevent overlapping (0.65 of line height)
            let fontSize = bounds.height * 0.65
            blocks.append(PDFTextBlock(text: text, frame: bounds, fontSize: fontSize))
        }
        return blocks
    }

    private func renderPageBackground(page: PDFPage, excluding blocks: [PDFTextBlock]) -> UIImage {
        let size = page.bounds(for: .mediaBox).size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { ctx in
            // Fill white first
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // Draw original PDF content flipped for UIKit
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
            
            // White out text areas to prevent "ghosting".
            // In PDFKit drawing, Y is bottom-up. In our manual fill (flipped back to normal), we need top-down.
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            for block in blocks {
                // Slightly tighter white-out rect
                let rect = CGRect(
                    x: block.frame.origin.x, 
                    y: size.height - block.frame.origin.y - block.frame.size.height, 
                    width: block.frame.size.width, 
                    height: block.frame.size.height
                )
                ctx.cgContext.fill(rect)
            }
        }
    }

    private func createEditableDOCX(pages: [PDFFidelityPage]) -> Data? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let wordDir = tempDir.appendingPathComponent("word")
        let mediaDir = wordDir.appendingPathComponent("media")
        let relsDir = tempDir.appendingPathComponent("_rels")
        let docRelsDir = wordDir.appendingPathComponent("_rels")
        let rootRelsDir = tempDir.appendingPathComponent("_rels")
        
        do {
            try [tempDir, wordDir, mediaDir, relsDir, docRelsDir, rootRelsDir].forEach { 
                try fileManager.createDirectory(at: $0, withIntermediateDirectories: true) 
            }
            
            var relsEntries = ""
            var bodyXml = ""
            var finalSectXml = ""
            
            for (pIdx, page) in pages.enumerated() {
                let bgName = "bg\(pIdx + 1).jpg"
                if let data = page.background.jpegData(compressionQuality: 0.8) {
                    try data.write(to: mediaDir.appendingPathComponent(bgName))
                }
                
                let bgRid = "rIdBG\(pIdx + 1)"
                relsEntries += "<Relationship Id=\"\(bgRid)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/\(bgName)\"/>\n"
                
                let pW = Int(page.size.width * 12700)
                let pH = Int(page.size.height * 12700)
                let pgW = Int(page.size.width * 20)
                let pgH = Int(page.size.height * 20)
                
                // Content for this page
                var pageContentXml = ""
                
                // 1. Background (relative to page)
                pageContentXml += """
                <w:r>
                    <w:drawing>
                        <wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="0" behindDoc="1" locked="1" layoutInCell="1" allowOverlap="1">
                            <wp:simplePos x="0" y="0"/>
                            <wp:positionH relativeFrom="page"><wp:posOffset>0</wp:posOffset></wp:positionH>
                            <wp:positionV relativeFrom="page"><wp:posOffset>0</wp:posOffset></wp:positionV>
                            <wp:extent cx="\(pW)" cy="\(pH)"/>
                            <wp:docPr id="\(pIdx * 5000 + 1)" name="BG\(pIdx + 1)"/>
                            <wp:cNvGraphicFramePr/>
                            <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                                <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                                    <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                                        <pic:nvPicPr><pic:cNvPr id="\(pIdx * 5000 + 1)" name="BG\(pIdx + 1)"/><pic:cNvPicPr/></pic:nvPicPr>
                                        <pic:blipFill><a:blip r:embed="\(bgRid)"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                                        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(pW)" cy="\(pH)"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                                    </pic:pic>
                                </a:graphicData>
                            </a:graphic>
                        </wp:anchor>
                    </w:drawing>
                </w:r>
                """
                
                // 2. Text Boxes
                for (bIdx, block) in page.textBlocks.enumerated() {
                    let bW = Int(block.frame.width * 12700)
                    let bH = Int(block.frame.height * 12700) 
                    let bX = Int(block.frame.origin.x * 12700)
                    let bY = Int((page.size.height - block.frame.origin.y - block.frame.height) * 12700)
                    let fontSize = Int(block.fontSize * 2)
                    let escapedText = block.text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
                    
                    pageContentXml += """
                    <w:r>
                        <w:drawing>
                            <wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="\(bIdx + 2)" behindDoc="0" locked="0" layoutInCell="1" allowOverlap="1">
                                <wp:simplePos x="0" y="0"/>
                                <wp:positionH relativeFrom="page"><wp:posOffset>\(bX)</wp:posOffset></wp:positionH>
                                <wp:positionV relativeFrom="page"><wp:posOffset>\(bY)</wp:posOffset></wp:positionV>
                                <wp:extent cx="\(bW)" cy="\(bH)"/>
                                <wp:docPr id="\(pIdx * 5000 + bIdx + 2)" name="Txt\(pIdx + 1)_\(bIdx + 1)"/>
                                <wp:cNvGraphicFramePr/>
                                <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                                    <a:graphicData uri="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">
                                        <wps:wsp xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">
                                            <wps:spPr>
                                                <a:xfrm><a:off x="0" y="0"/><a:ext cx="\(bW)" cy="\(bH)"/></a:xfrm>
                                                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                                                <a:ln><a:noFill/></a:ln>
                                            </wps:spPr>
                                            <wps:txbx>
                                                <w:txbxContent>
                                                    <w:p>
                                                        <w:pPr><w:spacing w:after="0" w:before="0" w:line="0" w:lineRule="auto"/><w:jc w:val="left"/></w:pPr>
                                                        <w:r>
                                                            <w:rPr>
                                                                <w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>
                                                                <w:sz w:val="\(fontSize)"/><w:szCs w:val="\(fontSize)"/><w:color w:val="000000"/>
                                                            </w:rPr>
                                                            <w:t>\(escapedText)</w:t>
                                                        </w:r>
                                                    </w:p>
                                                </w:txbxContent>
                                            </wps:txbx>
                                            <wps:bodyPr vert="horz" lIns="0" tIns="0" rIns="0" bIns="0" anchor="t"/>
                                        </wps:wsp>
                                    </a:graphicData>
                                </a:graphic>
                            </wp:anchor>
                        </w:drawing>
                    </w:r>
                    """
                }
                
                let sectXml = """
                <w:sectPr>
                    <w:pgSz w:w="\(pgW)" w:h="\(pgH)"/>
                    <w:pgMar w:top="0" w:right="0" w:bottom="0" w:left="0" w:header="0" w:footer="0" w:gutter="0"/>
                </w:sectPr>
                """
                
                // IMPORTANT: The Section Properties for Page N must come AFTER the content of Page N,
                // and it must be inside the <w:pPr> of the last paragraph of that section.
                if pIdx < pages.count - 1 {
                    bodyXml += "<w:p>\(pageContentXml)<w:pPr><w:spacing w:after=\"0\" w:before=\"0\" w:line=\"0\" w:lineRule=\"auto\"/>\(sectXml)</w:pPr></w:p>"
                } else {
                    bodyXml += "<w:p>\(pageContentXml)</w:p>"
                    finalSectXml = sectXml
                }
            }
            
            let documentXml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" 
                        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" 
                        xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" 
                        xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" 
                        xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
                        xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
                        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
                        mc:Ignorable="wps">
                <w:body>
                    \(bodyXml)
                    \(finalSectXml)
                </w:body>
            </w:document>
            """
            try documentXml.write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)
            
            // Re-adding Styles and basic structure for better compatibility
            let styleXml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/></w:rPr></w:rPrDefault></w:docDefaults></w:styles>"
            try styleXml.write(to: wordDir.appendingPathComponent("styles.xml"), atomically: true, encoding: .utf8)

            let contentTypes = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                <Default Extension="xml" ContentType="application/xml"/>
                <Default Extension="jpg" ContentType="image/jpeg"/>
                <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
                <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
            </Types>
            """
            try contentTypes.write(to: tempDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
            let rootRels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>"
            try rootRels.write(to: rootRelsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)
            let docRels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rIdStyle\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>\(relsEntries)</Relationships>"
            try docRels.write(to: wordDir.appendingPathComponent("_rels/document.xml.rels"), atomically: true, encoding: .utf8)

            let zipURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".docx")
            try fileManager.zipItem(at: tempDir, to: zipURL, shouldKeepParent: false)
            let data = try Data(contentsOf: zipURL)
            try? fileManager.removeItem(at: tempDir); try? fileManager.removeItem(at: zipURL)
            return data
        } catch {
            Logger.print("DOCX Build Error: \(error)", level: .error)
            return nil
        }
    }

    private func createEditablePPTX(pages: [PDFFidelityPage]) -> Data? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pptDir = tempDir.appendingPathComponent("ppt")
        let slidesDir = pptDir.appendingPathComponent("slides")
        let slideMastersDir = pptDir.appendingPathComponent("slideMasters")
        let slideLayoutsDir = pptDir.appendingPathComponent("slideLayouts")
        let themeDir = pptDir.appendingPathComponent("theme")
        let mediaDir = pptDir.appendingPathComponent("media")
        
        // Define directory structure
        let dirs = [
            tempDir.appendingPathComponent("_rels"),
            pptDir.appendingPathComponent("_rels"),
            slidesDir.appendingPathComponent("_rels"),
            slideMastersDir.appendingPathComponent("_rels"),
            slideLayoutsDir.appendingPathComponent("_rels"),
            themeDir,
            mediaDir
        ]
        
        do {
            try dirs.forEach { try fileManager.createDirectory(at: $0, withIntermediateDirectories: true) }
            
            // 1. Theme (Mandatory for some viewers)
            let themeXml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
                <a:themeElements><a:clrScheme name="Office"><a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1><a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="44546A"/></a:dk2><a:lt2><a:srgbClr val="E7E6E6"/></a:lt2><a:accent1><a:srgbClr val="4472C4"/></a:accent1><a:accent2><a:srgbClr val="ED7D31"/></a:accent2><a:accent3><a:srgbClr val="A5A5A5"/></a:accent3><a:accent4><a:srgbClr val="FFC000"/></a:accent4><a:accent5><a:srgbClr val="5B9BD5"/></a:accent5><a:accent6><a:srgbClr val="70AD47"/></a:accent6><a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme><a:fontScheme name="Office"><a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme><a:fmtScheme name="Office"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="50000"/><a:satMod val="300000"/></a:schemeClr></a:gs><a:gs pos="35000"><a:schemeClr val="phClr"><a:tint val="37000"/><a:satMod val="300000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:tint val="15000"/><a:satMod val="300000"/></a:schemeClr></a:gs></a:gsLst><a:lin ang="16200000" scaled="1"/></a:gradFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:shade val="51000"/><a:satMod val="130000"/></a:schemeClr></a:gs><a:gs pos="80000"><a:schemeClr val="phClr"><a:shade val="93000"/><a:satMod val="130000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="94000"/><a:satMod val="130000"/></a:schemeClr></a:gs></a:gsLst><a:lin ang="16200000" scaled="1"/></a:gradFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"><a:shade val="95000"/><a:satMod val="105000"/></a:schemeClr></a:solidFill><a:prstDash val="solid"/></a:ln><a:ln w="25400" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln><a:ln w="38100" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst><a:outerShdw blurRad="40000" dist="20000" dir="5400000" rotWithShape="0"><a:srgbClr val="000000"><a:alpha val="38000"/></a:srgbClr></a:outerShdw></a:effectLst></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="40000"/><a:satMod val="350000"/></a:schemeClr></a:gs><a:gs pos="40000"><a:schemeClr val="phClr"><a:tint val="45000"/><a:shade val="99000"/><a:satMod val="350000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="20000"/><a:satMod val="350000"/></a:schemeClr></a:gs></a:gsLst><a:path path="circle"><a:fillToRect l="50000" t="-80000" r="50000" b="180000"/></a:path></a:gradFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="80000"/><a:satMod val="300000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="30000"/><a:satMod val="200000"/></a:schemeClr></a:gs></a:gsLst><a:path path="circle"><a:fillToRect l="50000" t="50000" r="50000" b="50000"/></a:path></a:gradFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements>
            </a:theme>
            """
            try themeXml.write(to: themeDir.appendingPathComponent("theme1.xml"), atomically: true, encoding: .utf8)
            
            // 2. Slide Layout
            let slideLayoutXml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
                <p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>
            </p:sldLayout>
            """
            try slideLayoutXml.write(to: slideLayoutsDir.appendingPathComponent("slideLayout1.xml"), atomically: true, encoding: .utf8)
            let slideLayoutRels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"../slideMasters/slideMaster1.xml\"/></Relationships>"
            try slideLayoutRels.write(to: slideLayoutsDir.appendingPathComponent("_rels/slideLayout1.xml.rels"), atomically: true, encoding: .utf8)
            
            // 3. Slide Master
            let slideMasterXml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
                <p:cSld><p:bg><p:bgPr><a:solidFill><a:schemeClr val="lt1"/></a:solidFill><a:effectLst/></p:bgPr></p:bg><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>
                <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
                <p:sldLayoutIdLst><p:sldLayoutId id="2147483648" r:id=\"rId1\"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>
            </p:sldMaster>
            """
            try slideMasterXml.write(to: slideMastersDir.appendingPathComponent("slideMaster1.xml"), atomically: true, encoding: .utf8)
            let slideMasterRels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"../theme/theme1.xml\"/></Relationships>"
            try slideMasterRels.write(to: slideMastersDir.appendingPathComponent("_rels/slideMaster1.xml.rels"), atomically: true, encoding: .utf8)
            
            // 4. Register Content Types
            var contentTypesXml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                <Default Extension="xml" ContentType="application/xml"/>
                <Default Extension="jpg" ContentType="image/jpeg"/>
                <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
                <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
                <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
                <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
            </Types>
            """
            
            var presentationRelsXml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                <Relationship Id="rIdMaster1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
            """
            var sldIdListXml = "<p:sldIdLst>"
            
            // 5. Build Slides
            for (pIdx, page) in pages.enumerated() {
                let sId = pIdx + 1
                let slideName = "slide\(sId).xml"
                let bgName = "bg\(sId).jpg"
                
                let bgRId = "rIdBG\(sId)"
                
                if let data = page.background.jpegData(compressionQuality: 0.8) {
                    try data.write(to: mediaDir.appendingPathComponent(bgName))
                }
                
                var slideSpXml = ""
                for (bIdx, block) in page.textBlocks.enumerated() {
                    let bW = Int(block.frame.width * 12700)
                    let bH = Int(block.frame.height * 12700)
                    let bX = Int(block.frame.origin.x * 12700)
                    let bY = Int((page.size.height - block.frame.origin.y - block.frame.height) * 12700)
                    let fontSize = Int(block.fontSize * 100)
                    let escapedText = block.text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
                    let shapeId = (sId * 1000) + bIdx + 10
                    
                    slideSpXml += """
                    <p:sp>
                        <p:nvSpPr><p:cNvPr id=\"\(shapeId)\" name=\"Txt\(sId)_\(bIdx + 1)\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
                        <p:spPr><a:xfrm><a:off x=\"\(bX)\" y=\"\(bY)\"/><a:ext cx=\"\(bW)\" cy=\"\(bH)\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>
                        <p:txBody><a:bodyPr lIns=\"0\" tIns=\"0\" rIns=\"0\" bIns=\"0\" anchor=\"t\"/><a:lstStyle/><a:p><a:pPr algn=\"l\"/><a:r><a:rPr lang=\"en-US\" sz=\"\(fontSize)\"><a:latin typeface=\"Arial\"/></a:rPr><a:t>\(escapedText)</a:t></a:r></a:p></p:txBody>
                    </p:sp>
                    """
                }
                
                let rootGroupId = (sId * 1000) + 1
                let slideXml = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
                    <p:cSld>
                        <p:bg><p:bgPr><a:blipFill><a:blip r:embed=\"\(bgRId)\"/><a:stretch><a:fillRect/></a:stretch></a:blipFill><a:effectLst/></p:bgPr></p:bg>
                        <p:spTree><p:nvGrpSpPr><p:cNvPr id=\"\(rootGroupId)\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>\(slideSpXml)</p:spTree>
                    </p:cSld>
                    <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
                </p:sld>
                """
                try slideXml.write(to: slidesDir.appendingPathComponent(slideName), atomically: true, encoding: .utf8)
                
                let slideRelsXml = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                    <Relationship Id="rIdLayout" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
                    <Relationship Id="\(bgRId)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/\(bgName)"/>
                </Relationships>
                """
                try slideRelsXml.write(to: slidesDir.appendingPathComponent("_rels/\(slideName).rels"), atomically: true, encoding: .utf8)
                
                let rId = "rId\(sId + 10)"
                presentationRelsXml += "    <Relationship Id=\"\(rId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/\(slideName)\"/>\n"
                sldIdListXml += "    <p:sldId id=\"\(256 + pIdx)\" r:id=\"\(rId)\"/>\n"
                contentTypesXml = contentTypesXml.replacingOccurrences(of: "</Types>", with: "    <Override PartName=\"/ppt/slides/\(slideName)\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>\n</Types>")
            }
            
            presentationRelsXml += "</Relationships>"
            sldIdListXml += "</p:sldIdLst>"
            
            // 6. Final XML writes
            let pW = Int((pages.first?.size.width ?? 792) * 12700)
            let pH = Int((pages.first?.size.height ?? 612) * 12700)
            let presentationXml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
                <p:sldMasterIdLst>
                    <p:sldMasterId id="2147483648" r:id="rIdMaster1"/>
                </p:sldMasterIdLst>
                \(sldIdListXml)
                <p:notesSz cx="6858000" cy="9144000"/>
                <p:sldSz cx="\(pW)" cy="\(pH)" type="screen4x3"/>
            </p:presentation>
            """
            try presentationXml.write(to: pptDir.appendingPathComponent("presentation.xml"), atomically: true, encoding: .utf8)
            try presentationRelsXml.write(to: pptDir.appendingPathComponent("_rels/presentation.xml.rels"), atomically: true, encoding: .utf8)
            try contentTypesXml.write(to: tempDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
            let zipURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pptx")
            
            // 7. Mandatory Metadata (docProps)
            let docPropsDir = tempDir.appendingPathComponent("docProps")
            try fileManager.createDirectory(at: docPropsDir, withIntermediateDirectories: true)
            
            let appXml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
                <Application>PDF Tools</Application>
            </Properties>
            """
            try appXml.write(to: docPropsDir.appendingPathComponent("app.xml"), atomically: true, encoding: .utf8)
            
            let coreXml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <dc:title>PowerPoint Presentation</dc:title>
                <dc:creator>PDF Tools</dc:creator>
                <cp:lastModifiedBy>PDF Tools</cp:lastModifiedBy>
                <cp:revision>1</cp:revision>
            </cp:coreProperties>
            """
            try coreXml.write(to: docPropsDir.appendingPathComponent("core.xml"), atomically: true, encoding: .utf8)
            
            // Update root rels and content types for metadata
            let rootRelsExtended = """
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
                <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
                <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
            </Relationships>
            """
            try rootRelsExtended.write(to: tempDir.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
            
            contentTypesXml = contentTypesXml.replacingOccurrences(of: "</Types>", with: """
                <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
                <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
            </Types>
            """)
            try contentTypesXml.write(to: tempDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)

            try fileManager.zipItem(at: tempDir, to: zipURL, shouldKeepParent: false)
            let data = try Data(contentsOf: zipURL)
            try? fileManager.removeItem(at: tempDir); try? fileManager.removeItem(at: zipURL)
            return data
            
        } catch {
            Logger.print("PPTX Build Error: \(error)", level: .error)
            return nil
        }
    }
}
