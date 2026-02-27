//
//  CameraHandlerVC.swift
//  PDF Tools
//
//  Created by mac on 17/02/26.
//

import UIKit
import AVFoundation

class CameraHandlerVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCapturePhotoCaptureDelegate  {
    
    @IBOutlet weak var btn_flash: UIButton!
    @IBOutlet weak var collectionViewFeatures: UICollectionView!
    @IBOutlet weak var view_dot: UIView!
    @IBOutlet weak var btn_photoGallary: UIButton!
    @IBOutlet weak var btn_grid: UIButton!
    @IBOutlet weak var btn_cameraCapture: UIButton!
    @IBOutlet weak var view_passport: UIView!
    @IBOutlet weak var view_idCard: UIView!
    @IBOutlet weak var view_qr: UIView!
    @IBOutlet weak var view_bgSelectedimageCount: UIView!
    @IBOutlet weak var view_camera: UIView!
    @IBOutlet weak var lbl_selectedImageCount: UILabel!
    
    
    var isFlashOn = false
    var gridView: GridView!
    var isGridShow: Bool = false
    var arrCameraViewFeatures: [CameraViewFeatures] = [CameraViewFeatures]()
    let arrCameraFeaturesTitle = ["Single", "Multi", "Passport", "ID Card", "QR Code"]
    var imagePicker = UIImagePickerController()
    var selectedImages = [UIImage]()
    var imgCount = 0
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var stillImageOutput: AVCapturePhotoOutput?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        setupUI()
        ThreadManager.shared.background {
            self.captureSession?.startRunning()
        }
    }
    
    @IBAction func onTapped_flash(_ sender: UIButton) { toggalFlashLight(sender: sender) }
    @IBAction func onTapped_close(_ sender: Any) { NavigationManager.shared.popViewController(from: self) }
    @IBAction func onTapped_cameraCapture(_ sender: Any) { stillImageOutput?.capturePhoto(with: AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]), delegate: self) }
    
    @IBAction func onTapped_gridView(_ sender: Any) {
        isGridShow.toggle()
        if isGridShow { setupGridView() } else { gridView.removeFromSuperview() }
    }
    
    @IBAction func onTapped_photoPicker(_ sender: Any) { configPhotosOpening() }
    @IBAction func onTapped_selectedImages(_ sender: Any) { isFromCameraCaptured = false; navigateToCropDocVC(img: nil, imgs: selectedImages, from: self) }
    
    deinit {
        self.captureSession?.stopRunning()
    }
}

extension CameraHandlerVC: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { arrCameraFeaturesTitle.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellCameraFeatures", for: indexPath) as! cellCameraFeatures
        cell.lbl_featuresTitle.text = arrCameraFeaturesTitle[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        let mode = indexPath.row
        [view_passport, view_idCard, view_qr].enumerated().forEach { $0.element.isHidden = $0.offset != mode - 2 }
        [btn_photoGallary, btn_grid, btn_cameraCapture].forEach { $0.isHidden = mode == 4 }
        if mode >= 2 { btn_grid.isHidden = true; if isGridShow { gridView?.removeFromSuperview() } }
        collectionView.reloadItems(at: [indexPath])
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize { CGSize(width: 200, height: 50) }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let inset = (collectionView.frame.width - 200) / 2
        return UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
    }
}

extension CameraHandlerVC {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let img = info[.originalImage] as? UIImage {
            selectedImages.append(img); imgCount += 1
            view_bgSelectedimageCount.isHidden = false
            lbl_selectedImageCount.isHidden = false
            lbl_selectedImageCount.text = "\(imgCount)"
        }
        dismiss(animated: true)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation(), let img = UIImage(data: data) {
            isFromCameraCaptured = true; navigateToCropDocVC(img: img, imgs: nil, from: self)
        }
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { dismiss(animated: true) }
}

extension CameraHandlerVC {
    func setupUI() {
        collectionViewFeatures.register(UINib(nibName: "cellCameraFeatures", bundle: .main), forCellWithReuseIdentifier: "cellCameraFeatures")
        collectionViewFeatures.delegate = self; collectionViewFeatures.dataSource = self
        [view_dot, view_bgSelectedimageCount, lbl_selectedImageCount].forEach { $0?.layer.cornerRadius = ($0?.frame.height ?? 0) / 2 }
        [view_qr, view_passport, view_idCard].forEach { 
            $0.layer.borderWidth = 2; $0.layer.borderColor = UIColor.white.cgColor
            $0.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5); $0.isHidden = true 
        }
        updateSelectedImageCount()
    }
    
    func navigateToCropDocVC(img: UIImage?, imgs: [UIImage]?, from vc: UIViewController) {
        if let cropVC = storyboard?.instantiateViewController(withIdentifier: "CropDocumentVC") as? CropDocumentVC {
            cropVC.capturedCameraImage = img; cropVC.selectedPassedImages = imgs ?? []
            cropVC.onImagesUpdated = { [weak self] imgs in
                self?.selectedImages = imgs; self?.imgCount = imgs.count; self?.updateSelectedImageCount()
            }
            vc.navigationController?.pushViewController(cropVC, animated: true)
        }
    }
    
    func updateSelectedImageCount() {
        let hide = selectedImages.isEmpty
        view_bgSelectedimageCount.isHidden = hide; lbl_selectedImageCount.isHidden = hide
        lbl_selectedImageCount.text = "\(imgCount)"
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession(); captureSession?.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { return }
        stillImageOutput = AVCapturePhotoOutput()
        if let session = captureSession, let output = stillImageOutput, session.canAddInput(input) && session.canAddOutput(output) {
            session.addInput(input); session.addOutput(output)
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = .resizeAspectFill; previewLayer?.connection?.videoRotationAngle = 90
            if let preview = previewLayer { view_camera.layer.addSublayer(preview); preview.frame = view_camera.bounds }
        }
    }
    
    func setupGridView() {
        gridView = GridView(); gridView.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(gridView)
        NSLayoutConstraint.activate([gridView.topAnchor.constraint(equalTo: view.topAnchor), gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor), gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor), gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
    }
    
    func configPhotosOpening() {
        PermissionManager.shared.requestCameraPermission { [weak self] granted in
            guard granted else { PermissionManager.shared.openSettings(); return }
            let picker = UIImagePickerController(); picker.delegate = self; picker.sourceType = .photoLibrary
            self?.present(picker, animated: true)
        }
    }
    
    func toggalFlashLight(sender: UIButton) {
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch, (try? device.lockForConfiguration()) != nil {
            isFlashOn.toggle(); device.torchMode = isFlashOn ? .on : .off
            btn_flash.setImage(UIImage(named: isFlashOn ? "ic_flashOFF" : "ic_flashON"), for: .normal)
            device.unlockForConfiguration()
        }
    }
}

extension CameraHandlerVC: CropDocumentVCDelegate {
    func cropDocumentVC(_ controller: CropDocumentVC, didUpdateImages images: [UIImage]) {
        selectedImages = images; imgCount = images.count; updateSelectedImageCount()
    }
}
