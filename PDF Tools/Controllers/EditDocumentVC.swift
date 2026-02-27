import UIKit
import CoreImage
import CropViewController

class EditDocumentVC: UIViewController, UITextFieldDelegate, UIGestureRecognizerDelegate, EditableImageViewDelegate {
    
    @IBOutlet weak var view_topNav: UIView!
    @IBOutlet weak var view_bottomBase: UIView!
    @IBOutlet weak var view_editBase: UIView!
    @IBOutlet weak var constraint_bottomView: NSLayoutConstraint!
    @IBOutlet weak var constraint_editView: NSLayoutConstraint!
    
    @IBOutlet weak var lbl_counter: UILabel!
    @IBOutlet var img_features: [UIImageView]!
    @IBOutlet var lbl_featuresTitle: [UILabel]!
    @IBOutlet weak var txt_docName: UITextField!
    @IBOutlet weak var collectionview_passedImages: UICollectionView!
    @IBOutlet weak var collectionview_effectFeatures: UICollectionView!
    
    var arrFinalEditableImages: [UIImage] = []
    var overlayImageViews: [EditableImageView] = []
    var editableImage = UIImage()
    private var selectedOverlay: EditableImageView?
    
    private func updateUI(total: Int) {
        lbl_counter.text = "\(currentCount + 1)/\(total)"
    }
    var arrEffectsFeaturesData: [EffectFeatures] = [
        EffectFeatures (title: "Sign", icon: UIImage(systemName: "signature")!),
        EffectFeatures (title: "Crop", icon: UIImage(systemName: "crop.rotate")!),
        EffectFeatures (title: "Effect", icon: UIImage(systemName: "wand.and.sparkles.inverse")!),
        EffectFeatures (title: "Date", icon: UIImage(systemName: "calendar")!),
        EffectFeatures (title: "Watermark", icon: UIImage(systemName: "wonsign")!),
        EffectFeatures (title: "Stricker", icon: UIImage(systemName: "face.smiling")!),
        EffectFeatures (title: "Filter", icon: UIImage(systemName: "drop.halffull")!),
    ]
    
    var capturedCameraImage: UIImage?
    private var currentCount: Int = 0
    private var bottomBaseOriginalConstant: CGFloat = 0
    private var editBaseOriginalConstant: CGFloat = 0
    private var pendingFilterName: String?
        private let availableFilters: [(name: String, filterName: String)] = [
        ("None",               ""),
        ("Chrome",             "CIPhotoEffectChrome"),
        ("Fade",               "CIPhotoEffectFade"),
        ("Instant",            "CIPhotoEffectInstant"),
        ("Mono",               "CIPhotoEffectMono"),
        ("Noir",               "CIPhotoEffectNoir"),
        ("Process",            "CIPhotoEffectProcess"),
        ("Tonal",              "CIPhotoEffectTonal"),
        ("Transfer",           "CIPhotoEffectTransfer"),
        ("Sepia",              "CISepiaTone"),
        ("Vignette",           "CIVignette"),
        ("Bloom",              "CIBloom"),
        ("Gloom",              "CIGloom"),
        ("Sharpen",            "CISharpenLuminance"),
        ("Unsharp Mask",       "CIUnsharpMask"),
        ("Invert",             "CIColorInvert"),
        ("Grayscale",          "CIColorMonochrome"),
        ("Posterize",          "CIColorPosterize"),
        ("Vibrance",           "CIVibrance"),
        ("Temperature Warm",   "CITemperatureAndTint"),
        ("Crystallize",        "CICrystallize"),
        ("Pixellate",          "CIPixellate"),
        ("Pointillize",        "CIPointillize"),
        ("Edges",              "CIEdges"),
        ("Comic",              "CIComicEffect"),
        ("X-Ray",              "CIXRay")
    ]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ThreadManager.shared.main { [self] in
            initUI()
            initCollection()
        }
        manageClickableActions()
        callNotificationFallbacks()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ThreadManager.shared.main { [self] in
            txt_docName.setDottedUnderline(color: .lightGray, width: 2.5)
            if let layout = collectionview_passedImages.collectionViewLayout as? UICollectionViewFlowLayout {
                layout.itemSize = collectionview_passedImages.bounds.size
            }
        }
    }
    
    @IBAction func onTapped_save(_ sender: Any) {
        applyPendingFilter()                    // Commit selected CIFilter to the image
        mergeOverlaysForCurrentImage()          // Merge overlays on top
        hideBaseBottomViews(toView: view_editBase)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            showBaseBottomViews(toView: view_bottomBase)
        }
    }
    
    @IBAction func onTapped_back(_ sender: Any) {
        NavigationManager.shared.popViewController(from: self)
    }
    
    @IBAction func onTapped_closeEditView(_ sender: Any) {
        hideBaseBottomViews(toView: view_editBase)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            showBaseBottomViews(toView: view_bottomBase)
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.PDF_URL_PASSING, object: nil)
    }
    
}

extension EditDocumentVC {
    
    func initUI() {
        view_topNav.addBottomDropShadow()
        view_bottomBase.layer.cornerRadius = 15
        view_bottomBase.clipsToBounds = true
        view_bottomBase.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        if arrFinalEditableImages.isEmpty, let image = capturedCameraImage {
            arrFinalEditableImages = [image]
        }
        
        currentCount = 0
        updateUI(total: arrFinalEditableImages.count)
        
        txt_docName.delegate = self
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy_HH:mm:ss"
        let dateString = formatter.string(from: Date())
        txt_docName.text = "\(dateString)"
        
        bottomBaseOriginalConstant = constraint_bottomView.constant
        editBaseOriginalConstant = constraint_editView.constant
        hideBaseBottomViews(toView: view_editBase)
    }
    
    func initCollection() {
        collectionview_passedImages.register(UINib(nibName: "cellEditDoc", bundle: .main), forCellWithReuseIdentifier: "cellEditDoc")
        collectionview_effectFeatures.register(UINib(nibName: "cellEffectsFeatures", bundle: .main), forCellWithReuseIdentifier: "cellEffectsFeatures")
        collectionview_passedImages.isPagingEnabled = true
        collectionview_passedImages.showsHorizontalScrollIndicator = false
        if let layout = collectionview_passedImages.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            layout.itemSize = collectionview_passedImages.bounds.size
        }
        collectionview_passedImages.delegate = self
        collectionview_passedImages.dataSource = self
        collectionview_passedImages.reloadData()
        collectionview_effectFeatures.delegate = self
        collectionview_effectFeatures.dataSource = self
        collectionview_effectFeatures.reloadData()
    }
}

extension EditDocumentVC {
    
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
    
    @objc func featureTapped(_ sender: UITapGestureRecognizer) {
        guard let index = sender.view?.tag else { return }
        
        switch index {
        case 0:
            hideBaseBottomViews(toView: view_bottomBase)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                showBaseBottomViews(toView: view_editBase)
            }
        case 1: manageRotation(isLeft: true)
        case 2: manageRotation(isLeft: false)
        case 3: showDeleteAlert()
        case 4: NavigationManager.shared.navigateToExportVC(from: self, imgs: arrFinalEditableImages, name: txt_docName.text!)
        default: break
        }
    }
}

extension EditDocumentVC {
    
    private func showDeleteAlert() {
        let alertController = UIAlertController(
            title: "Delete",
            message: "Are you sure you want to delete this?",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(cancelAction)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteCurrentImage()
        }
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true)
    }
    
    private func deleteCurrentImage() {
        guard !arrFinalEditableImages.isEmpty else { return }
        
        let total = arrFinalEditableImages.count
        let indexToDelete = currentCount
        
        if total == 1 {
            arrFinalEditableImages.removeAll()
            collectionview_passedImages.reloadData()
            currentCount = 0
            updateUI(total: 0)
            return
        }
        
        arrFinalEditableImages.remove(at: indexToDelete)
        
        if currentCount >= arrFinalEditableImages.count {
            currentCount = arrFinalEditableImages.count - 1
        }
        
        collectionview_passedImages.reloadData()
        updateUI(total: arrFinalEditableImages.count)
        
        collectionview_passedImages.scrollToItem(at: IndexPath(item: currentCount, section: 0), at: .centeredHorizontally, animated: true)
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        showRenameAlert()
        return false
    }
    
    private func showRenameAlert() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy_HH:mm:ss"
        let defaultFileName = "\(formatter.string(from: Date()))"
        
        let alert = UIAlertController(title: "Rename File", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Enter file name"
            textField.text = self.txt_docName.text?.isEmpty == false ? self.txt_docName.text : defaultFileName
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let newName = alert.textFields?.first?.text, !newName.isEmpty {
                self.txt_docName.text = newName
            }
        })
        self.present(alert, animated: true)
    }
    
    func navigateToSignatureManageVC(type: String, from: UIViewController) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SignatureManageVC") as! SignatureManageVC
        vc.sigType = type
        vc.delegate = self
        from.navigationController?.pushViewController(vc, animated: true)
    }
}

extension EditDocumentVC: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == self.collectionview_passedImages {
            return arrFinalEditableImages.count
        } else {
            return arrEffectsFeaturesData.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == self.collectionview_passedImages {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellEditDoc", for: indexPath) as! cellEditDoc
            
            cell.img_editableFullImage.image = arrFinalEditableImages[indexPath.item]
            cell.img_editableFullImage.contentMode = .scaleAspectFit
            cell.img_editableFullImage.isUserInteractionEnabled = true
            cell.contentView.isUserInteractionEnabled = true
            
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellEffectsFeatures", for: indexPath) as! cellEffectsFeatures
            let model = arrEffectsFeaturesData[indexPath.item]
            cell.img_icon.image = model.icon
            cell.lbl_title.text = model.title
            return cell
            
        }
    }
    
    
    @objc private func handleBaseImagePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let view = gesture.view else { return }
        
        switch gesture.state {
        case .changed, .ended:
            let currentScale = view.frame.size.width / view.bounds.size.width
            var newScale = currentScale * gesture.scale
            
            // Limit zoom scale
            newScale = max(1.0, min(newScale, 4.0))
            
            let transform = CGAffineTransform(scaleX: newScale, y: newScale)
            view.transform = transform
            
            gesture.scale = 1
        default:
            break
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.frame.width
        currentCount = Int(scrollView.contentOffset.x / pageWidth)
        updateUI(total: arrFinalEditableImages.count)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.frame.width
        let fractionalPage = scrollView.contentOffset.x / pageWidth
        currentCount = Int(round(fractionalPage))
        updateUI(total: arrFinalEditableImages.count)
    }
}

extension EditDocumentVC: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == collectionview_passedImages {
            return collectionview_passedImages.bounds.size
        } else {
            return CGSize(width: 50, height: 70)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == collectionview_passedImages {
            return 0
        } else {
            return 20
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == collectionview_effectFeatures {
            switch indexPath.row {
            case 0:
                AlertHelper.shared.show(
                    on: self,
                    title: "Add Signature",
                    message: nil,
                    style: .actionSheet,
                    actions: [
                        ("Text", .default, { self.navigateToSignatureManageVC(type: "Type Signature", from: self) }),
                        ("Draw", .default, { self.navigateToSignatureManageVC(type: "Draw Signature", from: self) }),
                        ("Cancel", .cancel, nil)
                    ]
                )
            case 1:
                openCropScreen()
            case 2:
                showFilterActionSheet()
            case 3:
                addDateOverlay()
            default:
                break
            }
        }
    }
}

extension EditDocumentVC {
    
    func manageRotation(isLeft: Bool) {
        ThreadManager.shared.main {[self] in
            guard !arrFinalEditableImages.isEmpty else { return }
            
            let currentImageIndex = currentCount
            let currentImage = arrFinalEditableImages[currentImageIndex]
            let angle: CGFloat = isLeft ? -.pi/2 : .pi/2
            
            guard let cell = collectionview_passedImages.cellForItem(at: IndexPath(item: currentImageIndex, section: 0)) as? cellEditDoc else { return }
            
            UIView.animate(withDuration: 0.3, animations: {
                cell.img_editableFullImage.transform = cell.img_editableFullImage.transform.rotated(by: angle)
            }, completion: { _ in
                let rotatedImage = currentImage.rotate(radians: angle)
                self.arrFinalEditableImages[currentImageIndex] = rotatedImage
                
                cell.img_editableFullImage.transform = .identity
                cell.img_editableFullImage.image = rotatedImage
            })
        }
    }
    
    func hideBaseBottomViews(toView: UIView) {
        UIView.animate(withDuration: 0.3, animations: {
            toView.transform = CGAffineTransform(translationX: 0, y: toView.frame.height)
        }) { _ in
            toView.isHidden = true
            toView.transform = .identity
        }
    }
    
    func showBaseBottomViews(toView: UIView) {
        toView.isHidden = false
        toView.transform = CGAffineTransform(translationX: 0, y: toView.frame.height)
        
        UIView.animate(withDuration: 0.3) {
            toView.transform = .identity
        }
    }
}

// MARK: - CIFilter Integration

extension EditDocumentVC {
    
    func showFilterActionSheet() {
        guard !arrFinalEditableImages.isEmpty else { return }
        
        let alert = UIAlertController(
            title: "Choose Effect",
            message: "Select a filter to preview. Tap Save to apply.",
            preferredStyle: .actionSheet
        )
        
        for filter in availableFilters {
            let action = UIAlertAction(title: filter.name, style: .default) { [weak self] _ in
                guard let self = self else { return }
                if filter.filterName.isEmpty {
                    self.pendingFilterName = nil
                    self.revertCellToOriginal()
                } else {
                    self.pendingFilterName = filter.filterName
                    self.previewFilter(named: filter.filterName)
                }
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.pendingFilterName = nil
            self?.revertCellToOriginal()
        })
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func previewFilter(named filterName: String) {
        guard !arrFinalEditableImages.isEmpty,
              let cell = collectionview_passedImages.cellForItem(
                at: IndexPath(item: currentCount, section: 0)
              ) as? cellEditDoc else { return }
        
        let original = arrFinalEditableImages[currentCount]
        if let filtered = applyFilter(named: filterName, to: original) {
            cell.img_editableFullImage.image = filtered
        }
    }
    
    private func revertCellToOriginal() {
        guard !arrFinalEditableImages.isEmpty,
              let cell = collectionview_passedImages.cellForItem(
                at: IndexPath(item: currentCount, section: 0)
              ) as? cellEditDoc else { return }
        cell.img_editableFullImage.image = arrFinalEditableImages[currentCount]
    }
    
    func applyPendingFilter() {
        guard let filterName = pendingFilterName,
              !filterName.isEmpty,
              !arrFinalEditableImages.isEmpty else {
            pendingFilterName = nil
            return
        }
        
        let original = arrFinalEditableImages[currentCount]
        if let filtered = applyFilter(named: filterName, to: original) {
            arrFinalEditableImages[currentCount] = filtered
            
            if let cell = collectionview_passedImages.cellForItem(
                at: IndexPath(item: currentCount, section: 0)
            ) as? cellEditDoc {
                cell.img_editableFullImage.image = filtered
            }
        }
        pendingFilterName = nil
    }
    
    private func applyFilter(named filterName: String, to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        guard let filter = CIFilter(name: filterName) else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        switch filterName {
        case "CISepiaTone":
            filter.setValue(0.85, forKey: kCIInputIntensityKey)
        case "CIVignette":
            filter.setValue(1.2, forKey: kCIInputIntensityKey)
            filter.setValue(1.5, forKey: kCIInputRadiusKey)
        case "CIBloom", "CIGloom":
            filter.setValue(0.8, forKey: kCIInputIntensityKey)
            filter.setValue(10.0, forKey: kCIInputRadiusKey)
        case "CISharpenLuminance":
            filter.setValue(0.8, forKey: kCIInputSharpnessKey)
        case "CIUnsharpMask":
            filter.setValue(2.5, forKey: kCIInputRadiusKey)
            filter.setValue(0.5, forKey: kCIInputIntensityKey)
        case "CIColorMonochrome":
            filter.setValue(CIColor(color: .gray), forKey: kCIInputColorKey)
            filter.setValue(1.0, forKey: kCIInputIntensityKey)
        case "CIColorPosterize":
            filter.setValue(6.0, forKey: "inputLevels")
        case "CIVibrance":
            filter.setValue(0.8, forKey: "inputAmount")
        case "CITemperatureAndTint":
            filter.setValue(CIVector(x: 7000, y: 0), forKey: "inputNeutral")
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
        case "CICrystallize":
            filter.setValue(20.0, forKey: kCIInputRadiusKey)
        case "CIPixellate":
            filter.setValue(12.0, forKey: kCIInputScaleKey)
        case "CIPointillize":
            filter.setValue(12.0, forKey: kCIInputRadiusKey)
        case "CIEdges":
            filter.setValue(5.0, forKey: kCIInputIntensityKey)
        default:
            break
        }
        
        guard let output = filter.outputImage,
              let cgOut = context.createCGImage(output, from: ciImage.extent) else { return nil }
        
        return UIImage(cgImage: cgOut, scale: image.scale, orientation: image.imageOrientation)
    }
}

extension EditDocumentVC: SecondaryViewControllerDelegate {
    
    func didSelectImage(_ image: UIImage) {
        Logger.print("Received dragable image >>>>>> \(image)", level: .success)
        
        guard !arrFinalEditableImages.isEmpty else { return }
        
        let currentIndexPath = IndexPath(item: currentCount, section: 0)
        
        collectionview_passedImages.scrollToItem(at: currentIndexPath, at: .centeredHorizontally, animated: false)
        collectionview_passedImages.layoutIfNeeded()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let cell = self.collectionview_passedImages.cellForItem(at: currentIndexPath) as? cellEditDoc else { return }
            
            let baseView = cell.img_editableFullImage
            let baseFrame = baseView?.bounds
            
            guard baseFrame!.width > 0, baseFrame!.height > 0 else { return }
            
            let width = max(baseFrame!.width * 0.15, 40)
            let aspectRatio = image.size.height / max(image.size.width, 1)
            let height = max(width * aspectRatio, 40)
            
            let container = EditableImageView(frame: CGRect(
                x: baseFrame!.midX - width / 2,
                y: baseFrame!.midY - height / 2,
                width: width + 24, // Add padding for controls
                height: height + 24
            ))
            
            container.delegate = self
            container.imageView.image = image
            
            if baseView?.gestureRecognizers?.filter({ $0 is UITapGestureRecognizer }).isEmpty ?? true {
                let baseTap = UITapGestureRecognizer(target: self, action: #selector(self.deselectAllOverlays))
                baseView?.addGestureRecognizer(baseTap)
            }
            
            baseView!.addSubview(container)
            self.overlayImageViews.append(container)
            self.selectOverlay(container)
        }
    }
    
    private func addDateOverlay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let dateString = formatter.string(from: Date())
        
        guard let dateImage = imageFromText(dateString, font: UIFont.boldSystemFont(ofSize: 40), color: .black) else { return }
        
        let currentIndexPath = IndexPath(item: currentCount, section: 0)
        collectionview_passedImages.scrollToItem(at: currentIndexPath, at: .centeredHorizontally, animated: false)
        collectionview_passedImages.layoutIfNeeded()
        
        guard let cell = collectionview_passedImages.cellForItem(at: currentIndexPath) as? cellEditDoc,
              let baseView = cell.img_editableFullImage else { return }
        
        let baseFrame = baseView.bounds
        let width = max(baseFrame.width * 0.4, 150)
        let aspectRatio = dateImage.size.height / max(dateImage.size.width, 1)
        let height = width * aspectRatio
        
        let container = EditableImageView(frame: CGRect(
            x: baseFrame.midX - (width + 24) / 2,
            y: baseFrame.midY - (height + 24) / 2,
            width: width + 24,
            height: height + 24
        ))
        
        container.editMode = .date
        container.delegate = self
        container.imageView.image = dateImage
        
        container.onDateChangeTapped = { [weak self, weak container] in
            guard let self = self, let container = container else { return }
            self.showDatePicker(for: container)
        }
        
        if baseView.gestureRecognizers?.filter({ $0 is UITapGestureRecognizer }).isEmpty ?? true {
            let baseTap = UITapGestureRecognizer(target: self, action: #selector(self.deselectAllOverlays))
            baseView.addGestureRecognizer(baseTap)
        }
        
        baseView.addSubview(container)
        self.overlayImageViews.append(container)
        self.selectOverlay(container)
    }
    
    private func showDatePicker(for overlay: EditableImageView) {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        
        let alert = UIAlertController(title: "Select Date", message: "\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
        alert.view.addSubview(datePicker)
        
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            datePicker.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            datePicker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 45),
            datePicker.widthAnchor.constraint(equalTo: alert.view.widthAnchor)
        ])
        
        alert.addAction(UIAlertAction(title: "Update", style: .default) { _ in
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            let dateString = formatter.string(from: datePicker.date)
            
            if let newImage = self.imageFromText(dateString, font: UIFont.boldSystemFont(ofSize: 40), color: .black) {
                overlay.imageView.image = newImage
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func imageFromText(_ text: String, font: UIFont, color: UIColor) -> UIImage? {
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let size = text.size(withAttributes: attr)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        text.draw(at: .zero, withAttributes: attr)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
        
    
    @objc private func deselectAllOverlays() {
        selectedOverlay?.isSelected = false
        selectedOverlay = nil
    }
    
    private func selectOverlay(_ overlay: EditableImageView) {
        selectedOverlay?.isSelected = false
        selectedOverlay = overlay
        selectedOverlay?.isSelected = true
    }
    
    // MARK: - EditableImageViewDelegate
    
    func didSelectView(_ view: EditableImageView) {
        selectOverlay(view)
    }
    
    func didDeleteView(_ view: EditableImageView) {
        if let index = overlayImageViews.firstIndex(of: view) {
            overlayImageViews.remove(at: index)
        }
        if selectedOverlay == view {
            selectedOverlay = nil
        }
    }
    
    // MARK: - Merge
    
    private func mergeOverlaysForCurrentImage() {
        guard !arrFinalEditableImages.isEmpty else { return }
        let currentIndex = currentCount
        guard let cell = collectionview_passedImages.cellForItem(
            at: IndexPath(item: currentIndex, section: 0)
        ) as? cellEditDoc else { return }
        
        let imageView = cell.img_editableFullImage
        
        deselectAllOverlays()
        overlayImageViews.forEach { $0.hideControls() }
        
        let renderer = UIGraphicsImageRenderer(size: (imageView?.bounds.size)!)
        let mergedImage = renderer.image { ctx in
            imageView?.layer.render(in: ctx.cgContext)
        }
        
        arrFinalEditableImages[currentIndex] = mergedImage
        imageView?.image = mergedImage
        imageView?.transform = .identity
        
        overlayImageViews.forEach { $0.removeFromSuperview() }
        overlayImageViews.removeAll()
    }
}

extension EditDocumentVC {
    func callNotificationFallbacks() {
        NotificationCenter.default.addObserver(self, selector: #selector(methodOfReceivedNotification(_:)), name: Notification.Name.PDF_URL_PASSING, object: nil)
    }
    
    @objc func methodOfReceivedNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let fileURL = userInfo["pdfURL"] as? URL else {
            Logger.print("Failed to receive PDF URL", level: .error)
            return
        }
        
        Logger.print("Received PDF URL: >>>>>> \(fileURL)", level: .success)
        
        NavigationManager.shared.navigateToPDFViewVC(from: self, url: "\(fileURL)")
    }
}

extension EditDocumentVC: CropViewControllerDelegate {
    
    func openCropScreen() {
        guard !arrFinalEditableImages.isEmpty else { return }
        let image = arrFinalEditableImages[currentCount]
        let cropVC = CropViewController(image: image)
        cropVC.delegate = self
        present(cropVC, animated: true)
    }
    
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        dismiss(animated: true)
        arrFinalEditableImages[currentCount] = image
        
        if let cell = collectionview_passedImages.cellForItem(at: IndexPath(item: currentCount, section: 0)) as? cellEditDoc {
            cell.img_editableFullImage.image = image
        }
    }
}

extension EditDocumentVC {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

