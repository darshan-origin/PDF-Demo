import UIKit

protocol EditableImageViewDelegate: AnyObject {
    func didSelectView(_ view: EditableImageView)
    func didDeleteView(_ view: EditableImageView)
}

class EditableImageView: UIView {
    
    weak var delegate: EditableImageViewDelegate?
    let imageView = UIImageView()
    
    var editMode: EditableViewMode = .general {
        didSet { updateControlVisibility(animated: false) }
    }
    
    var onDateChangeTapped: (() -> Void)?
    
    var isSelected: Bool = false {
        didSet {
            updateControlVisibility(animated: true)
            if isSelected {
                superview?.bringSubviewToFront(self)
            }
        }
    }
    
    // UI Elements
    private let deleteButton = UIButton(type: .custom)
    private let resizeButton = UIButton(type: .custom)
    private let dashedBorder = CAShapeLayer()
    
    // Constants
    private let controlSize: CGFloat = 30
    private let touchArea: CGFloat = 44
    private let borderPadding: CGFloat = 15
    
    // State for gestures
    private var initialBounds: CGRect = .zero
    private var initialDistance: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        clipsToBounds = false
        isUserInteractionEnabled = true
        
        // Image View
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)
        
        // Dashed Border
        dashedBorder.strokeColor = UIColor.lightGray.withAlphaComponent(0.6).cgColor
        dashedBorder.fillColor = nil
        dashedBorder.lineWidth = 1.0
        dashedBorder.lineDashPattern = [4, 3]
        dashedBorder.opacity = 0
        layer.addSublayer(dashedBorder)
        
        // Controls
        // Trash icon at top-left
        setupControl(deleteButton, icon: "trash.fill", color: .systemRed, action: #selector(handleDelete))
        
        // Resize icon at bottom-right
        setupControl(resizeButton, icon: "arrow.down.left.and.arrow.up.right", color: .white, iconColor: .systemRed, action: nil)
        let resizePan = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
        resizeButton.addGestureRecognizer(resizePan)
        
        // Main Gestures
        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        dragGesture.delegate = self
        addGestureRecognizer(dragGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        tapGesture.require(toFail: doubleTap)
        
        // Support standard pinch for extra smoothness
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
        
        updateControlVisibility(animated: false)
    }
    
    private func setupControl(_ button: UIButton, icon: String, color: UIColor, iconColor: UIColor = .white, action: Selector?) {
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.tintColor = iconColor
        button.backgroundColor = color
        button.layer.cornerRadius = controlSize / 2
        button.isExclusiveTouch = true
        
        // Shadow for premium look
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 4
        
        if let action = action {
            button.addTarget(self, action: action, for: .touchUpInside)
        }
        
        addSubview(button)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let contentRect = bounds.insetBy(dx: borderPadding, dy: borderPadding)
        imageView.frame = contentRect
        
        dashedBorder.frame = bounds
        dashedBorder.path = UIBezierPath(rect: contentRect).cgPath
        
        // Positions based on the mockup image
        let halfTouch = touchArea / 2
        
        // Top-Left: Delete
        deleteButton.frame = CGRect(x: borderPadding - halfTouch, y: borderPadding - halfTouch, width: touchArea, height: touchArea)
        
        // Bottom-Right: Resize
        resizeButton.frame = CGRect(x: bounds.width - borderPadding - halfTouch, y: bounds.height - borderPadding - halfTouch, width: touchArea, height: touchArea)
        
        [deleteButton, resizeButton].forEach { btn in
            let pad = (touchArea - controlSize) / 2
            btn.contentEdgeInsets = UIEdgeInsets(top: pad, left: pad, bottom: pad, right: pad)
        }
    }
    
    // MARK: - Interaction
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if isHidden || alpha < 0.01 || !isUserInteractionEnabled { return nil }
        
        if isSelected {
            for btn in [deleteButton, resizeButton] {
                let localPoint = convert(point, to: btn)
                if btn.point(inside: localPoint, with: event) {
                    return btn
                }
            }
        }
        
        if self.point(inside: point, with: event) {
            return super.hitTest(point, with: event) ?? self
        }
        
        return nil
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let expanded = bounds.insetBy(dx: -borderPadding, dy: -borderPadding)
        return expanded.contains(point)
    }
    
    // MARK: - Visibility
    
    private func updateControlVisibility(animated: Bool) {
        let targetAlpha: CGFloat = isSelected ? 1.0 : 0.0
        
        let actions = {
            self.dashedBorder.opacity = Float(targetAlpha)
            self.deleteButton.alpha = targetAlpha
            self.resizeButton.alpha = targetAlpha
            
            self.deleteButton.isUserInteractionEnabled = self.isSelected
            self.resizeButton.isUserInteractionEnabled = self.isSelected
        }
        
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .allowUserInteraction, animations: actions)
            
            if isSelected {
                [deleteButton, resizeButton].forEach { button in
                    button.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                    UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 1.0) {
                        button.transform = .identity
                    }
                }
            }
        } else {
            actions()
        }
    }
    
    func hideControls() {
        isSelected = false
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.didSelectView(self)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if let onDateChange = onDateChangeTapped {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onDateChange()
        }
    }
    
    @objc private func handleDrag(_ gesture: UIPanGestureRecognizer) {
        guard let parent = superview else { return }
        
        if gesture.state == .began {
            delegate?.didSelectView(self)
        }
        
        let translation = gesture.translation(in: parent)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        gesture.setTranslation(.zero, in: parent)
    }
    
    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        guard let parent = superview else { return }
        let point = gesture.location(in: parent)
        
        switch gesture.state {
        case .began:
            initialBounds = bounds
            initialDistance = hypot(point.x - center.x, point.y - center.y)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .changed:
            let currentDist = hypot(point.x - center.x, point.y - center.y)
            let scale = currentDist / initialDistance
            
            let newW = max(initialBounds.width * scale, 60)
            let newH = max(initialBounds.height * scale, 60)
            
            bounds = CGRect(x: 0, y: 0, width: newW, height: newH)
            setNeedsLayout()
        default: break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            let scale = gesture.scale
            let newW = max(bounds.width * scale, 60)
            let newH = max(bounds.height * scale, 60)
            bounds = CGRect(x: 0, y: 0, width: newW, height: newH)
            gesture.scale = 1.0
            setNeedsLayout()
        }
    }
    
    @objc private func handleDelete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIView.animate(withDuration: 0.2, animations: {
            self.transform = self.transform.scaledBy(x: 0.1, y: 0.1)
            self.alpha = 0
        }) { _ in
            self.delegate?.didDeleteView(self)
            self.removeFromSuperview()
        }
    }
}

extension EditableImageView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let loc = touch.location(in: self)
        for btn in [deleteButton, resizeButton] {
            if btn.isUserInteractionEnabled && btn.alpha > 0.1 && btn.frame.contains(loc) {
                return false
            }
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}
