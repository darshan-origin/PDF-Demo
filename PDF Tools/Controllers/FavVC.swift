import UIKit
import PDFKit
import PDFCompressorKit

class FavVC: UIViewController {

    @IBOutlet weak var tableview_favourites: UITableView!
    
    private var items: [WorkItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFavorites()
    }
    
    private func setupTableView() {
        tableview_favourites.register(UINib(nibName: "cellAllFiles", bundle: .main), forCellReuseIdentifier: "cellAllFiles")
        tableview_favourites.delegate = self
        tableview_favourites.dataSource = self
    }
    
    func loadFavorites() {
        items = FavoriteManager.shared.favoriteFiles.map { .file($0) }
        tableview_favourites.reloadData()
    }
}

extension FavVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 140
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellAllFiles", for: indexPath) as! cellAllFiles
        let item = items[indexPath.row]
        
        if case .file(let file) = item {
            cell.lbl_fileName.text = file.name
            cell.lbl_sizeANDtime.text = file.sizeAndTime
            cell.btn_moreInfo.menu = makeMenu(for: indexPath.row)
            cell.btn_moreInfo.showsMenuAsPrimaryAction = true
            cell.btn_moreInfo.isHidden = false
            cell.btn_favourite.isHidden = false
            
            // In FavVC, it's always a favourite initially
            cell.btn_favourite.setImage(UIImage(systemName: "heart.fill"), for: .normal)
            
            cell.didTapFavourite = { [weak self] in
                guard let self = self else { return }
                FavoriteManager.shared.toggleFavorite(file)
                self.loadFavorites() // Reload list since it's the favorites screen
            }

            if let tagColor = file.tagColor {
                cell.view_tag.isHidden = false
                cell.view_tag.backgroundColor = tagColor
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
        guard case .file(let file) = items[indexPath.row] else { return }
        
        if file.url.pathExtension == "jpg" {
            openImageViewer(with: "\(file.url)")
        } else if file.url.pathExtension == "zip" {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            DOCHelper.shared.unzipFile(fromWhich: file.url, destinationURL: documentsURL)
            loadFavorites()
        } else if file.url.pathExtension == "pdf" {
            handlePDFOpening(file: file)
        }
    }
}

extension FavVC {
    
    private func handlePDFOpening(file: FilesMetaDataModel) {
        if file.isProtected {
            AlertHelper.shared.textFieldAlert(title: "Enter Password", placeHolder: "Password", vc: self, saprated: false) { [weak self] enteredPassword in
                guard let self = self, let enteredPassword else { return }
                let savedPassword = PDFProtectionManager.shared.getPassword(for: file.url)
                if enteredPassword == savedPassword {
                    self.presentPDF(url: file.url)
                } else {
                    Logger.print("Wrong password", level: .error)
                }
            }
        } else {
            presentPDF(url: file.url)
        }
    }
    
    private func presentPDF(url: URL) {
        let previewVC = PDFViewVC(url: url)
        let nav = UINavigationController(rootViewController: previewVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
    
    func openImageViewer(with url: String) {
        let viewer = CommonImageViewerVC(imageUrl: url)
        present(viewer, animated: true, completion: nil)
    }
    
    func makeMenu(for index: Int) -> UIMenu {
        guard case .file(let file) = items[index] else { return UIMenu(title: "", children: []) }
        
        var actions: [UIAction] = []
        for action in FileAction.allCases {
            if action == .setPassword {
                let title = file.isProtected ? "Remove Password" : action.rawValue
                let setPasswordAction = UIAction(title: title) { [weak self] _ in
                    if file.isProtected {
                        PDFProtectionManager.shared.removePassword(for: file.url)
                        self?.loadFavorites()
                    } else {
                        self?.handle(action, at: index)
                    }
                }
                actions.append(setPasswordAction)
            } else {
                let normalAction = UIAction(title: action.rawValue) { [weak self] _ in
                    self?.handle(action, at: index)
                }
                actions.append(normalAction)
            }
        }
        return UIMenu(title: "PDF Edit", children: actions)
    }
    
    private func handle(_ action: FileAction, at index: Int) {
        guard case .file(let file) = items[index] else { return }
        
        switch action {
        case .rename:
            AlertHelper.shared.textFieldAlert(title: "Rename File", placeHolder: "Rename this file", vc: self, saprated: false, keyboardType: .asciiCapable) { [weak self] newName in
                guard let self = self, let newName, !newName.isEmpty else { return }
                LoaderView.shared.show(on: self.view)
                do {
                    try FileStorageManager.rename(at: file.url, to: "\(newName).\(file.url.pathExtension)")
                    self.loadFavorites()
                    LoaderView.shared.hide()
                } catch {
                    LoaderView.shared.hide()
                    Logger.print("Rename failed: \(error)", level: .error)
                }
            }
            
        case .delete:
            AlertHelper.shared.showAlert(on: self, title: "Delete File", message: "Are you sure you want to delete this file?", actions: [("Cancel", .cancel), ("OK", .destructive)]) { [weak self] selectedAction in
                guard let self = self, selectedAction == "OK" else { return }
                LoaderView.shared.show(on: self.view)
                do {
                    try FileStorageManager.delete(at: file.url)
                    self.loadFavorites()
                    LoaderView.shared.hide()
                } catch {
                    LoaderView.shared.hide()
                    Logger.print("Delete failed: \(error)", level: .error)
                }
            }
            
        case .compress:
            LoaderView.shared.show(on: self.view)
            ThreadManager.shared.background {
                do {
                    let zipData = try DOCHelper.shared.compressPDFAndReturnZip(from: file.url, name: file.name)
                    let baseName = DOCHelper.shared.fileName(from: file.url)
                    try FileStorageManager.store(zipData, at: "\(baseName).zip", in: .documents)
                    ThreadManager.shared.main { 
                        self.loadFavorites() 
                        LoaderView.shared.hide()
                    }
                } catch {
                    ThreadManager.shared.main {
                        LoaderView.shared.hide()
                    }
                    Logger.print("Compression failed: \(error)", level: .error)
                }
            }
            
        case .compressSize:
            guard file.url.pathExtension.lowercased() == "pdf" else { return }
            LoaderView.shared.show(on: self.view)
            ThreadManager.shared.background {
                do {
                    try DOCHelper.shared.compressPDF(at: file.url)
                    ThreadManager.shared.main {
                        self.loadFavorites()
                        LoaderView.shared.hide()
                    }
                } catch {
                    ThreadManager.shared.main {
                        LoaderView.shared.hide()
                    }
                    Logger.print("Compression failed: \(error)", level: .error)
                }
            }
            
        case .duplicate:
            do {
                _ = try FileStorageManager.duplicate(at: file.url)
                loadFavorites()
            } catch {
                Logger.print("Duplicate failed: \(error)", level: .error)
            }
            
        case .email:
            MailHelper.shared.shareFileViaMail(fileURL: file.url, from: self, subject: "PDF File", body: "Here is the file you requested.")
            
        case .share:
            DOCHelper.shared.shareFile(fileURL: file.url, vc: self)
            
        case .setPassword:
            AlertHelper.shared.textFieldAlert(title: "Set Password", placeHolder: "Enter password", vc: self, saprated: false) { [weak self] password in
                guard let self = self, let password, !password.isEmpty else { return }
                PDFProtectionManager.shared.setPassword(password, for: file.url)
                self.loadFavorites()
            }
            
        case .merge, .organize, .split:
            let allFiles = items.compactMap { if case .file(let f) = $0 { return f }; return nil }
            let pageCount = DOCHelper.shared.getPDFPageCount(fileURL: file.url)
            NavigationManager.shared.navigateToMErgePDFVC(
                from: self,
                isSplit: action == .split,
                isOrganize: action == .organize,
                count: action == .merge ? 0 : pageCount,
                pdfURL: action == .merge ? nil : file.url,
                url: allFiles
            )
            
        case .copy, .move:
            let folders = FileStorageManager.fetchFoldersFromDocumentDirectory()
            AlertHelper.shared.showFolderSelectionSheet(folders: folders, title: "Choose Folder", on: self) { [weak self] selectedFolder in
                guard let self = self else { return }
                LoaderView.shared.show(on: self.view)
                ThreadManager.shared.background {
                    do {
                        let destinationURL = selectedFolder.url.appendingPathComponent(file.url.lastPathComponent)
                        if action == .copy {
                            try FileStorageManager.copy(from: file.url, to: destinationURL)
                        } else {
                            try FileStorageManager.move(from: file.url, to: destinationURL)
                        }
                        ThreadManager.shared.main { 
                            self.loadFavorites() 
                            LoaderView.shared.hide()
                        }
                    } catch {
                        ThreadManager.shared.main {
                            LoaderView.shared.hide()
                        }
                        Logger.print("Action failed: \(error.localizedDescription)", level: .error)
                    }
                }
            }
            
        case .markTag:
            NavigationManager.shared.navigateToMarkTagVC(from: self, index: index, selectedColor: file.tagColor) { [weak self] selectedColor in
                guard let self = self else { return }
                var updatedFile = file
                updatedFile.tagColor = selectedColor
                FavoriteManager.shared.updateFavorite(updatedFile)
                self.items[index] = .file(updatedFile)
                self.tableview_favourites.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            }
            
        case .info:
            let pages = DOCHelper.shared.getPDFPageCount(fileURL: file.url)
            NavigationManager.shared.navigateToInfoVC(from: self, creationDate: "\(file.creationDate!)", size: file.size ?? 0, name: file.name, page: "\(pages)")
        }
    }
}
