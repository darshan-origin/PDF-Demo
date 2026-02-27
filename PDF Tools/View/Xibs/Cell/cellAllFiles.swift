import UIKit

class cellAllFiles: UITableViewCell {

    @IBOutlet weak var btn_moreInfo: UIButton!
    @IBOutlet weak var img_thumbnail: UIImageView!
    @IBOutlet weak var view_base: UIView!
    @IBOutlet weak var lbl_fileName: UILabel!
    @IBOutlet weak var lbl_sizeANDtime: UILabel!
    @IBOutlet weak var view_tag: UIView!
    @IBOutlet weak var btn_favourite: UIButton!
    
    var didTapFavourite: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        initUI()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    @IBAction func btnFavouriteTapped(_ sender: UIButton) {
        didTapFavourite?()
    }
}

extension cellAllFiles {
    
    func initUI() {
        ThreadManager.shared.main { [self] in
            img_thumbnail.layer.cornerRadius = 10
            img_thumbnail.layer.masksToBounds = true
            view_base.layer.cornerRadius = 12
            view_base.layer.masksToBounds = true
            view_tag.layer.cornerRadius = view_tag.frame.height / 2
            view_tag.layer.masksToBounds = true
            view_base.applyShadow()
        }
    }
}
