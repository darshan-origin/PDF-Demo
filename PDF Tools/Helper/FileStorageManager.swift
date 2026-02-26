//
//  FileStorageManager.swift
//  PDF Tools
//
//  Created by mac on 19/02/26.
//

//
//  FileStorageManager.swift
//  Centralized file and directory operations: store, fetch, edit, delete,
//  rename, duplicate, copy, move, list, and attributes.
//
//  See FILE_MANAGER_README.md for setup and usage.
//

import Foundation
import UIKit

// MARK: - StorageLocation

/// Base directory for file storage (Documents, Caches, Temporary, etc.).
public enum StorageLocation {
    case documents
    case caches
    case temporary
    case applicationSupport
    case custom(URL)
    
    public var url: URL {
        switch self {
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        case .caches:
            return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        case .temporary:
            return FileManager.default.temporaryDirectory
        case .applicationSupport:
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        case .custom(let url):
            return url
        }
    }
}

// MARK: - FileItem

/// Lightweight representation of a file or directory at a path.
public struct FileItem {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let size: Int64
    public let modificationDate: Date?
    
    public init(url: URL, name: String, isDirectory: Bool, size: Int64, modificationDate: Date?) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate
    }
}

// MARK: - FileStorageManagerError

public enum FileStorageManagerError: Error, LocalizedError {
    case invalidPath
    case fileNotFound
    case directoryNotFound
    case cannotCreateDirectory(URL)
    case writeFailed(URL)
    case readFailed(URL)
    case deleteFailed(URL)
    case moveFailed(source: URL, destination: URL)
    case copyFailed(source: URL, destination: URL)
    case encodingFailed
    case decodingFailed(Error)
    case notAFile(URL)
    case notADirectory(URL)
    case fileAlreadyExists(URL)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPath: return "The provided path or URL is invalid."
        case .fileNotFound: return "The file does not exist."
        case .directoryNotFound: return "The directory does not exist."
        case .cannotCreateDirectory(let url): return "Cannot create directory at \(url.path)."
        case .writeFailed(let url): return "Failed to write to \(url.path)."
        case .readFailed(let url): return "Failed to read from \(url.path)."
        case .deleteFailed(let url): return "Failed to delete \(url.path)."
        case .moveFailed(let src, let dst): return "Failed to move \(src.path) to \(dst.path)."
        case .copyFailed(let src, let dst): return "Failed to copy \(src.path) to \(dst.path)."
        case .encodingFailed: return "Failed to encode data."
        case .decodingFailed(let error): return "Failed to decode: \(error.localizedDescription)."
        case .notAFile(let url): return "\(url.path) is not a file."
        case .notADirectory(let url): return "\(url.path) is not a directory."
        case .fileAlreadyExists(let url): return "File already exists at \(url.path)."
        }
    }
}

// MARK: - FileStorageManager

/// Centralized file and directory operations. All paths are relative to a `StorageLocation` unless a full URL is provided.
public enum FileStorageManager {
    
    private static let fileManager = FileManager.default
    private static let queue = DispatchQueue(label: "com.app.filestoragemanager.serial", qos: .utility)
    
    /// Default base location for relative paths. Defaults to `.documents`.
    public static var defaultLocation: StorageLocation = .documents
    
    // MARK: - Path resolution
    
    /// Resolves a relative path (e.g. "folder/file.txt") to a full URL under the given location.
    public static func url(for path: String, in location: StorageLocation = defaultLocation) -> URL {
        location.url.appendingPathComponent(path)
    }
    
    /// Ensures the parent directory of the given URL exists. Creates intermediate directories if needed.
    public static func createParentDirectoryIfNeeded(for url: URL) throws {
        let parent = url.deletingLastPathComponent()
        guard parent.path != url.path else { return }
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    public static func documentsDirectoryURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    public static func fetchFiles(in directory: URL) -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            
            return contents.filter { $0.hasDirectoryPath == false }
        } catch {
            return []
        }
    }
    
    // MARK: - Store (Write)
    
    /// Stores raw `Data` at the given path. Overwrites if the file exists.
    public static func store(_ data: Data, at path: String, in location: StorageLocation = defaultLocation) throws {
        let url = self.url(for: path, in: location)
        Logger.print("FILE_MANAGER: Store (Write) >>>>>> current url \(url)", level: .success)
        try createParentDirectoryIfNeeded(for: url)
        do {
            try data.write(to: url, options: .atomic)
            Logger.print("FILE_MANAGER: Store (Write) >>>>>> \(data)", level: .success)
        } catch {
            Logger.print("FILE_MANAGER: Store (Write) ERROR", level: .error)
            throw FileStorageManagerError.writeFailed(url)
        }
    }
    
    /// Stores a `String` (UTF-8) at the given path. Overwrites if the file exists.
    public static func store(_ string: String, at path: String, in location: StorageLocation = defaultLocation) throws {
        guard let data = string.data(using: .utf8) else { throw FileStorageManagerError.encodingFailed }
        try store(data, at: path, in: location)
    }
    
    /// Stores an `Encodable` value as JSON at the given path. Overwrites if the file exists.
    public static func store<T: Encodable>(_ value: T, at path: String, in location: StorageLocation = defaultLocation, encoder: JSONEncoder = JSONEncoder()) throws {
        let data = try encoder.encode(value)
        try store(data, at: path, in: location)
    }
    
    /// Writes `Data` directly to a full URL. Creates parent directory if needed. Overwrites if exists.
    public static func store(_ data: Data, at url: URL) throws {
        try createParentDirectoryIfNeeded(for: url)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw FileStorageManagerError.writeFailed(url)
        }
    }
    
    /// Appends `Data` to an existing file, or creates the file with this data if it does not exist.
    public static func append(_ data: Data, to path: String, in location: StorageLocation = defaultLocation) throws {
        let url = self.url(for: path, in: location)
        try createParentDirectoryIfNeeded(for: url)
        if fileManager.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try data.write(to: url, options: .atomic)
        }
    }
    
    /// Appends a `String` (UTF-8) to an existing file, or creates the file with this content if it does not exist.
    public static func append(_ string: String, to path: String, in location: StorageLocation = defaultLocation) throws {
        guard let data = string.data(using: .utf8) else { throw FileStorageManagerError.encodingFailed }
        try append(data, to: path, in: location)
    }
    
    /// Create Folder in document directory
    public static func createFolderInDocumentsDirectory(folderName: String) {
        let fileManager = FileManager.default
        do {
            let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let newFolderURL = documentsDirectory.appendingPathComponent(folderName)
            if !fileManager.fileExists(atPath: newFolderURL.path) {
                try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: false, attributes: nil)
                Logger.print("Folder '\\(folderName)' created successfully at: \\(newFolderURL.path)", level: .success)
            } else {
                Logger.print("Folder '\\(folderName)' already exists.", level: .warning)
            }
        } catch {
            Logger.print("Error creating folder: \\(error.localizedDescription)", level: .error)
        }
    }
    
    
    // MARK: - Fetch (Read)
    
    /// Fetch all files from document direcotory and return array of files URL.
    public static func fetchAllFiles() -> [URL] {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Logger.print("Unable to locate the documents directory.", level: .error)
            return []
        }
        
        do {
            let directoryContents = try fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            let fileURLs = directoryContents.filter { $0.hasDirectoryPath == false }
            Logger.print("Found files: \(fileURLs.map {$0}) \n \n \(fileURLs.map { $0.lastPathComponent })", level: .success)
            return fileURLs
        }
        catch {
            Logger.print("Error while enumerating files in the documents directory: \(error.localizedDescription)", level: .error)
            return []
        }
    }
    
    
    /// Fetches raw `Data` from the given path.
    public static func fetchData(at path: String, in location: StorageLocation = defaultLocation) throws -> Data {
        let url = self.url(for: path, in: location)
        return try fetchData(at: url)
    }
    
    /// Fetches raw `Data` from the given URL.
    public static func fetchData(at url: URL) throws -> Data {
        guard fileManager.fileExists(atPath: url.path) else { throw FileStorageManagerError.fileNotFound }
        var isDir: ObjCBool = false
        guard fileManager.isValidFile(at: url, isDirectory: &isDir), !isDir.boolValue else {
            throw FileStorageManagerError.notAFile(url)
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw FileStorageManagerError.readFailed(url)
        }
    }
    
    /// Fetches file content as a `String` (UTF-8).
    public static func fetchString(at path: String, in location: StorageLocation = defaultLocation) throws -> String {
        let data = try fetchData(at: path, in: location)
        guard let string = String(data: data, encoding: .utf8) else { throw FileStorageManagerError.decodingFailed(NSError(domain: "FileStorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8"])) }
        return string
    }
    
    /// Fetches and decodes a `Decodable` value from JSON at the given path.
    public static func fetch<T: Decodable>(_ type: T.Type, at path: String, in location: StorageLocation = defaultLocation, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        let data = try fetchData(at: path, in: location)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw FileStorageManagerError.decodingFailed(error)
        }
    }
    
    /// Fetches and decodes from a full URL.
    public static func fetch<T: Decodable>(_ type: T.Type, at url: URL, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        let data = try fetchData(at: url)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw FileStorageManagerError.decodingFailed(error)
        }
    }
    
    // MARK: - Edit (Overwrite / Append)
    
    /// Overwrites file content with the given `Data`. Creates file and parent directory if needed.
    public static func edit(_ data: Data, at path: String, in location: StorageLocation = defaultLocation) throws {
        try store(data, at: path, in: location)
    }
    
    /// Overwrites file content with the given `String`. Creates file and parent directory if needed.
    public static func edit(_ string: String, at path: String, in location: StorageLocation = defaultLocation) throws {
        try store(string, at: path, in: location)
    }
    
    /// Overwrites file content with the given `Encodable` as JSON.
    public static func edit<T: Encodable>(_ value: T, at path: String, in location: StorageLocation = defaultLocation, encoder: JSONEncoder = JSONEncoder()) throws {
        try store(value, at: path, in: location, encoder: encoder)
    }
    
    // MARK: - Delete
    
    /// Deletes the file or directory at the given path. For directories, use `removeDirectory(recursive:)` to remove contents.
    public static func delete(at path: String, in location: StorageLocation = defaultLocation) throws {
        let url = self.url(for: path, in: location)
        try delete(at: url)
    }
    
    /// Deletes the file or empty directory at the given URL.
    public static func delete(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { throw FileStorageManagerError.fileNotFound }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw FileStorageManagerError.deleteFailed(url)
        }
    }
    
    /// Removes a directory. If `recursive` is true, removes the directory and all contents; if false, removes only when the directory is empty.
    public static func removeDirectory(at path: String, in location: StorageLocation = defaultLocation, recursive: Bool = true) throws {
        let url = self.url(for: path, in: location)
        guard fileManager.fileExists(atPath: url.path) else { throw FileStorageManagerError.directoryNotFound }
        var isDir: ObjCBool = false
        guard fileManager.isValidFile(at: url, isDirectory: &isDir), isDir.boolValue else {
            throw FileStorageManagerError.notADirectory(url)
        }
        if !recursive {
            let contents = try fileManager.contentsOfDirectory(atPath: url.path)
            if !contents.isEmpty {
                throw FileStorageManagerError.deleteFailed(url)
            }
        }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw FileStorageManagerError.deleteFailed(url)
        }
    }
    
    /// Removes a file if it exists. Does nothing if the path does not exist. Does not throw.
    public static func removeFileIfExists(at url: URL) {
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
    
    /// Removes file at path if it exists. Does not throw.
    public static func removeFileIfExists(at path: String, in location: StorageLocation = defaultLocation) {
        let url = self.url(for: path, in: location)
        removeFileIfExists(at: url)
    }
    
    // MARK: - Rename
    
    /// Renames the file or directory at `path` to `newName` (same parent directory).
    public static func rename(at path: String, to newName: String, in location: StorageLocation = defaultLocation) throws {
        let url = self.url(for: path, in: location)
        let parent = url.deletingLastPathComponent()
        let destination = parent.appendingPathComponent(newName)
        try move(from: url, to: destination)
    }
    
    /// Renames the item at `url` to `newName` in the same directory.
    public static func rename(at url: URL, to newName: String) throws {
        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        try move(from: url, to: destination)
    }
    
    // MARK: - Duplicate
    
    /// Duplicates the file at `path` to a new file named `destinationName` in the same directory (or optional destination path).
    public static func duplicate(at path: String, to destinationName: String? = nil, in location: StorageLocation = defaultLocation) throws -> URL {
        let url = self.url(for: path, in: location)
        let name = destinationName ?? Self.copySuffixName(for: url)
        let destination = url.deletingLastPathComponent().appendingPathComponent(name)
        try copy(from: url, to: destination)
        return destination
    }
    
    /// Duplicates the file at `url` to the same directory with an optional new name; if nil, uses "_copy" suffix.
    public static func duplicate(at url: URL, to destinationName: String? = nil) throws -> URL {
        let name = destinationName ?? Self.copySuffixName(for: url)
        let destination = url.deletingLastPathComponent().appendingPathComponent(name)
        try copy(from: url, to: destination)
        return destination
    }
    
    private static func copySuffixName(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        return ext.isEmpty ? "\(base)_copy" : "\(base)_copy.\(ext)"
    }
    
    // MARK: - Copy
    
    /// Copies the file or directory at `sourcePath` to `destinationPath` (full path under the same location).
    public static func copy(from sourcePath: String, to destinationPath: String, in location: StorageLocation = defaultLocation) throws {
        let source = self.url(for: sourcePath, in: location)
        let destination = self.url(for: destinationPath, in: location)
        try copy(from: source, to: destination)
    }
    
    /// Copies the file or directory at `source` URL to `destination` URL. Creates parent of destination if needed.
    public static func copy(from source: URL, to destination: URL) throws {
        guard fileManager.fileExists(atPath: source.path) else { throw FileStorageManagerError.fileNotFound }
        try createParentDirectoryIfNeeded(for: destination)
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            throw FileStorageManagerError.copyFailed(source: source, destination: destination)
        }
    }
    
    // MARK: - Move
    
    /// Moves the file or directory at `sourcePath` to `destinationPath` under the same location.
    public static func move(from sourcePath: String, to destinationPath: String, in location: StorageLocation = defaultLocation) throws {
        let source = self.url(for: sourcePath, in: location)
        let destination = self.url(for: destinationPath, in: location)
        try move(from: source, to: destination)
    }
    
    /// Moves the file or directory at `source` URL to `destination` URL. Creates parent of destination if needed.
    public static func move(from source: URL, to destination: URL) throws {
        guard fileManager.fileExists(atPath: source.path) else { throw FileStorageManagerError.fileNotFound }
        try createParentDirectoryIfNeeded(for: destination)
        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            throw FileStorageManagerError.moveFailed(source: source, destination: destination)
        }
    }
    
    // MARK: - File Creation Date
    
    /// Fetch creatiuon date of given file url.
    public static func getFileCreationDate(for fileURL: URL) -> Date? {
        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey])
            return resourceValues.creationDate
        } catch {
            Logger.print("Error getting creation date: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
    
    // MARK: - File size and time
    
    /// fetch the given path url files size and time together and return
    public static func sizeAndDateString(for url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            
            let fileSize: UInt64 = attributes[.size] as? UInt64 ?? 0
            let sizeFormatter = ByteCountFormatter()
            sizeFormatter.countStyle = .file
            let sizeString = sizeFormatter.string(fromByteCount: Int64(fileSize))
            let creationDate: Date = attributes[.creationDate] as? Date ?? Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let dateString = dateFormatter.string(from: creationDate)
            
            return "\(sizeString) • \(dateString)"
            
        } catch {
            Logger.print("Error fetching file attributes: \(error.localizedDescription)", level: .error)
            return "Unknown size • Unknown date"
        }
    }
    
    // MARK: - Directory creation
    
    
    /// fetch all only folder's directory from file manaager
    internal static func fetchFoldersFromDocumentDirectory() -> [FolderModel] {
        let fileManager = FileManager.default
        
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Logger.print("Could not find the documents directory URL.", level: .warning)
            return []
        }
        
        do {
            let directoryContents = try fileManager.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            let folders = directoryContents.compactMap { url -> FolderModel? in
                guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey]),
                      resourceValues.isDirectory == true else {
                    return nil
                }
                
                let size = folderSize(at: url)
                let creationDate = resourceValues.creationDate
                
                Logger.print(
                    "Found Folder: \(url.lastPathComponent) | Size: \(size) bytes",
                    level: .success
                )
                
                return FolderModel(
                    name: url.lastPathComponent,
                    url: url,
                    size: size,
                    creationDate: creationDate
                )
            }
            
            return folders
            
        } catch {
            Logger.print("Error while enumerating files: \(error.localizedDescription)", level: .error)
            return []
        }
    }
    
    
    /// Folder size fetch
    public static func folderSize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var size: Int64 = 0
        
        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                   resourceValues.isRegularFile == true,
                   let fileSize = resourceValues.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        
        return size
    }
    
    /// Creates a directory at the given path (and any intermediate directories). Does nothing if it already exists.
    public static func createDirectory(at path: String, in location: StorageLocation = defaultLocation) throws {
        let url = self.url(for: path, in: location)
        if fileManager.fileExists(atPath: url.path) { return }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw FileStorageManagerError.cannotCreateDirectory(url)
        }
    }
    
    /// Creates a directory at the given URL with intermediate directories if needed.
    public static func createDirectory(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) { return }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw FileStorageManagerError.cannotCreateDirectory(url)
        }
    }
    
    // MARK: - Exists & listing
    
    /// Returns whether a file or directory exists at the given path.
    public static func exists(at path: String, in location: StorageLocation = defaultLocation) -> Bool {
        let url = self.url(for: path, in: location)
        return fileManager.fileExists(atPath: url.path)
    }
    
    /// Returns whether a file or directory exists at the given URL.
    public static func exists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
    
    /// Returns whether the path is a directory.
    public static func isDirectory(at path: String, in location: StorageLocation = defaultLocation) -> Bool {
        let url = self.url(for: path, in: location)
        var isDir: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
    
    /// Lists contents of the directory at the given path (non-recursive). Returns empty array if path is not a directory or does not exist.
    public static func listContents(at path: String, in location: StorageLocation = defaultLocation) throws -> [FileItem] {
        let url = self.url(for: path, in: location)
        return try listContents(at: url)
    }
    
    /// Lists contents of the directory at the given URL. Returns array of `FileItem`.
    public static func listContents(at url: URL) throws -> [FileItem] {
        guard fileManager.fileExists(atPath: url.path) else { throw FileStorageManagerError.directoryNotFound }
        var isDir: ObjCBool = false
        guard fileManager.isValidFile(at: url, isDirectory: &isDir), isDir.boolValue else {
            throw FileStorageManagerError.notADirectory(url)
        }
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
        return contents.compactMap { url -> FileItem? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) else { return nil }
            let size = Int64(values.fileSize ?? 0)
            let isDirectory = values.isDirectory ?? false
            return FileItem(url: url, name: url.lastPathComponent, isDirectory: isDirectory, size: size, modificationDate: values.contentModificationDate)
        }
    }
    
    // MARK: - Attributes & size
    
    /// Returns the file size in bytes, or nil if not a file or not found.
    public static func fileSize(at path: String, in location: StorageLocation = defaultLocation) -> Int64? {
        let url = self.url(for: path, in: location)
        return fileSize(at: url)
    }
    
    /// Returns the file size in bytes at the given URL.
    public static func fileSize(at url: URL) -> Int64? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return nil }
        return size
    }
    
    /// Returns modification date for the item at path, or nil.
    public static func modificationDate(at path: String, in location: StorageLocation = defaultLocation) -> Date? {
        let url = self.url(for: path, in: location)
        return (try? fileManager.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
    
    /// Returns full attributes dictionary for the item at the URL.
    public static func attributes(at url: URL) throws -> [FileAttributeKey: Any] {
        guard fileManager.fileExists(atPath: url.path) else { throw FileStorageManagerError.fileNotFound }
        return try fileManager.attributesOfItem(atPath: url.path)
    }
    
    
    
    public static func saveImagesToDocuments(images: [UIImage], folderName: String = "SavedImages") -> [URL]? {
        
        let fileManager = FileManager.default
        
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let folderURL = documentsURL.appendingPathComponent(folderName)
        
        if !fileManager.fileExists(atPath: folderURL.path) {
            do {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                Logger.print("Error creating directory: \(error)", level: .error)
                return nil
            }
        }
        
        var savedURLs: [URL] = []
        
        for (index, image) in images.enumerated() {
            let fileURL = folderURL.appendingPathComponent("image_\(index).jpg")
            if let data = image.jpegData(compressionQuality: 0.8) {
                do {
                    try data.write(to: fileURL)
                    savedURLs.append(fileURL)
                } catch {
                    Logger.print("Error saving image: \(error)", level: .error)
                }
            }
        }
        return savedURLs
    }
    
}

// MARK: - FileManager validation helper

extension FileManager {
    
    /// Returns true if the URL exists and matches the given isDirectory expectation.
    fileprivate func isValidFile(at url: URL, isDirectory: UnsafeMutablePointer<ObjCBool>) -> Bool {
        fileExists(atPath: url.path, isDirectory: isDirectory)
    }
}
