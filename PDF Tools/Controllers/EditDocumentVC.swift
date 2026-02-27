import UIKit
import CoreImage
import CropViewController

extension Date {
    func toString(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

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
    
    private var selectedOverlay: EditableImageView?
    private var currentCount: Int = 0 {
        didSet { updateUI() }
    }
    
    private func updateUI() {
        lbl_counter.text = "\(currentCount + 1)/\(arrFinalEditableImages.count)"
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
        applyPendingFilter()
        mergeOverlaysForCurrentImage()
        toggleBottomViews(hide: view_editBase, show: view_bottomBase)
    }
    
    @IBAction func onTapped_back(_ sender: Any) {
        NavigationManager.shared.popViewController(from: self)
    }
    
    @IBAction func onTapped_closeEditView(_ sender: Any) {
        toggleBottomViews(hide: view_editBase, show: view_bottomBase)
    }
    
    private func toggleBottomViews(hide: UIView, show: UIView) {
        animateBottomView(hide, isVisible: false) {
            self.animateBottomView(show, isVisible: true)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension EditDocumentVC {
    
    func initUI() {
        view_topNav.addBottomDropShadow()
        view_bottomBase.roundCorners(corners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], radius: 15)
        
        if arrFinalEditableImages.isEmpty, let image = capturedCameraImage {
            arrFinalEditableImages = [image]
        }
        
        currentCount = 0
        txt_docName.delegate = self
        txt_docName.text = Date().toString(format: "dd-MM-yyyy_HH:mm:ss")
        
        bottomBaseOriginalConstant = constraint_bottomView.constant
        editBaseOriginalConstant = constraint_editView.constant
        animateBottomView(view_editBase, isVisible: false)
    }
    
    func initCollection() {
        collectionview_passedImages.register(UINib(nibName: "cellEditDoc", bundle: .main), forCellWithReuseIdentifier: "cellEditDoc")
        collectionview_effectFeatures.register(UINib(nibName: "cellEffectsFeatures", bundle: .main), forCellWithReuseIdentifier: "cellEffectsFeatures")
        
        [collectionview_passedImages, collectionview_effectFeatures].forEach {
            $0?.delegate = self
            $0?.dataSource = self
            $0?.reloadData()
        }
        
        collectionview_passedImages.isPagingEnabled = true
        collectionview_passedImages.showsHorizontalScrollIndicator = false
        
        if let layout = collectionview_passedImages.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 0
            layout.itemSize = collectionview_passedImages.bounds.size
        }
    }
}

extension EditDocumentVC {
    
    private func manageClickableActions() {
        for (i, (img, lbl)) in zip(img_features, lbl_featuresTitle).enumerated() {
            [img, lbl].forEach {
                $0.isUserInteractionEnabled = true
                $0.tag = i
                $0.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(featureTapped(_:))))
            }
        }
    }
    
    @objc func featureTapped(_ sender: UITapGestureRecognizer) {
        guard let index = sender.view?.tag else { return }
        
        switch index {
        case 0: toggleBottomViews(hide: view_bottomBase, show: view_editBase)
        case 1, 2: manageRotation(isLeft: index == 1)
        case 3: showDeleteAlert()
        case 4: NavigationManager.shared.navigateToExportVC(from: self, imgs: arrFinalEditableImages, name: txt_docName.text!)
        default: break
        }
    }
}

extension EditDocumentVC {
    
    private func showDeleteAlert() {
        AlertHelper.shared.show(on: self, title: "Delete", message: "Are you sure you want to delete this?", style: .alert, actions: [
            ("Cancel", .cancel, nil),
            ("Delete", .destructive, { self.deleteCurrentImage() })
        ])
    }
    
    private func deleteCurrentImage() {
        guard !arrFinalEditableImages.isEmpty else { return }
        
        arrFinalEditableImages.remove(at: currentCount)
        if currentCount >= arrFinalEditableImages.count && currentCount > 0 {
            currentCount = arrFinalEditableImages.count - 1
        }
        
        collectionview_passedImages.reloadData()
        if !arrFinalEditableImages.isEmpty {
            collectionview_passedImages.scrollToItem(at: IndexPath(item: currentCount, section: 0), at: .centeredHorizontally, animated: true)
        }
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        showRenameAlert()
        return false
    }
    
    private func showRenameAlert() {
        let defaultFileName = Date().toString(format: "dd-MM-yyyy_HH:mm:ss")
        let alert = UIAlertController(title: "Rename File", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = self.txt_docName.text?.isEmpty == false ? self.txt_docName.text : defaultFileName }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let newName = alert.textFields?.first?.text, !newName.isEmpty {
                self.txt_docName.text = newName
            }
        })
        present(alert, animated: true)
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
        collectionView == collectionview_passedImages ? arrFinalEditableImages.count : arrEffectsFeaturesData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == collectionview_passedImages {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellEditDoc", for: indexPath) as! cellEditDoc
            cell.img_editableFullImage.image = arrFinalEditableImages[indexPath.item]
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellEffectsFeatures", for: indexPath) as! cellEffectsFeatures
        let model = arrEffectsFeaturesData[indexPath.item]
        cell.img_icon.image = model.icon
        cell.lbl_title.text = model.title
        return cell
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
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.frame.width
        if pageWidth > 0 {
            currentCount = Int(round(scrollView.contentOffset.x / pageWidth))
        }
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
        guard !arrFinalEditableImages.isEmpty else { return }
        
        let angle: CGFloat = isLeft ? -.pi/2 : .pi/2
        guard let cell = collectionview_passedImages.cellForItem(at: IndexPath(item: currentCount, section: 0)) as? cellEditDoc else { return }
        
        UIView.animate(withDuration: 0.3, animations: {
            cell.img_editableFullImage.transform = cell.img_editableFullImage.transform.rotated(by: angle)
        }, completion: { _ in
            let rotatedImage = self.arrFinalEditableImages[self.currentCount].rotate(radians: angle)
            self.arrFinalEditableImages[self.currentCount] = rotatedImage
            cell.img_editableFullImage.transform = .identity
            cell.img_editableFullImage.image = rotatedImage
        })
    }
    
    private func animateBottomView(_ view: UIView, isVisible: Bool, completion: (() -> Void)? = nil) {
        view.isHidden = false
        let yOffset = isVisible ? 0 : view.frame.height
        let targetTransform = CGAffineTransform(translationX: 0, y: yOffset)
        
        UIView.animate(withDuration: 0.3, animations: {
            view.transform = targetTransform
        }) { _ in
            view.isHidden = !isVisible
            completion?()
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
        
        let params: [String: [String: Any]] = [
            "CISepiaTone": [kCIInputIntensityKey: 0.85],
            "CIColorControls": [kCIInputSaturationKey: 1.2, kCIInputBrightnessKey: 0.05, kCIInputContrastKey: 1.1],
            "CIExposureAdjust": [kCIInputEVKey: 0.5],
            "CIGammaAdjust": ["inputPower": 0.8],
            "CIHueAdjust": [kCIInputAngleKey: Float.pi / 4],
            "CIHighlightShadowAdjust": ["inputHighlightAmount": 1.0, "inputShadowAmount": 0.5],
            "CIWhitePointAdjust": [kCIInputColorKey: CIColor.white],
            "CIVibrance": ["inputAmount": 0.8],
            "CITemperatureAndTint": ["inputNeutral": CIVector(x: 7000, y: 0), "inputTargetNeutral": CIVector(x: 6500, y: 0)],
            "CIColorMonochrome": [kCIInputColorKey: CIColor(color: .gray), kCIInputIntensityKey: 1.0],
            "CIColorPosterize": ["inputLevels": 6.0],
            "CIBloom": [kCIInputIntensityKey: 0.8, kCIInputRadiusKey: 10.0],
            "CIGloom": [kCIInputIntensityKey: 0.8, kCIInputRadiusKey: 10.0],
            "CIGaussianBlur": [kCIInputRadiusKey: 8.0],
            "CIMotionBlur": [kCIInputRadiusKey: 10.0, kCIInputAngleKey: 0.0],
            "CIZoomBlur": [kCIInputAmountKey: 20.0],
            "CIBokehBlur": [kCIInputRadiusKey: 15.0],
            "CISharpenLuminance": [kCIInputSharpnessKey: 0.8],
            "CIUnsharpMask": [kCIInputRadiusKey: 2.5, kCIInputIntensityKey: 0.5],
            "CIEdges": [kCIInputIntensityKey: 5.0],
            "CIEdgeWork": [kCIInputRadiusKey: 3.0],
            "CILaplacian": [:],
            "CIComicEffect": [:],
            "CICrystallize": [kCIInputRadiusKey: 25.0],
            "CIPixellate": [kCIInputScaleKey: 12.0],
            "CIPointillize": [kCIInputRadiusKey: 12.0],
            "CICMYKHalftone": [kCIInputWidthKey: 6.0],
            "CIVignette": [kCIInputIntensityKey: 1.2, kCIInputRadiusKey: 1.5],
            "CIBumpDistortion": [kCIInputRadiusKey: 150.0, kCIInputScaleKey: 0.5],
            "CITwirlDistortion": [kCIInputRadiusKey: 300.0, kCIInputAngleKey: 1.0]
        ]
        
        params[filterName]?.forEach { filter.setValue($0.value, forKey: $0.key) }
        
        guard let output = filter.outputImage,
              let cgOut = context.createCGImage(output, from: ciImage.extent) else { return nil }
        
        return UIImage(cgImage: cgOut, scale: image.scale, orientation: image.imageOrientation)
    }
}

extension EditDocumentVC: SecondaryViewControllerDelegate {
    
    func didSelectImage(_ image: UIImage) {
        addOverlay(image: image, mode: .general)
    }
    
    private func addDateOverlay() {
        let dateString = Date().toString(format: "dd/MM/yyyy")
        guard let image = imageFromText(dateString, font: .boldSystemFont(ofSize: 40), color: .black) else { return }
        addOverlay(image: image, mode: .date)
    }
    
    private func addOverlay(image: UIImage, mode: EditableViewMode) {
        guard let cell = collectionview_passedImages.cellForItem(at: IndexPath(item: currentCount, section: 0)) as? cellEditDoc,
              let baseView = cell.img_editableFullImage else { return }
        
        let baseFrame = baseView.bounds
        let width = mode == .date ? max(baseFrame.width * 0.4, 150) : max(baseFrame.width * 0.15, 40)
        let height = width * (image.size.height / max(image.size.width, 1))
        
        let container = EditableImageView(frame: CGRect(
            x: baseFrame.midX - (width + 24) / 2,
            y: baseFrame.midY - (height + 24) / 2,
            width: width + 24,
            height: height + 24
        ))
        
        container.editMode = mode
        container.delegate = self
        container.imageView.image = image
        
        if mode == .date {
            container.onDateChangeTapped = { [weak self, weak container] in
                guard let container = container else { return }
                self?.showDatePicker(for: container)
            }
        }
        
        if (baseView.gestureRecognizers?.filter({ $0 is UITapGestureRecognizer }).isEmpty ?? true) {
            baseView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(deselectAllOverlays)))
        }
        
        baseView.addSubview(container)
        overlayImageViews.append(container)
        selectOverlay(container)
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
