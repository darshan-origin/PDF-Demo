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
        tableView_allFiles.register(UINib(nibName: "cellAllFiles", bundle: .main), forCellReuseIdentifier: "cellAllFiles")
        tableView_allFiles.delegate = self
        tableView_allFiles.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        loadFiles()
    }
    
    @IBAction func onTapped_importPDF(_ sender: Any) {
        DocumentPickerHelper.openDoc(type: .pdf, from: self) { [weak self] selectedURL in
            guard let self = self, let sourceURL = selectedURL else { return }
            LoaderView.shared.show(on: self.view)
            do {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsURL.appendingPathComponent(sourceURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                self.loadFiles()
                LoaderView.shared.hide()
            } catch {
                LoaderView.shared.hide()
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
        LoaderView.shared.show(on: self.view)
        ThreadManager.shared.background { [weak self] in
            guard let self = self else { return }
            let directoryURL = self.currentDirectoryURL ?? FileStorageManager.documentsDirectoryURL()
            var tempItems: [WorkItem] = []
            
            if self.currentDirectoryURL == nil {
                tempItems = FileStorageManager.fetchFoldersFromDocumentDirectory().map { .folder($0) }
            }
            
            let fileItems = FileStorageManager.fetchFiles(in: directoryURL).map { url -> WorkItem in
                .file(FilesMetaDataModel(
                    url: url,
                    name: url.lastPathComponent,
                    thumbnail: DOCHelper.shared.generateThumbnailSync(for: url),
                    size: FileStorageManager.fileSize(at: url),
                    creationDate: FileStorageManager.getFileCreationDate(for: url),
                    sizeAndTime: FileStorageManager.sizeAndDateString(for: url),
                    folderData: nil,
                    isProtected: PDFProtectionManager.shared.isProtected(url),
                    tagColor: nil
                ))
            }
            
            ThreadManager.shared.main {
                self.items = tempItems + fileItems
                self.title = self.currentDirectoryURL?.lastPathComponent ?? "My Works"
                self.tableView_allFiles.reloadData()
                LoaderView.shared.hide()
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
            cell.lbl_sizeANDtime.text = "Folder • \(ByteCountFormatter.string(fromByteCount: folder.size, countStyle: .file))"
            cell.img_thumbnail.image = UIImage(systemName: "folder.fill")
            [cell.view_tag, cell.btn_moreInfo, cell.btn_favourite].forEach { $0?.isHidden = true }
            
        case .file(let file):
            cell.lbl_fileName.text = file.name
            cell.lbl_sizeANDtime.text = file.sizeAndTime
            cell.btn_moreInfo.menu = makeMenu(for: indexPath.row)
            cell.btn_moreInfo.showsMenuAsPrimaryAction = true
            [cell.btn_moreInfo, cell.btn_favourite].forEach { $0?.isHidden = false }
            
            let isFav = FavoriteManager.shared.isFavorite(file)
            cell.btn_favourite.setImage(UIImage(systemName: isFav ? "heart.fill" : "heart"), for: .normal)
            cell.didTapFavourite = { [weak self] in
                FavoriteManager.shared.toggleFavorite(file)
                self?.tableView_allFiles.reloadRows(at: [indexPath], with: .none)
            }

            cell.view_tag.isHidden = file.tagColor == nil
            cell.view_tag.backgroundColor = file.tagColor
            cell.view_tag.layer.cornerRadius = cell.view_tag.frame.height / 2
            cell.img_thumbnail.image = file.url.pathExtension == "zip" ? UIImage(named: "ic_zip") : file.thumbnail
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
            let ext = file.url.pathExtension
            if ext == "jpg" { openImageViewer(with: "\(file.url)") }
            if ext == "zip" {
                DOCHelper.shared.unzipFile(fromWhich: file.url, destinationURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!)
                loadFiles()
            }
            if ext == "pdf" {
                if file.isProtected {
                    AlertHelper.shared.textFieldAlert(title: "Enter Password", placeHolder: "Password", vc: self, saprated: false) { [weak self] enteredPassword in
                        guard let self = self, let enteredPassword = enteredPassword,
                              enteredPassword == PDFProtectionManager.shared.getPassword(for: file.url) else { return }
                        self.presentPDF(url: file.url)
                    }
                } else {
                    presentPDF(url: file.url)
                }
            }
        }
    }
    
    private func presentPDF(url: URL) {
        let previewVC = PDFViewVC(url: url)
        let nav = UINavigationController(rootViewController: previewVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
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
        var folders = items.folders
        var files = items.files
        
        switch action {
        case .createdDate:
            folders.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
            files.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        case .az:
            folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .za:
            folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
            files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .size:
            folders.sort { $0.size > $1.size }
            files.sort { ($0.size ?? 0) > ($1.size ?? 0) }
        }
        items = folders.map { .folder($0) } + files.map { .file($0) }
        tableView_allFiles.reloadData()
    }
    
    private func handle(_ action: FileAction, at index: Int) {
        guard case .file(var file) = items[index] else { return }
        
        switch action {
        case .rename:
            AlertHelper.shared.textFieldAlert(title: "Rename File", placeHolder: "Rename this file", vc: self, saprated: false) { newName in
                guard let newName = newName, !newName.isEmpty else { return }
                try? FileStorageManager.rename(at: file.url, to: "\(newName).\(file.url.pathExtension)")
                self.loadFiles()
            }
            
        case .delete:
            AlertHelper.shared.showAlert(on: self, title: "Delete File", message: "Are you sure you want to delete this file?", actions: [("Cancel", .cancel), ("OK", .destructive)]) { action in
                if action == "OK" { try? FileStorageManager.delete(at: file.url); self.loadFiles() }
            }
            
        case .compress:
            performBackgroundAction {
                let zipData = try DOCHelper.shared.compressPDFAndReturnZip(from: file.url, name: file.name)
                try FileStorageManager.store(zipData, at: "\(DOCHelper.shared.fileName(from: file.url)).zip", in: .documents)
            }
            
        case .duplicate:
            _ = try? FileStorageManager.duplicate(at: file.url); loadFiles()
            
        case .email:
            MailHelper.shared.shareFileViaMail(fileURL: file.url, from: self, subject: "PDF File", body: "Requested file.")
            
        case .share:
            DOCHelper.shared.shareFile(fileURL: file.url, vc: self)
            
        case .setPassword:
            AlertHelper.shared.textFieldAlert(title: "Set Password", placeHolder: "Enter password", vc: self, saprated: false) { [weak self] pwd in
                guard let pwd = pwd, !pwd.isEmpty else { return }
                PDFProtectionManager.shared.setPassword(pwd, for: file.url)
                self?.loadFiles()
            }
            
        case .merge, .organize, .split:
            let isSplit = action == .split
            let isOrg = action == .organize
            NavigationManager.shared.navigateToMErgePDFVC(from: self, isSplit: isSplit, isOrganize: isOrg,
                count: isSplit || isOrg ? DOCHelper.shared.getPDFPageCount(fileURL: file.url) : 0,
                pdfURL: isSplit || isOrg ? file.url : nil, url: items.files)
            
        case .copy, .move:
            AlertHelper.shared.showFolderSelectionSheet(folders: items.folders, title: action == .copy ? "Copy to" : "Move to", on: self) { [weak self] folder in
                self?.performBackgroundAction {
                    let dest = self?.getUniqueDestination(for: file.url, in: folder.url) ?? folder.url
                    action == .copy ? try FileStorageManager.copy(from: file.url, to: dest) : try FileStorageManager.move(from: file.url, to: dest)
                }
            }
            
        case .markTag:
            NavigationManager.shared.navigateToMarkTagVC(from: self, index: index, selectedColor: file.tagColor) { [weak self] color in
                file.tagColor = color
                self?.items[index] = .file(file)
                FavoriteManager.shared.updateFavorite(file)
                self?.tableView_allFiles.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            }
         
        case .info:
            NavigationManager.shared.navigateToInfoVC(from: self, creationDate: "\(file.creationDate!)", size: file.size ?? 0, name: file.name, page: "\(DOCHelper.shared.getPDFPageCount(fileURL: file.url))")
        }
    }
    
    private func performBackgroundAction(_ action: @escaping () throws -> Void) {
        LoaderView.shared.show(on: self.view)
        ThreadManager.shared.background {
            try? action()
            ThreadManager.shared.main { self.loadFiles(); LoaderView.shared.hide() }
        }
    }
    
    private func getUniqueDestination(for source: URL, in folder: URL) -> URL {
        var dest = folder.appendingPathComponent(source.lastPathComponent)
        var count = 1
        while FileStorageManager.exists(at: dest.path()) {
            dest = folder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)_\(count).\(source.pathExtension)")
            count += 1
        }
        return dest
    }
}

extension Array where Element == WorkItem {
    var folders: [FolderModel] { compactMap { if case .folder(let f) = $0 { return f }; return nil } }
    var files: [FilesMetaDataModel] { compactMap { if case .file(let f) = $0 { return f }; return nil } }
}
