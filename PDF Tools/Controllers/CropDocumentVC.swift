import UIKit
import CropViewController

protocol CropDocumentVCDelegate: AnyObject {
    func cropDocumentVC(_ controller: CropDocumentVC, didUpdateImages images: [UIImage])
}

class CropDocumentVC: UIViewController {
    
    @IBOutlet weak var view_topNav: UIView!
    @IBOutlet weak var view_bottomBase: UIView!
    @IBOutlet weak var btn_left: UIButton!
    @IBOutlet weak var btn_right: UIButton!
    @IBOutlet weak var lbl_counter: UILabel!
    @IBOutlet weak var img_passedImageView: UIImageView!
    @IBOutlet var img_features: [UIImageView]!
    @IBOutlet var lbl_featuresTitle: [UILabel]!
    
    var selectedPassedImages: [UIImage] = []
    private var originalImages: [UIImage] = []
    var capturedCameraImage: UIImage?
    var onImagesUpdated: (([UIImage]) -> Void)?
    private var currentCount: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
        manageClickableActions()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.isMovingFromParent {
            onImagesUpdated?(selectedPassedImages)
        }
    }
    
    @IBAction func onTapped_left(_ sender: Any) {
        manageImageCounter(isLeft: true)
    }
    
    @IBAction func opnTapped_right(_ sender: Any) {
        manageImageCounter(isLeft: false)
    }
    
    @IBAction func onTapped_back(_ sender: Any) {
        NavigationManager.shared.popViewController(from: self)
    }
}

extension CropDocumentVC {
    
    func initUI() {
        view_topNav.addBottomDropShadow()
        view_bottomBase.layer.cornerRadius = 15
        view_bottomBase.clipsToBounds = true
        view_bottomBase.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        if selectedPassedImages.isEmpty, let image = capturedCameraImage {
            selectedPassedImages = [image]
        }
        
        if originalImages.isEmpty {
            originalImages = selectedPassedImages
        }
        
        currentCount = 0
        updateUI(total: selectedPassedImages.count)
    }
    
    private func updateUI(total: Int) {
        img_passedImageView.image = selectedPassedImages[currentCount]
        lbl_counter.text = "\(currentCount + 1)/\(total)"
        
        btn_left.isHidden = total <= 1
        btn_right.isHidden = total <= 1
        btn_left.isEnabled = currentCount > 0
        btn_right.isEnabled = currentCount < total - 1
    }
}

extension CropDocumentVC {
    
    private func manageImageCounter(isLeft: Bool) {
        guard !selectedPassedImages.isEmpty else { return }
        currentCount = isLeft ? max(currentCount - 1, 0) : min(currentCount + 1, selectedPassedImages.count - 1)
        updateUI(total: selectedPassedImages.count)
    }
}

extension CropDocumentVC {
    
    private func manageClickableActions() {
        for i in 0..<img_features.count {
            img_features[i].isUserInteractionEnabled = true
            lbl_featuresTitle[i].isUserInteractionEnabled = true
            img_features[i].tag = i
            lbl_featuresTitle[i].tag = i
            
            let imageTap = UITapGestureRecognizer(target: self, action: #selector(featureTapped(_:)))
            let labelTap = UITapGestureRecognizer(target: self, action: #selector(featureTapped(_:)))
            img_features[i].addGestureRecognizer(imageTap)
            lbl_featuresTitle[i].addGestureRecognizer(labelTap)
        }
    }
    
    @objc private func featureTapped(_ sender: UITapGestureRecognizer) {
        guard let index = sender.view?.tag else { return }
        switch index {
        case 0: openCropScreen()
        case 1: resetCurrentImage()
        case 2: showDeleteAlert()
        case 3:
            guard let editVC = storyboard?.instantiateViewController(withIdentifier: "EditDocumentVC") as? EditDocumentVC else { return }
            editVC.arrFinalEditableImages = selectedPassedImages // pass updated images
            if selectedPassedImages.count == 1 {
                editVC.capturedCameraImage = selectedPassedImages.first
            }
            navigationController?.pushViewController(editVC, animated: true)
        default: break
        }
    }

    
    private func resetCurrentImage() {
        guard originalImages.indices.contains(currentCount) else { return }
        selectedPassedImages[currentCount] = originalImages[currentCount]
        img_passedImageView.image = originalImages[currentCount]
        onImagesUpdated?(selectedPassedImages)
    }
    
    private func showDeleteAlert() {
        let alertController = UIAlertController(title: "Delete", message: "Are you sure you want to delete this file?", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .default))
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteCurrentImage()
        })
        present(alertController, animated: true)
    }
    
    private func deleteCurrentImage() {
        guard !selectedPassedImages.isEmpty else { return }
        if selectedPassedImages.count == 1 {
            onImagesUpdated?([])
            NavigationManager.shared.popViewController(from: self)
            return
        }
        selectedPassedImages.remove(at: currentCount)
        originalImages.remove(at: currentCount)
        if currentCount >= selectedPassedImages.count {
            currentCount = selectedPassedImages.count - 1
        }
        updateUI(total: selectedPassedImages.count)
        onImagesUpdated?(selectedPassedImages)
    }
}

extension CropDocumentVC: CropViewControllerDelegate {
    
    func openCropScreen() {
        guard let image = img_passedImageView.image else { return }
        let cropVC = CropViewController(image: image)
        cropVC.delegate = self
        present(cropVC, animated: true)
    }
    
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        dismiss(animated: true)
        selectedPassedImages[currentCount] = image
        img_passedImageView.image = image
        onImagesUpdated?(selectedPassedImages)
    }
}
