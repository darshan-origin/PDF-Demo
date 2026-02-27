import UIKit
import PDFKit

class ExportDocumentPopupVC: UIViewController {
    
    @IBOutlet weak var view_base: UIView!
    @IBOutlet weak var txt_docName: UITextField!
    @IBOutlet weak var segmented_fileType: UISegmentedControl!
    @IBOutlet weak var slider_qualityRatio: UISlider!
    @IBOutlet weak var switch_watermark: UISwitch!
    @IBOutlet weak var lbl_currentSliderValue: UILabel!
    
    var fileName = ""
    var finalGenrableImages = [UIImage]()
    var docURL = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        segmented_fileType.selectedSegmentIndex = 0
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ThreadManager.shared.main { [self] in
            txt_docName.setDottedUnderline(color: .lightGray, width: 2.5)
        }
    }
    
    
    @IBAction func onTapped_close(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func onTapped_save(_ sender: Any) {
        let selectedIndex = segmented_fileType.selectedSegmentIndex
        Logger.print("Selected Segment Index: \(selectedIndex)", level: .success)
        savePDF()
    }
    
    @IBAction func onSliderValueChanged(_ sender: UISlider) {
        let roundedValue = round(sender.value)
        sender.value = roundedValue
        
        let intValue = Int(roundedValue)
        lbl_currentSliderValue.text = "Select Quality: \(intValue)"
        Logger.print("Select Quality: \(intValue)", level: .debug)
    }
}

extension ExportDocumentPopupVC {
    
    func initUI() {
        ThreadManager.shared.main { [self] in
            view_base.layer.cornerRadius = 12
            view_base.layer.masksToBounds = true
            
            txt_docName.text = fileName
            
            setupSegment()
            hideKeyboardOnTap()
            Logger.print("Recived images array count to convert in PDF >>>>>> \(finalGenrableImages.count)", level: .success)
        }
    }
    
    func setupSegment() {
        segmented_fileType.removeAllSegments()
        segmented_fileType.insertSegment(withTitle: "PDF", at: 0, animated: false)
        segmented_fileType.insertSegment(withTitle: "JPEG", at: 1, animated: false)
        segmented_fileType.selectedSegmentTintColor = UIColor.systemBlue
        
        segmented_fileType.setTitleTextAttributes(
            [.foregroundColor: UIColor.black],
            for: .normal
        )
        
        segmented_fileType.setTitleTextAttributes(
            [.foregroundColor: UIColor.white],
            for: .selected
        )
        
        segmented_fileType.selectedSegmentIndex = 0
        segmented_fileType.layoutIfNeeded()
    }
    
    func setupSlider() {
        slider_qualityRatio.minimumValue = 1
        slider_qualityRatio.maximumValue = 4
        slider_qualityRatio.isContinuous = false
        slider_qualityRatio.value = 4
        lbl_currentSliderValue.text = "Select Quality: 4"
    }
}

extension ExportDocumentPopupVC {
    
    func savePDF() {
        autoreleasepool {
            var watermarkImg: UIImage? = nil
            if let sw = switch_watermark, sw.isOn {
                watermarkImg = UIImage(named: "pdf_logo")
                if watermarkImg == nil {
                    Logger.print("Watermark image not found", level: .error)
                }
            }
            
            // Map slider (1-4) to quality (0.2-0.8), default to 0.8 if slider is nil
            let sliderVal = slider_qualityRatio?.value ?? 4.0
            let mappedQuality: CGFloat = CGFloat(0.2 * sliderVal)
            
            guard let pdfData = DOCHelper.shared.createPDF(from: finalGenrableImages, watermark: watermarkImg, quality: mappedQuality) else {
                Logger.print("Failed to generate PDF data", level: .error)
                return
            }
            do {
                try FileStorageManager.store(pdfData, at: "\(fileName).pdf", in: .documents)
                Logger.print("PDF saved successfully", level: .success)
                let fileURL = FileStorageManager.url(for: "\(fileName).pdf", in: .documents)
                
                Logger.print("FINAL STORED PDF URL: >>>>>> \(fileURL)", level: .success)
                let userInfo = ["pdfURL": fileURL]
                
                NotificationCenter.default.post(
                    name: Notification.Name.PDF_URL_PASSING,
                    object: nil,
                    userInfo: userInfo
                )
                
                self.dismiss(animated: true)
            }
            catch {
                Logger.print("Could not save PDF file >>>>>> \(error.localizedDescription)", level: .error)
            }
        }
    }
}
