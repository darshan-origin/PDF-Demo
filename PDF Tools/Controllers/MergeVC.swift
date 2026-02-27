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
        view_topNav.applyShadow()
        lbl_screenTitle.text = isSplit ? "Split PDF" : (isOrganize ? "Organize PDF" : "Merge PDF")
        btn_actionButtonm.setTitle(lbl_screenTitle.text, for: .normal)
        if isOrganize {
            tableview_allPDFs.isEditing = true
            pageOrder = Array(0..<pdfPageCount)
        }
        tableview_allPDFs.register(UINib(nibName: "cellAllFilesPDFs", bundle: .main), forCellReuseIdentifier: "cellAllFilesPDFs")
        tableview_allPDFs.dataSource = self
        tableview_allPDFs.delegate = self
    }
    
    @IBAction func onTapped_back(_ sender: Any) {
        NavigationManager.shared.popViewController(from: self)
    }
    
    @IBAction func onTapped_merge(_ sender: Any) {
        if isOrganize || isSplit {
            guard let url = fileURL else { return }
            let pages = isOrganize ? pageOrder.map { $0 + 1 } : selectedIndexes.sorted().map { $0 + 1 }
            performPDFAction(title: isOrganize ? "organized" : "splitted") {
                self.isOrganize ? DOCHelper.shared.reorderPDF(sourceURL: url, pageNumbers: pages) : 
                           DOCHelper.shared.splitPdfByPageNumbers(sourceURL: url, pageNumbers: pages)
            }
        } else {
            let selectedURLs = selectedIndexes.sorted().compactMap { $0 < filesArray.count ? filesArray[$0].url : nil }
            performPDFAction(title: "merged", isMerge: true) { DOCHelper.shared.mergePDFs(from: selectedURLs) }
        }
    }
    
    private func performPDFAction(title: String, isMerge: Bool = false, action: @escaping () -> Data?) {
        LoaderView.shared.show(on: self.view)
        ThreadManager.shared.background { [weak self] in
            guard let self = self, let data = action() else { ThreadManager.shared.main { LoaderView.shared.hide() }; return }
            do {
                let name = "\(DOCHelper.shared.getCustomFormattedDateTime())_\(title)"
                try FileStorageManager.store(data, at: "\(name).pdf", in: .documents)
                let storedURL = FileStorageManager.url(for: "\(name).pdf", in: .documents)
                ThreadManager.shared.main {
                    LoaderView.shared.hide()
                    isMerge ? NavigationManager.shared.popROOTViewController(from: self) : 
                             NavigationManager.shared.navigateToPDFViewVC(from: self, url: "\(storedURL)")
                }
            } catch {
                ThreadManager.shared.main { LoaderView.shared.hide() }
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
        } else {
            cell.lbl_fileName.text = "Page \((isOrganize ? pageOrder[indexPath.row] : indexPath.row) + 1)"
            cell.lbl_sizeANDtime.text = ""
            cell.img_thumbnail.image = UIImage(systemName: "doc.richtext")
        }
        let isSelected = selectedIndexes.contains(indexPath.row)
        cell.btn_checkmark.setImage(isOrganize ? nil : UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle"), for: .normal)
        cell.btn_checkmark.tintColor = isSelected ? .systemBlue : .systemGray3
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isOrganize { return }
        if selectedIndexes.contains(indexPath.row) { selectedIndexes.remove(indexPath.row) }
        else { selectedIndexes.insert(indexPath.row) }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
