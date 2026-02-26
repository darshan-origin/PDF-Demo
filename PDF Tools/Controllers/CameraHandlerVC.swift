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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        initUI()
        ThreadManager.shared.background {
            self.captureSession?.startRunning()
        }
    }
    
    @IBAction func onTapped_flash(_ sender: UIButton) {
        toggalFlashLight(sender: sender)
    }
    
    @IBAction func onTapped_close(_ sender: Any) {
        NavigationManager.shared.popViewController(from: self)
    }
    
    @IBAction func onTapped_cameraCapture(_ sender: Any) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    @IBAction func onTapped_gridView(_ sender: Any) {
        isGridShow.toggle()
        ThreadManager.shared.main { [self] in
            if isGridShow {
                setupGridView()
            }
            else {
                gridView.removeFromSuperview()
            }
        }
    }
    
    @IBAction func onTapped_photoPicker(_ sender: Any) {
        configPhotosOpening()
    }
    
    @IBAction func onTapped_selectedImages(_ sender: Any) {
        isFromCameraCaptured = false
        self.navigateToCropDocVC(img: nil, imgs: selectedImages, from: self)
    }
    
    
    
    deinit {
        self.captureSession?.stopRunning()
    }
}

extension CameraHandlerVC: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return arrCameraFeaturesTitle.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = self.collectionViewFeatures.dequeueReusableCell(withReuseIdentifier: "cellCameraFeatures", for: indexPath) as! cellCameraFeatures
        let model = arrCameraFeaturesTitle[indexPath.row]
        cell.lbl_featuresTitle.text = model
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let model = arrCameraFeaturesTitle[indexPath.row]
        Logger.print(model, level: .debug)
        collectionView.scrollToItem(at: indexPath,at: .centeredHorizontally, animated: true)
        if let cell = collectionView.cellForItem(at: indexPath) as? cellCameraFeatures {
            cell.isSelected = true
        }
        
        if indexPath.row == 2 {
            self.view_passport.isHidden = false
            self.view_qr.isHidden = true
            self.view_idCard.isHidden = true
            self.btn_grid.isHidden = true
            if isGridShow {
                self.gridView.removeFromSuperview()
            }
        } else if indexPath.row == 3 {
            self.view_idCard.isHidden = false
            self.view_qr.isHidden = true
            self.view_passport.isHidden = true
            self.btn_grid.isHidden = true
            if isGridShow {
                self.gridView.removeFromSuperview()
            }
        } else if indexPath.row == 4 {
            self.btn_photoGallary.isHidden = true
            self.btn_grid.isHidden = true
            self.btn_cameraCapture.isHidden = true
            self.view_qr.isHidden = false
            self.view_passport.isHidden = true
            self.view_idCard.isHidden = true
            self.btn_grid.isHidden = true
            if isGridShow {
                self.gridView.removeFromSuperview()
            }
        }
        else {
            self.view_qr.isHidden = true
            self.view_idCard.isHidden = true
            self.view_passport.isHidden = true
            self.btn_photoGallary.isHidden = false
            self.btn_grid.isHidden = false
            self.btn_cameraCapture.isHidden = false
        }
        
        collectionView.reloadItems(at: [indexPath])
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 200, height: 50)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let cellWidth: CGFloat = 200
        let inset = (collectionView.frame.width / 2) - (cellWidth / 2)
        return UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
    }
}

extension CameraHandlerVC {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let originalImage = info[.originalImage]
        Logger.print("Selected image metadata >>>>> \(originalImage.debugDescription)", level: .info)
        selectedImages.append(originalImage as? UIImage ?? UIImage())
        Logger.print("Stored Last selected image >>>>> \(selectedImages)", level: .success)
        imgCount += 1
        if !selectedImages.isEmpty {
            self.view_bgSelectedimageCount.isHidden = false
            self.lbl_selectedImageCount.isHidden = false
            self.lbl_selectedImageCount.text = "\(imgCount)"
        }
        dismiss(animated: true, completion: nil)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let e = error {
            Logger.print(e, level: .error)
        } else if let photoData = photo.fileDataRepresentation(), let photoImage = UIImage(data: photoData) {
            Logger.print("Camera image captured and data >>>>>> \(photoData)", level: .success)
            isFromCameraCaptured = true
            self.navigateToCropDocVC(img: photoImage, imgs: nil, from: self)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
}

extension CameraHandlerVC {
    
    func initUI() {
        ThreadManager.shared.main { [self] in
            collectionViewFeatures.register(UINib(nibName: "cellCameraFeatures", bundle: .main), forCellWithReuseIdentifier: "cellCameraFeatures")
            collectionViewFeatures.delegate = self
            collectionViewFeatures.dataSource = self
            collectionViewFeatures.isPagingEnabled = false
            collectionViewFeatures.isScrollEnabled = false
            collectionViewFeatures.reloadData()
            
            view_dot.layer.cornerRadius = view_dot.frame.height / 2
            captureViewsConfig(view: view_qr)
            captureViewsConfig(view: view_passport)
            captureViewsConfig(view: view_idCard)
            view_bgSelectedimageCount.layer.cornerRadius = view_bgSelectedimageCount.frame.height / 2
            view_bgSelectedimageCount.layer.borderWidth = 1
            view_bgSelectedimageCount.layer.borderColor = UIColor.lightGray.cgColor
            lbl_selectedImageCount.layer.cornerRadius = lbl_selectedImageCount.frame.height / 2
            lbl_selectedImageCount.clipsToBounds = true
            
            if selectedImages.isEmpty {
                lbl_selectedImageCount.isHidden = true
                view_bgSelectedimageCount.isHidden = true
            }
        }
    }
    
    func navigateToCropDocVC(img: UIImage?, imgs: [UIImage]?, from vc: UIViewController) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let cropVC = storyboard.instantiateViewController(withIdentifier: "CropDocumentVC") as? CropDocumentVC {
            
            if let singleImage = img {
                cropVC.capturedCameraImage = singleImage
            }
            if let imagesArray = imgs {
                cropVC.selectedPassedImages = imagesArray
            }
            
            // Pass the closure instead of delegate
            cropVC.onImagesUpdated = { [weak self] updatedImages in
                guard let self = self else { return }
                self.selectedImages = updatedImages
                self.imgCount = updatedImages.count
                self.lbl_selectedImageCount.text = "\(self.imgCount)"
                self.view_bgSelectedimageCount.isHidden = updatedImages.isEmpty
                self.lbl_selectedImageCount.isHidden = updatedImages.isEmpty
            }
            
            vc.navigationController?.pushViewController(cropVC, animated: true)
        }
    }
    
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video) else {
            Logger.print("Unable to access back camera!", level: .error)
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            stillImageOutput = AVCapturePhotoOutput()
            
            if captureSession?.canAddInput(input) == true && captureSession?.canAddOutput(stillImageOutput!) == true {
                captureSession?.addInput(input)
                captureSession?.addOutput(stillImageOutput!)
                setupLivePreview()
            }
        } catch let error {
            Logger.print("Error Unable to initialize back camera: \(error.localizedDescription)", level: .error)
        }
    }
    
    func setupLivePreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.connection?.videoRotationAngle = 90
        view_camera.layer.addSublayer(previewLayer!)
        
        ThreadManager.shared.backgroundUserInitiated { [weak self] in
            self?.captureSession?.startRunning()
            ThreadManager.shared.main {
                self?.previewLayer?.frame = self?.view_camera.bounds ?? CGRect.zero
            }
        }
    }
    
    
    func captureViewsConfig(view: UIView) {
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.cgColor
        view.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        view.isHidden = true
    }
    
    func setupGridView() {
        gridView = GridView()
        gridView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gridView)
        
        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: view.topAnchor),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func configPhotosOpening() {
        PermissionManager.shared.requestCameraPermission { [self] granted in
            if granted {
                Logger.print("Photos Permission Allowed", level: .success)
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .photoLibrary
                present(imagePicker, animated: true, completion: nil)
            } else {
                Logger.print("Photos Permission Denied", level: .error)
                PermissionManager.shared.openSettings()
            }
        }
    }
    
    func toggalFlashLight(sender: UIButton) {
        let device = AVCaptureDevice.default(for: AVMediaType.video)
        if let device = device, device.hasTorch {
            do {
                try device.lockForConfiguration()
                ThreadManager.shared.main() { [self] in
                    
                    if isFlashOn {
                        device.torchMode = .off
                        isFlashOn = false
                        Logger.print("Flash OFF", level: .success)
                        btn_flash.setImage(UIImage(named: "ic_flashON"), for: .normal)
                    } else {
                        device.torchMode = .on
                        isFlashOn = true
                        Logger.print("Flash ON", level: .success)
                        btn_flash.setImage(UIImage(named: "ic_flashOFF"), for: .normal)
                    }
                    device.unlockForConfiguration()
                }
            } catch {
                Logger.print("Could not hold torch configuration", level: .error)
            }
        }
    }
}

extension CameraHandlerVC: CropDocumentVCDelegate {
    func cropDocumentVC(_ controller: CropDocumentVC, didUpdateImages images: [UIImage]) {
        self.selectedImages = images
        self.imgCount = images.count
        self.lbl_selectedImageCount.text = "\(self.imgCount)"
        self.view_bgSelectedimageCount.isHidden = self.selectedImages.isEmpty
        self.lbl_selectedImageCount.isHidden = self.selectedImages.isEmpty
    }
}
