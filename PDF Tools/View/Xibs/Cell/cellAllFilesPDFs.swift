import UIKit

class cellAllFilesPDFs: UITableViewCell {

    @IBOutlet weak var img_thumbnail: UIImageView!
    @IBOutlet weak var view_base: UIView!
    @IBOutlet weak var lbl_fileName: UILabel!
    @IBOutlet weak var btn_checkmark: UIButton!
    @IBOutlet weak var lbl_sizeANDtime: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        initUI()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

extension cellAllFilesPDFs {
    
    func initUI() {
        ThreadManager.shared.main { [self] in
            img_thumbnail.layer.cornerRadius = 10
            img_thumbnail.layer.masksToBounds = true
            view_base.layer.cornerRadius = 12
            view_base.layer.masksToBounds = true
            view_base.applyShadow()
        }
    }
}
