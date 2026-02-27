import UIKit

protocol EditableImageViewDelegate: AnyObject {
    func didSelectView(_ view: EditableImageView)
    func didDeleteView(_ view: EditableImageView)
}

class EditableImageView: UIView {
    
    weak var delegate: EditableImageViewDelegate?
    let imageView = UIImageView()
    var editMode: EditableViewMode = .general
    var onDateChangeTapped: (() -> Void)?
    var isSelected: Bool = false {
        didSet { animateSelectionState() }
    }
    
    private let deleteButton = UIButton(type: .custom)
    private let resizeButton = UIButton(type: .custom)
    private let rotateButton = UIButton(type: .custom)
    private let flipButton   = UIButton(type: .custom)
    private let changeDateButton = UIButton(type: .custom)
    private let controlSize: CGFloat  = 22
    private let touchTarget: CGFloat  = 22        // generous tap area
    private let borderInset: CGFloat  = 11        // half of controlSize
    private var lastRotationAngle: CGFloat = 0
    private var initialBounds: CGRect = .zero
    private var initialDistance: CGFloat = 0
    private let dashedBorder = CAShapeLayer()
    private var dragPanGesture: UIPanGestureRecognizer!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        
        setupImageView()
        setupDashedBorder()
        setupControlButtons()
        setupGestures()
        setControlsVisible(false, animated: false)
    }
    
    private func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.clipsToBounds = true
        addSubview(imageView)
    }
    
    private func setupDashedBorder() {
        dashedBorder.fillColor = UIColor.clear.cgColor
        dashedBorder.strokeColor = UIColor.systemBlue.cgColor
        dashedBorder.lineWidth = 1.5
        dashedBorder.lineDashPattern = [6, 4]
        dashedBorder.opacity = 0
        layer.addSublayer(dashedBorder)
    }
    
    private func setupControlButtons() {
        configureControl(flipButton, systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill",color: .systemYellow)
        flipButton.addTarget(self, action: #selector(onFlipTapped), for: .touchUpInside)
        
        configureControl(deleteButton, systemName: "xmark.circle.fill", color: .systemRed)
        deleteButton.addTarget(self, action: #selector(onDeleteTapped), for: .touchUpInside)
        
        configureControl(rotateButton, systemName: "rotate.right.fill", color: .systemGreen)
        let rotatePan = UIPanGestureRecognizer(target: self, action: #selector(handleRotateCornerPan(_:)))
        rotateButton.addGestureRecognizer(rotatePan)
        
        configureControl(resizeButton, systemName: "arrow.up.left.and.arrow.down.right.circle.fill", color: .systemBlue)
        let resizePan = UIPanGestureRecognizer(target: self, action: #selector(handleResizeCornerPan(_:)))
        resizeButton.addGestureRecognizer(resizePan)
        
        configureControl(changeDateButton, systemName: "calendar.badge.plus", color: .systemIndigo)
        changeDateButton.addTarget(self, action: #selector(onDateChangeInternalTapped), for: .touchUpInside)
        
        [flipButton, deleteButton, rotateButton, resizeButton, changeDateButton].forEach { addSubview($0) }
    }
    
    private func configureControl(_ button: UIButton, systemName: String, color: UIColor) {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: controlSize * 0.5, weight: .bold)
        button.setImage(UIImage(systemName: systemName, withConfiguration: symbolConfig), for: .normal)
        button.tintColor = .white
        button.backgroundColor = color
        button.layer.cornerRadius = controlSize / 2
        button.clipsToBounds = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        button.layer.shadowOpacity = 0.35
        button.layer.shadowRadius = 3
        button.frame = CGRect(x: 0, y: 0, width: touchTarget, height: touchTarget)
        
        var config = UIButton.Configuration.plain()
        let pad = (touchTarget - controlSize) / 2
        config.contentInsets = NSDirectionalEdgeInsets(top: pad, leading: pad, bottom: pad, trailing: pad)
        button.configuration = config
        button.backgroundColor = color
    }
    
    private func setupGestures() {
        dragPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDragPan(_:)))
        dragPanGesture.maximumNumberOfTouches = 1
        dragPanGesture.delegate = self
        addGestureRecognizer(dragPanGesture)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
        
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleTwoFingerRotation(_:)))
        rotation.delegate = self
        addGestureRecognizer(rotation)
    }
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView.frame = bounds.insetBy(dx: borderInset, dy: borderInset)
        
        let borderRect = bounds.insetBy(dx: borderInset, dy: borderInset)
        dashedBorder.path = UIBezierPath(rect: borderRect).cgPath
        dashedBorder.frame = bounds
        flipButton.center   = CGPoint(x: 0, y: 0)                       // Top-Left
        deleteButton.center  = CGPoint(x: bounds.width, y: 0)           // Top-Right
        rotateButton.center  = CGPoint(x: 0, y: bounds.height)          // Bottom-Left
        resizeButton.center  = CGPoint(x: bounds.width, y: bounds.height) // Bottom-Right
        changeDateButton.center = CGPoint(x: bounds.width, y: bounds.height) // Bottom-Right (Date Mode)
    }
    
    private func animateSelectionState() {
        setControlsVisible(isSelected, animated: true)
    }
    
    private func setControlsVisible(_ visible: Bool, animated: Bool) {
        let targetAlpha: CGFloat = visible ? 1.0 : 0.0
        let borderOpacity: Float = visible ? 1.0 : 0.0
        
        let work = { [self] in
            if editMode == .general {
                flipButton.alpha = targetAlpha
                rotateButton.alpha = targetAlpha
                resizeButton.alpha = targetAlpha
                changeDateButton.alpha = 0
            } else {
                flipButton.alpha = 0
                rotateButton.alpha = 0
                resizeButton.alpha = 0
                changeDateButton.alpha = targetAlpha
            }
            deleteButton.alpha = targetAlpha
            dashedBorder.opacity = borderOpacity
        }
        
        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
                work()
            }
            
            if visible {
                [flipButton, deleteButton, rotateButton, resizeButton].forEach { btn in
                    btn.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                    UIView.animate(withDuration: 0.35, delay: 0.05, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
                        btn.transform = .identity
                    }
                }
            }
        } else {
            work()
        }
        
        [flipButton, deleteButton, rotateButton, resizeButton, changeDateButton].forEach {
            $0.isUserInteractionEnabled = visible
        }
    }
    
    private func lightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func mediumHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let loc = gesture.location(in: self)
        for btn in [flipButton, deleteButton, rotateButton, resizeButton] where btn.frame.contains(loc) {
            return
        }
        delegate?.didSelectView(self)
        lightHaptic()
    }
    
    @objc private func handleDragPan(_ gesture: UIPanGestureRecognizer) {
        guard let parent = superview else { return }
        
        switch gesture.state {
        case .began:
            delegate?.didSelectView(self)
            lightHaptic()
            
        case .changed:
            let translation = gesture.translation(in: parent)
            center = CGPoint(x: center.x + translation.x,
                             y: center.y + translation.y)
            gesture.setTranslation(.zero, in: parent)
            
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            delegate?.didSelectView(self)
            
        case .changed:
            let currentScale = hypot(transform.a, transform.c)
            let proposedScale = currentScale * gesture.scale
            let clampedScale = min(max(proposedScale, 0.3), 5.0)
            let delta = clampedScale / currentScale
            
            transform = transform.scaledBy(x: delta, y: delta)
            gesture.scale = 1
            
        default:
            break
        }
    }
    
    @objc private func handleTwoFingerRotation(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .began:
            delegate?.didSelectView(self)
            
        case .changed:
            transform = transform.rotated(by: gesture.rotation)
            gesture.rotation = 0
            
        default:
            break
        }
    }
    
    
    @objc private func onDeleteTapped() {
        mediumHaptic()
        
        UIView.animate(withDuration: 0.25, animations: {
            self.transform = self.transform.scaledBy(x: 0.01, y: 0.01)
            self.alpha = 0
        }) { _ in
            self.delegate?.didDeleteView(self)
            self.removeFromSuperview()
        }
    }
    
    @objc private func onFlipTapped() {
        lightHaptic()
        
        UIView.animate(withDuration: 0.3, delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5) {
            self.imageView.transform = self.imageView.transform.scaledBy(x: -1, y: 1)
        }
    }
    
    @objc private func onDateChangeInternalTapped() {
        lightHaptic()
        onDateChangeTapped?()
    }
    
    @objc private func handleResizeCornerPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            initialBounds = bounds
            delegate?.didSelectView(self)
            lightHaptic()
            
        case .changed:
            let translation = gesture.translation(in: superview)
            let angle = atan2(transform.b, transform.a)
            let dx = translation.x * cos(angle) + translation.y * sin(angle)
            let dy = -translation.x * sin(angle) + translation.y * cos(angle)
            let diag = (dx + dy) / 2.0
            let minSize: CGFloat = 60
            let newWidth  = max(initialBounds.width  + diag, minSize)
            let newHeight = max(initialBounds.height + diag, minSize)
            
            let savedCenter = center
            bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
            center = savedCenter
            setNeedsLayout()
            layoutIfNeeded()
            
        case .ended, .cancelled:
            initialBounds = bounds
            gesture.setTranslation(.zero, in: superview)
            
        default:
            break
        }
    }
    
    @objc private func handleRotateCornerPan(_ gesture: UIPanGestureRecognizer) {
        guard let parent = superview else { return }
        let location = gesture.location(in: parent)
        let viewCenter = center
        
        let currentAngle = atan2(location.y - viewCenter.y, location.x - viewCenter.x)
        
        switch gesture.state {
        case .began:
            lastRotationAngle = currentAngle
            delegate?.didSelectView(self)
            lightHaptic()
            
        case .changed:
            let angleDelta = currentAngle - lastRotationAngle
            transform = transform.rotated(by: angleDelta)
            lastRotationAngle = currentAngle
            
        default:
            break
        }
    }
    
    func hideControls() {
        setControlsVisible(false, animated: false)
    }
    
    func showControls() {
        setControlsVisible(true, animated: false)
    }
}

extension EditableImageView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer is UIPinchGestureRecognizer && other is UIRotationGestureRecognizer) ||
            (gestureRecognizer is UIRotationGestureRecognizer && other is UIPinchGestureRecognizer) {
            return true
        }
        return false
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === dragPanGesture {
            let loc = gestureRecognizer.location(in: self)
            for btn in [flipButton, deleteButton, rotateButton, resizeButton, changeDateButton] {
                if btn.frame.contains(loc) {
                    return false
                }
            }
        }
        return true
    }
}
