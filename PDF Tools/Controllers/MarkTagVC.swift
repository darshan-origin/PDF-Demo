import UIKit

class MarkTagVC: UIViewController {

    @IBOutlet weak var view_base: UIView!
    @IBOutlet weak var colorPicker: UIColorWell!
    @IBOutlet weak var view_selectedColorPreview: UIView!
    
    var onColorSelected: ((UIColor?) -> Void)?
    var selectedColor: UIColor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        if let selectedColor = selectedColor {
            colorPicker.selectedColor = selectedColor
            view_selectedColorPreview.backgroundColor = selectedColor
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view_base.layer.cornerRadius = 12
        
        view_selectedColorPreview.layer.cornerRadius = view_selectedColorPreview.frame.height / 2
        view_selectedColorPreview.layer.borderWidth = 1
        view_selectedColorPreview.layer.borderColor = UIColor.lightGray.cgColor
    
        view_selectedColorPreview.backgroundColor = .clear
        colorPicker.addTarget(self, action: #selector(colorChanged), for: .valueChanged)
    }

    @objc func colorChanged() {
        view_selectedColorPreview.backgroundColor = colorPicker.selectedColor
    }
    
    @IBAction func onTapped_close(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func onTappped_clear(_ sender: Any) {
        colorPicker.selectedColor = nil
        view_selectedColorPreview.backgroundColor = .clear
    }
    
    @IBAction func onTappped_add(_ sender: Any) {
        let color = view_selectedColorPreview.backgroundColor
        onColorSelected?(color == .clear ? nil : color)
        dismiss(animated: true)
    }
}
