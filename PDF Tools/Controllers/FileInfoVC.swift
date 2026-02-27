import UIKit

class FileInfoVC: UIViewController {
    
    @IBOutlet weak var lbl_name: UILabel!
    @IBOutlet weak var lbl_page: UILabel!
    @IBOutlet weak var lbl_fileSize: UILabel!
    @IBOutlet weak var lbl_created: UILabel!
    @IBOutlet weak var view_base: UIView!
    
    var name = "", pages = "", created = ""
    var fileSize: Int64 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        Logger.print("\(name) | \(pages) | \(fileSize) | \(created)", level: .info)
        
        view.backgroundColor = .black.withAlphaComponent(0.7)
        view_base.layer.cornerRadius = 12
        
        lbl_name.text = name
        lbl_page.text = "\(pages) Pages"
        lbl_fileSize.text = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        if let date = formatter.date(from: created) {
            formatter.dateFormat = "dd-MMM-yyyy 'at' HH:mm"
            lbl_created.text = formatter.string(from: date)
        }
    }
    
    @IBAction func onTapped_close(_ sender: Any) {
        dismiss(animated: true)
    }
}
