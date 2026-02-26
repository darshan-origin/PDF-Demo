import UIKit

class MergeVC: UIViewController {
    
    @IBOutlet weak var view_topNav: UIView!
    @IBOutlet weak var tableview_allPDFs: UITableView!
    @IBOutlet weak var lbl_screenTitle: UILabel!
    @IBOutlet weak var btn_actionButtonm: UIButton!
    
    var filesArray: [FilesMetaDataModel] = []
    var selectedIndexes: Set<Int> = []
    var isSplit: Bool = false
    var isOrganize: Bool = false
    var pdfPageCount: Int = 0
    var fileURL: URL?
    var pageOrder: [Int] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
    }
    
    func initUI() {
        view_topNav.applyShadow()
        
        if isSplit {
            lbl_screenTitle.text = "Split PDF"
            btn_actionButtonm.setTitle("Split PDF", for: .normal)
        } else if isOrganize {
            tableview_allPDFs.isEditing = true
            pageOrder = Array(0..<pdfPageCount)
            lbl_screenTitle.text = "Organize PDF"
            btn_actionButtonm.setTitle("Organize PDF", for: .normal)
        } else {
            lbl_screenTitle.text = "Merge PDF"
            btn_actionButtonm.setTitle("Merge PDF", for: .normal)
        }
        tableviewConfig()
        tableview_allPDFs.reloadData()
    }
    
    func tableviewConfig() {
        tableview_allPDFs.register(UINib(nibName: "cellAllFilesPDFs", bundle: .main), forCellReuseIdentifier: "cellAllFilesPDFs")
        tableview_allPDFs.delegate = self
        tableview_allPDFs.dataSource = self
    }
    
    @IBAction func onTapped_back(_ sender: Any) {
        NavigationManager.shared.popViewController(from: self)
    }
    
    @IBAction func onTapped_merge(_ sender: Any) {
        
        if isOrganize {
            guard let sourceURL = fileURL else { return }
            let orderedPages = pageOrder.map { $0 + 1 }
            
            ThreadManager.shared.background { [weak self] in
                guard let self else { return }
                
                if let data = DOCHelper.shared.reorderPDF( sourceURL: sourceURL, pageNumbers: orderedPages ) {
                    do {
                        let newName = "\(DOCHelper.shared.getCustomFormattedDateTime())_organized"
                        try FileStorageManager.store( data, at: "\(newName).pdf", in: .documents)
                        
                        let storedURL = FileStorageManager.url( for: "\(newName).pdf", in: .documents)
                        
                        ThreadManager.shared.main {
                            NavigationManager.shared.navigateToPDFViewVC( from: self,url: "\(storedURL)")
                        }
                    } catch {
                        Logger.print("Error storing organized PDF: \(error)", level: .error)
                    }
                }
            }
            
        }
        else if isSplit {
            
            guard let sourceURL = fileURL else { return }
            
            let pageNumbers = selectedIndexes
                .sorted()
                .map { $0 + 1 }
            
            ThreadManager.shared.background { [weak self] in
                guard let self else { return }
                
                if let data = DOCHelper.shared.splitPdfByPageNumbers(
                    sourceURL: sourceURL,
                    pageNumbers: pageNumbers
                ) {
                    do {
                        let newName = "\(DOCHelper.shared.getCustomFormattedDateTime())_splitted"
                        try FileStorageManager.store(data, at: "\(newName).pdf",in: .documents)
                        let storedURL = FileStorageManager.url(for: "\(newName).pdf",in: .documents)
                        ThreadManager.shared.main {
                            NavigationManager.shared.navigateToPDFViewVC(from: self,url: "\(storedURL)")
                        }
                    } catch {
                        Logger.print("Error storing split PDF: \(error)", level: .error)
                    }
                }
            }
            
        } else {
            
            let selectedURLs: [URL] = selectedIndexes
                .sorted()
                .compactMap { index in
                    guard index < filesArray.count else { return nil }
                    return filesArray[index].url
                }
            mergeingPDF(files: selectedURLs)
        }
    }
    
    func mergeingPDF(files: [URL]) {
        ThreadManager.shared.background { [weak self] in
            guard let self else { return }
            
            let mergedFileName = "\(DOCHelper.shared.getCustomFormattedDateTime())_merged"
            
            if let mergedPDFData = DOCHelper.shared.mergePDFs(from: files) {
                do {
                    try FileStorageManager.store(mergedPDFData,at: "\(mergedFileName).pdf", in: .documents)
                    ThreadManager.shared.main {
                        NavigationManager.shared.popROOTViewController(from: self)
                    }
                } catch {
                    Logger.print("Error storing merged PDF: \(error)", level: .error)
                }
            }
        }
    }
}

extension MergeVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableview: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (isSplit || isOrganize) ? pdfPageCount : filesArray.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return isOrganize
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard isOrganize else { return }
        let movedItem = pageOrder.remove(at: sourceIndexPath.row)
        pageOrder.insert(movedItem, at: destinationIndexPath.row)
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellAllFilesPDFs", for: indexPath) as! cellAllFilesPDFs
        
        if !isSplit && !isOrganize {
            let model = filesArray[indexPath.row]
            cell.lbl_fileName.text = model.name
            cell.lbl_sizeANDtime.text = model.sizeAndTime
            cell.img_thumbnail.image = model.thumbnail
        } else if isSplit {
            cell.lbl_fileName.text = "Page \(indexPath.row + 1)"
            cell.lbl_sizeANDtime.text = ""
            cell.img_thumbnail.image = UIImage(systemName: "doc.richtext")
        } else {
            let originalPageIndex = pageOrder[indexPath.row]
            cell.lbl_fileName.text = "Page \(originalPageIndex + 1)"
            cell.lbl_sizeANDtime.text = ""
            cell.img_thumbnail.image = UIImage(systemName: "doc.richtext")
        }
        
        if !isOrganize {
            let isSelected = selectedIndexes.contains(indexPath.row)
            let imageName = isSelected ? "checkmark.circle.fill" : "circle"
            cell.btn_checkmark.setImage(UIImage(systemName: imageName), for: .normal)
            cell.btn_checkmark.tintColor = isSelected ? .systemBlue : .systemGray3
        } else {
            cell.btn_checkmark.setImage(nil, for: .normal)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if isOrganize { return }
        
        if selectedIndexes.contains(indexPath.row) {
            selectedIndexes.remove(indexPath.row)
        } else {
            selectedIndexes.insert(indexPath.row)
        }
        
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
