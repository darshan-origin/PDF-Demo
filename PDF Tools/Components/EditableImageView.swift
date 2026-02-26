import UIKit

protocol EditableImageViewDelegate: AnyObject {
    func didSelectView(_ view: EditableImageView)
    func didDeleteView(_ view: EditableImageView)
}

class EditableImageView: UIView {
    
    // MARK: - Properties
    weak var delegate: EditableImageViewDelegate?
    var imageView: UIImageView!
    
    private var deleteButton: UIButton!
    private var rotateButton: UIButton!
    private var resizeButton: UIButton!
    private var flipButton: UIButton!
    
    private let controlSize: CGFloat = 24
    private var lastRotation: CGFloat = 0
    private var lastScale: CGFloat = 1.0
    
    var isSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.backgroundColor = .clear
        
        // Image View
        imageView = UIImageView(frame: self.bounds.insetBy(dx: controlSize/2, dy: controlSize/2))
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)
        
        // Border
        self.layer.borderWidth = 1.0
        self.layer.borderColor = UIColor.systemBlue.cgColor
        
        setupButtons()
        setupGestures()
        updateSelectionState()
    }
    
    private func setupButtons() {
        // Top Left: Flip (Yellow)
        flipButton = createControlButton(imageName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", color: .systemYellow)
        flipButton.addTarget(self, action: #selector(flipHorizontal), for: .touchUpInside)
        
        // Top Right: Delete (Red)
        deleteButton = createControlButton(imageName: "xmark.circle.fill", color: .systemRed)
        deleteButton.addTarget(self, action: #selector(deleteView), for: .touchUpInside)
        
        // Bottom Left: Rotate (Green)
        rotateButton = createControlButton(imageName: "rotate.right.fill", color: .systemGreen)
        let rotatePan = UIPanGestureRecognizer(target: self, action: #selector(handleRotatePan(_:)))
        rotateButton.addGestureRecognizer(rotatePan)
        
        // Bottom Right: Resize (Blue)
        resizeButton = createControlButton(imageName: "arrow.up.left.and.arrow.down.right.circle.fill", color: .systemBlue)
        let resizePan = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
        resizeButton.addGestureRecognizer(resizePan)
        
        [flipButton, deleteButton, rotateButton, resizeButton].forEach { addSubview($0!) }
    }
    
    private func createControlButton(imageName: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: controlSize, height: controlSize)
        let config = UIImage.SymbolConfiguration(pointSize: controlSize * 0.6, weight: .bold)
        let image = UIImage(systemName: imageName, withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = color
        button.layer.cornerRadius = controlSize / 2
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 2
        return button
    }
    
    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleMovePan(_:)))
        self.addGestureRecognizer(pan)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        self.addGestureRecognizer(tap)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        self.addGestureRecognizer(pinch)
        
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate(_:)))
        self.addGestureRecognizer(rotate)
        
        // Allow simultaneous gestures
        pan.delegate = self
        pinch.delegate = self
        rotate.delegate = self
    }
    
    private func updateSelectionState() {
        let controlsAlpha: CGFloat = isSelected ? 1.0 : 0.0
        flipButton.alpha = controlsAlpha
        deleteButton.alpha = controlsAlpha
        rotateButton.alpha = controlsAlpha
        resizeButton.alpha = controlsAlpha
        self.layer.borderWidth = isSelected ? 1.0 : 0.0
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = self.bounds.insetBy(dx: controlSize/2, dy: controlSize/2)
        
        flipButton.center = CGPoint(x: 0, y: 0)
        deleteButton.center = CGPoint(x: bounds.width, y: 0)
        rotateButton.center = CGPoint(x: 0, y: bounds.height)
        resizeButton.center = CGPoint(x: bounds.width, y: bounds.height)
    }
    
    // MARK: - Actions
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.didSelectView(self)
    }
    
    @objc private func handleMovePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = self.superview else { return }
        let translation = gesture.translation(in: superview)
        self.center = CGPoint(x: self.center.x + translation.x, y: self.center.y + translation.y)
        gesture.setTranslation(.zero, in: superview)
        
        if gesture.state == .began {
            delegate?.didSelectView(self)
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        self.transform = self.transform.scaledBy(x: gesture.scale, y: gesture.scale)
        gesture.scale = 1
        if gesture.state == .began {
            delegate?.didSelectView(self)
        }
    }
    
    @objc private func handleRotate(_ gesture: UIRotationGestureRecognizer) {
        self.transform = self.transform.rotated(by: gesture.rotation)
        gesture.rotation = 0
        if gesture.state == .began {
            delegate?.didSelectView(self)
        }
    }
    
    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        // Calculate new size based on bottom-right corner drag
        var newWidth = self.bounds.width + translation.x
        var newHeight = self.bounds.height + translation.y
        
        // Maintain aspect ratio or set minimums
        let minSize: CGFloat = 60
        newWidth = max(newWidth, minSize)
        newHeight = max(newHeight, minSize)
        
        let center = self.center
        self.bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        self.center = center
        
        gesture.setTranslation(.zero, in: self)
        self.setNeedsLayout()
    }
    
    @objc private func handleRotatePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self.superview)
        let center = self.center
        
        let currentAngle = atan2(location.y - center.y, location.x - center.x)
        
        if gesture.state == .began {
            lastRotation = currentAngle
        } else {
            let angleDiff = currentAngle - lastRotation
            self.transform = self.transform.rotated(by: angleDiff)
            lastRotation = currentAngle
        }
    }
    
    @objc func deleteView() {
        delegate?.didDeleteView(self)
        self.removeFromSuperview()
    }
    
    @objc func flipHorizontal() {
        UIView.animate(withDuration: 0.3) {
            self.imageView.transform = self.imageView.transform.scaledBy(x: -1, y: 1)
        }
    }
}

extension EditableImageView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

