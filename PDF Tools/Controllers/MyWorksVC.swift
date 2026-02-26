import UIKit
import PDFKit
import PDFCompressorKit

class MyWorksVC: UIViewController {
    
    @IBOutlet private weak var tableView_allFiles: UITableView!
    @IBOutlet weak var btn_filter: UIButton!
    
    private var items: [WorkItem] = []
    private var currentDirectoryURL: URL?
    let compressor = PDFCompressor()
    
    override func viewDidLoad() {
        tabBarController?.isTabBarHidden = false
        btn_filter.showsMenuAsPrimaryAction = true
        btn_filter.menu = makeFilterMenu()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        loadFiles()
    }
    
    @IBAction func onTapped_importPDF(_ sender: Any) {
        DocumentPickerHelper.openDoc(type: .pdf, from: self) { selectedURL in
            guard let sourceURL = selectedURL else { return }
            do {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsURL.appendingPathComponent(sourceURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                Logger.print("PDF saved at: \(destinationURL)", level: .success)
                self.loadFiles()
            } catch {
                Logger.print("Error saving PDF: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    @IBAction func onTapped_createNewFolder(_ sender: Any) {
        AlertHelper.shared.textFieldAlert(title: "Create New Folder", placeHolder: "Enter folder name", vc: self, saprated: false) { folderName in
            Logger.print("Received folder name: \(String(describing: folderName))", level: .success)
            FileStorageManager.createFolderInDocumentsDirectory(folderName: folderName ?? "PDF_TOOLS")
            self.loadFiles()
        }
    }
}

extension MyWorksVC {
    
    static func instantiate(with directoryURL: URL) -> MyWorksVC {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MyWorksVC") as! MyWorksVC
        vc.currentDirectoryURL = directoryURL
        return vc
    }
    
    func loadFiles() {
        ThreadManager.shared.background { [weak self] in
            guard let self = self else { return }
            
            let directoryURL = self.currentDirectoryURL ??
            FileStorageManager.documentsDirectoryURL()
            
            var tempItems: [WorkItem] = []
            
            if self.currentDirectoryURL == nil {
                let documentFolders = FileStorageManager.fetchFoldersFromDocumentDirectory()
                
                for folder in documentFolders {
                    tempItems.append(.folder(folder))
                }
            }
            
            let fileURLs = FileStorageManager.fetchFiles(in: directoryURL)
            
            let fileItems = fileURLs.map { url -> WorkItem in
                let thumb = DOCHelper.shared.generateThumbnailSync(for: url)
                let isProtected = PDFProtectionManager.shared.isProtected(url)
                                
                let fileModel = FilesMetaDataModel(
                    url: url,
                    name: url.lastPathComponent,
                    thumbnail: thumb,
                    size: FileStorageManager.fileSize(at: url),
                    creationDate: FileStorageManager.getFileCreationDate(for: url),
                    sizeAndTime: FileStorageManager.sizeAndDateString(for: url),
                    folderData: [],
                    isProtected: isProtected
                )
                return .file(fileModel)
            }
            
            tempItems.append(contentsOf: fileItems)
            
            ThreadManager.shared.main {
                self.items = tempItems
                self.title = self.currentDirectoryURL?.lastPathComponent ?? "My Works"
                self.tableView_allFiles.register(UINib(nibName: "cellAllFiles", bundle: .main), forCellReuseIdentifier: "cellAllFiles")
                self.tableView_allFiles.delegate = self
                self.tableView_allFiles.dataSource = self
                self.tableView_allFiles.reloadData()
            }
        }
    }
}


extension MyWorksVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        140
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellAllFiles", for: indexPath) as! cellAllFiles
        let item = items[indexPath.row]
        
        switch item {
            
        case .folder(let folder):
            cell.lbl_fileName.text = folder.name
            let formattedSize = ByteCountFormatter.string(fromByteCount: folder.size, countStyle: .file)
            cell.view_tag.isHidden = true
            cell.lbl_sizeANDtime.text = "Folder • \(formattedSize)"
            cell.img_thumbnail.image = UIImage(systemName: "folder.fill")
            cell.btn_moreInfo.isHidden = true
            
        case .file(let file):
            cell.lbl_fileName.text = file.name
            cell.lbl_sizeANDtime.text = file.sizeAndTime
            cell.btn_moreInfo.menu = makeMenu(for: indexPath.row)
            cell.btn_moreInfo.showsMenuAsPrimaryAction = true
            cell.btn_moreInfo.isHidden = false
            if let tagColor = file.tagColor {
                cell.view_tag.isHidden = false
                cell.view_tag.backgroundColor = tagColor
                cell.view_tag.layer.cornerRadius = cell.view_tag.frame.height / 2
            } else {
                cell.view_tag.isHidden = true
            }
            
            if file.url.pathExtension == "zip" {
                cell.img_thumbnail.image = UIImage(named: "ic_zip")
            } else {
                cell.img_thumbnail.image = file.thumbnail
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let item = items[indexPath.row]
        switch item {
        
            
        case .folder(let folder):
            let folderVC = MyWorksVC.instantiate(with: folder.url)
            tabBarController?.isTabBarHidden = true
            navigationController?.pushViewController(folderVC, animated: true)
            
        case .file(let file):
            
            if file.url.pathExtension == "jpg" {
                openImageViewer(with: "\(file.url)")
            }
            
            if file.url.pathExtension == "zip" {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                DOCHelper.shared.unzipFile(fromWhich: file.url, destinationURL: documentsURL)
                loadFiles()
            }
            
            if file.url.pathExtension == "pdf" {  
                
                if file.isProtected {
                    
                    AlertHelper.shared.textFieldAlert(
                        title: "Enter Password",
                        placeHolder: "Password",
                        vc: self,
                        saprated: false
                    ) { [weak self] enteredPassword in
                        
                        guard let self = self,
                              let enteredPassword else { return }
                        
                        let savedPassword = PDFProtectionManager.shared.getPassword(for: file.url)
                        
                        if enteredPassword == savedPassword {
                            let previewVC = PDFViewVC(url: file.url)
                            let nav = UINavigationController(rootViewController: previewVC)
                            nav.modalPresentationStyle = .fullScreen
                            self.present(nav, animated: true)
                        } else {
                            Logger.print("Wrong password", level: .error)
                        }
                    }
                    
                } else {
                    let previewVC = PDFViewVC(url: file.url)
                    let nav = UINavigationController(rootViewController: previewVC)
                    nav.modalPresentationStyle = .fullScreen
                    present(nav, animated: true)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let item = items[indexPath.row]
        
        guard case .folder(let folder) = item else {
            return nil
        }
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completionHandler) in
            self?.confirmDeleteFolder(folder, at: indexPath)
            completionHandler(true)
        }
        
        let renameAction = UIContextualAction(style: .normal, title: "Rename") { [weak self] (_, _, comletionHandler) in
            self?.confirmRename(folder, at: indexPath)
            comletionHandler(true)
        }
        
        deleteAction.image = UIImage(systemName: "trash.fill")
        renameAction.image = UIImage(systemName: "pencil")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
        configuration.performsFirstActionWithFullSwipe = false
        
        return configuration
    }
    
    private func confirmRename(_ folder: FolderModel, at indexPath: IndexPath) {
        AlertHelper.shared.textFieldAlert(
            title: "Rename the Folder",
            placeHolder: "Enter new folder name",
            vc: self,
            saprated: false) { newName in
                DOCHelper.shared.renameFolder(oldFolderName: folder.name, newFolderName: newName ?? "PDF_TOOLS")
                self.loadFiles()
            }
    }
    
    private func confirmDeleteFolder(_ folder: FolderModel, at indexPath: IndexPath) {
        AlertHelper.shared.showAlert(
            on: self,
            title: "Delete Folder",
            message: "Are you sure you want to delete the folder \"\(folder.name)\" and all its contents?",
            actions: [("Cancel", .cancel), ("OK", .destructive)]
        ) { [weak self] selectedAction in
            guard selectedAction == "OK", let self = self else { return }
            
            do {
                try FileManager.default.removeItem(at: folder.url)
                Logger.print("Folder delere successfully: \(folder.name)", level: .success)
                self.items.remove(at: indexPath.row)
                self.tableView_allFiles.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                Logger.print("Failed to delete folder: \(error.localizedDescription)", level: .error)
            }
        }
    }
}

extension MyWorksVC {
    
    func openImageViewer(with url: String) {
        let viewer = CommonImageViewerVC(imageUrl: url)
        present(viewer, animated: true, completion: nil)
    }
    
    func makeMenu(for index: Int) -> UIMenu {
        
        guard case .file(let file) = items[index] else {
            return UIMenu(title: "", children: [])
        }
        
        _ = DOCHelper.shared.isPDFPasswordProtected(url: file.url)
        var actions: [UIAction] = []
        
        for action in FileAction.allCases {
            if action == .setPassword {
                if file.isProtected {
                    let removeAction = UIAction(title: "Remove Password") { [weak self] _ in
                        PDFProtectionManager.shared.removePassword(for: file.url)
                        Logger.print("Password removed", level: .success)
                        self?.loadFiles()
                    }
                    actions.append(removeAction)
                }
                else {
                    let setPasswordAction = UIAction(title: action.rawValue) { [weak self] _ in
                        self?.handle(action, at: index)
                    }
                    actions.append(setPasswordAction)
                }
            }
            else {
                let normalAction = UIAction(title: action.rawValue) { [weak self] _ in
                    self?.handle(action, at: index)
                }
                actions.append(normalAction)
            }
        }
        return UIMenu(title: "PDF Edit", children: actions)
    }
    
    func makeFilterMenu() -> UIMenu {
        let actions = FilterAction.allCases.map { action in UIAction(title: action.rawValue) { [weak self] _ in self?.handleFilter(action)}}
        
        return UIMenu(title: "Filter", children: actions)
    }
    
    private func handleFilter(_ action: FilterAction) {
        var folders = items.compactMap {
            if case .folder(let folder) = $0 { return folder }
            return nil
        }
        
        var files = items.compactMap {
            if case .file(let file) = $0 { return file }
            return nil
        }
        
        switch action {
            
        case .createdDate:
            folders.sort {
                ($0.creationDate ?? .distantPast) >
                ($1.creationDate ?? .distantPast)
            }
            files.sort {
                ($0.creationDate ?? .distantPast) >
                ($1.creationDate ?? .distantPast)
            }
            Logger.print("Filter applied: Creation Date (Newest First)")
            
        case .az:
            folders.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            files.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            Logger.print("Filter applied: A - Z")
            
        case .za:
            folders.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }
            files.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }
            Logger.print("Filter applied: Z - A")
            
        case .size:
            folders.sort {
                $0.size > $1.size
            }
            files.sort {
                ($0.size ?? 0) > ($1.size ?? 0)
            }
            Logger.print("Filter applied: Size (Largest First)")
        }
        items = folders.map { .folder($0) } + files.map { .file($0) }
        tableView_allFiles.reloadData()
    }
    
    private func handle(_ action: FileAction, at index: Int) {
        
        guard case .file(let file) = items[index] else { return }
        
        switch action {
            
            // MARK: - RENAME
            
        case .rename:
            Logger.print("rename", level: .debug)
            
            AlertHelper.shared.textFieldAlert(
                title: "Rename File",
                placeHolder: "Rename this file",
                vc: self,
                saprated: false,
                keyboardType: .asciiCapable
            ) { newName in
                
                guard let newName, !newName.isEmpty else { return }
                
                do {
                    try FileStorageManager.rename(
                        at: file.url,
                        to: "\(newName).\(file.url.pathExtension)"
                    )
                    self.loadFiles()
                    Logger.print("File renamed successfully", level: .success)
                } catch {
                    Logger.print("Rename failed: \(error)", level: .error)
                }
            }
            
            // MARK: - DELETE
            
        case .delete:
            Logger.print("delete", level: .debug)
            
            AlertHelper.shared.showAlert(
                on: self,
                title: "Delete File",
                message: "Are you sure you want to delete this file?",
                actions: [("Cancel", .cancel), ("OK", .destructive)]
            ) { selectedAction in
                
                guard selectedAction == "OK" else { return }
                
                do {
                    try FileStorageManager.delete(at: file.url)
                    self.loadFiles()
                    Logger.print("File deleted successfully", level: .success)
                } catch {
                    Logger.print("Delete failed: \(error)", level: .error)
                }
            }
            
            // MARK: - COMPRESS
            
        case .compress:
            Logger.print("compress", level: .debug)
            
            ThreadManager.shared.background {
                do {
                    let zipData = try DOCHelper.shared.compressPDFAndReturnZip(
                        from: file.url,
                        name: file.name
                    )
                    
                    let baseName = DOCHelper.shared.fileName(from: file.url)
                    let zipName = "\(baseName).zip"
                    
                    try FileStorageManager.store(zipData, at: zipName, in: .documents)
                    
                    ThreadManager.shared.main {
                        self.loadFiles()
                    }
                    
                    Logger.print("Compression successful", level: .success)
                    
                } catch {
                    Logger.print("Compression failed: \(error)", level: .error)
                }
            }
            
            // MARK: - DUPLICATE
            
        case .duplicate:
            do {
                _ = try FileStorageManager.duplicate(at: file.url)
                self.loadFiles()
                Logger.print("Duplicate successful", level: .success)
            } catch {
                Logger.print("Duplicate failed: \(error)", level: .error)
            }
            
            // MARK: - EMAIL
            
        case .email:
            MailHelper.shared.shareFileViaMail(
                fileURL: file.url,
                from: self,
                subject: "PDF File",
                body: "Here is the file you requested."
            )
            
            // MARK: - SHARE
            
        case .share:
            DOCHelper.shared.shareFile(fileURL: file.url, vc: self)
            
            // MARK: - PASSWORD
            
        case .setPassword:
            
            AlertHelper.shared.textFieldAlert(
                title: "Set Password",
                placeHolder: "Enter password",
                vc: self,
                saprated: false
            ) { [weak self] password in
                
                guard let self = self,
                      let password,
                      !password.isEmpty else { return }
                
                PDFProtectionManager.shared.setPassword(password, for: file.url)
                
                Logger.print("Password saved locally", level: .success)
                self.loadFiles()
            }
            
            // MARK: - MERGE
            
        case .merge:
            let allFiles = items.compactMap {
                if case .file(let f) = $0 { return f }
                return nil
            }
            NavigationManager.shared.navigateToMErgePDFVC(
                from: self,
                isSplit: false,
                isOrganize: false,
                count: 0,
                pdfURL: nil,
                url: allFiles
            )
            
            // MARK: - Organize
            
        case .organize:
            Logger.print("Organize PDF")
            let pageCount = DOCHelper.shared.getPDFPageCount(fileURL: file.url)
            let allFiles = items.compactMap {
                if case .file(let f) = $0 { return f }
                return nil
            }
            NavigationManager.shared.navigateToMErgePDFVC(
                from: self,
                isSplit: false,
                isOrganize: true,
                count: pageCount,
                pdfURL: file.url,
                url: allFiles
            )
            
            // MARK: - SPLIT
            
        case .split:
            let pageCount = DOCHelper.shared.getPDFPageCount(fileURL: file.url)
            let allFiles = items.compactMap {
                if case .file(let f) = $0 { return f }
                return nil
            }
            NavigationManager.shared.navigateToMErgePDFVC(
                from: self,
                isSplit: true,
                isOrganize: false,
                count: pageCount,
                pdfURL: file.url,
                url: allFiles
            )
            
            // MARK: - COPY
            
        case .copy:
            Logger.print("copy", level: .debug)
            
            let folders = items.compactMap {
                if case .folder(let folder) = $0 { return folder }
                return nil
            }
            
            AlertHelper.shared.showFolderSelectionSheet(
                folders: folders,
                title: "Where to paste?",
                on: self
            ) { [weak self] selectedFolder in
                
                guard let self = self else { return }
                
                ThreadManager.shared.background {
                    do {
                        var destinationURL = selectedFolder.url.appendingPathComponent(file.url.lastPathComponent)
                        var count = 1
                        while FileStorageManager.exists(at: destinationURL.path()) {
                            let newNAME = "\(file.url.deletingLastPathComponent().lastPathComponent)_\(count).\(file.url.pathExtension)"
                            destinationURL = selectedFolder.url.appendingPathComponent(newNAME)
                            count += 1
                        }
                        try FileStorageManager.copy(from: file.url, to: destinationURL)
                        
                        Logger.print("File copied successfully", level: .success)
                        
                        ThreadManager.shared.main {
                            self.loadFiles()
                        }
                        
                    } catch {
                        Logger.print("Copy failed: \(error.localizedDescription)", level: .error)
                    }
                }
            }
            
            // MARK: - MOVE
        case .move:
            Logger.print("Move", level: .debug)
            
            let folders = items.compactMap {
                if case .folder(let folder) = $0 { return folder }
                return nil
            }
            
            AlertHelper.shared.showFolderSelectionSheet(
                folders: folders,
                title: "Where to Move?",
                on: self
            ) { [weak self] selectedFolder in
                
                guard let self = self else { return }
                
                ThreadManager.shared.background {
                    do {
                        var destinationURL = selectedFolder.url.appendingPathComponent(file.url.lastPathComponent)
                        var count = 1
                        while FileStorageManager.exists(at: destinationURL.path()) {
                            let newName = "\(file.url.deletingPathExtension().lastPathComponent)_\(count).\(file.url.pathExtension)"
                            destinationURL = selectedFolder.url.appendingPathComponent(newName)
                            count += 1
                        }
                        
                        try FileStorageManager.move(from: file.url, to: destinationURL)
                        
                        Logger.print("File copied successfully", level: .success)
                        
                        ThreadManager.shared.main {
                            self.loadFiles()
                        }
                    }
                    catch {
                        Logger.print("Move failed: \(error.localizedDescription)", level: .error)
                    }
                }
            }
            
        case .markTag:
            
            guard case .file(var file) = items[index] else { return }
            
            NavigationManager.shared.navigateToMarkTagVC(
                from: self,
                index: index,
                selectedColor: file.tagColor
            ) { [weak self] selectedColor in
                
                guard let self = self else { return }
                file.tagColor = selectedColor
                self.items[index] = .file(file)
                self.tableView_allFiles.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            }
         
        case .info:
            
            guard case .file(let file) = items[index] else { return }
            let name = file.name
            let pages = DOCHelper.shared.getPDFPageCount(fileURL: file.url)
            let fileSize = file.size ?? Int64()
            let created = file.creationDate
            NavigationManager.shared.navigateToInfoVC(from: self, creationDate: "\(created!)", size: fileSize, name: name, page: "\(pages)")
        }
    }
}
