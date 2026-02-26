import UIKit

class FileInfoVC: UIViewController {
    
    @IBOutlet weak var lbl_name: UILabel!
    @IBOutlet weak var lbl_page: UILabel!
    @IBOutlet weak var lbl_fileSize: UILabel!
    @IBOutlet weak var lbl_created: UILabel!
    @IBOutlet weak var view_base: UIView!
    
    var name = ""
    var pages = ""
    var fileSize = Int64()
    var created = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.print(name, level: .info)
        Logger.print(pages, level: .info)
        Logger.print(fileSize, level: .info)
        Logger.print(created, level: .info)
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view_base.layer.cornerRadius = 12
        
        let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        
        lbl_name.text = name
        lbl_page.text = "\(pages) Pages"
        lbl_fileSize.text = "\(formattedSize)"
        
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = inputFormatter.date(from: created) {
            
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "dd-MMM-yyyy 'at' HH:mm"
            outputFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            let formattedDate = outputFormatter.string(from: date)
            lbl_created.text = formattedDate
        }
        
    }
    
    @IBAction func onTapped_close(_ sender: Any) {
        self.dismiss(animated: true)
    }
}

