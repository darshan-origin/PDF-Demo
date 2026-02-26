//
//  SignatureManageVC.swift
//  PDF Tools
//
//  Created by mac on 18/02/26.
//

import UIKit
import PencilKit

protocol SecondaryViewControllerDelegate: AnyObject {
    func didSelectImage(_ image: UIImage)
}

class SignatureManageVC: UIViewController, UITextFieldDelegate, PKCanvasViewDelegate {

    @IBOutlet weak var view_topNAv: UIView!
    @IBOutlet weak var lbl_titleType: UILabel!
    @IBOutlet weak var view_baseTextSigType: UIView!
    @IBOutlet weak var view_baseDrawSigType: UIView!
    @IBOutlet weak var txt_typingSig: UITextField!
    @IBOutlet weak var color_picker: UIColorWell!
    
    var sigType = ""
    var finalGeneratedImage = UIImage()
    weak var delegate: SecondaryViewControllerDelegate?

    
    private var canvasView: PKCanvasView!
    private var toolPicker: PKToolPicker?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if canvasView != nil {
            canvasView.frame = view_baseDrawSigType.bounds
        }
    }

    @IBAction func onTapped_back(_ sender: Any) {
        NavigationManager.shared.popViewController(from: self)
    }
    
    @IBAction func onTapped_save(_ sender: Any) {
        if sigType == "Draw Signature" {
            let drawing = canvasView.drawing
            let image = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
            finalGeneratedImage = image
        }
        
        delegate?.didSelectImage(finalGeneratedImage)
        NavigationManager.shared.popViewController(from: self)
    }
    
    @IBAction func onTapped_undo(_ sender: Any) {
        if let undoManager = canvasView.undoManager, undoManager.canUndo {
            undoManager.undo()
        }
    }

    @IBAction func onTapped_redo(_ sender: Any) {
        if let undoManager = canvasView.undoManager, undoManager.canRedo {
            undoManager.redo()
        }
    }

    @IBAction func onTapped_reset(_ sender: Any) {
        canvasView.drawing = PKDrawing()
        canvasView.undoManager?.removeAllActions()
    }

}

extension SignatureManageVC {
    
    func initUI() {
        
        if sigType == "Type Signature" {
            view_baseTextSigType.isHidden = false
            view_baseDrawSigType.isHidden = true
        } else {
            view_baseTextSigType.isHidden = true
            view_baseDrawSigType.isHidden = false
        }
        
        view_topNAv.addBottomDropShadow()
        lbl_titleType.text = sigType
        view_baseTextSigType.applyShadow()
        view_baseDrawSigType.applyShadow()
        
        setupTextField()
        setupColorPicker()
        
        if sigType != "Type Signature" {
            setupPencilDrawing()
        }
        
        hideKeyboardOnTap()
    }
        
    func setupTextField() {
        
        txt_typingSig.delegate = self
        
        let signatureFont = UIFont(name: "Zapfino", size: 35) ?? UIFont.systemFont(ofSize: 35)
        
        txt_typingSig.attributedPlaceholder = NSAttributedString(
            string: "Signature",
            attributes: [
                .font: signatureFont,
                .foregroundColor: UIColor.lightGray
            ]
        )
        
        txt_typingSig.font = signatureFont
        txt_typingSig.textColor = .black
    }
        
    func setupPencilDrawing() {
        
        canvasView = PKCanvasView(frame: view_baseDrawSigType.bounds)
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.backgroundColor = .clear
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = self
        
        view_baseDrawSigType.addSubview(canvasView)
        
        let defaultTool = PKInkingTool(.pen, color: .black, width: 5)
        canvasView.tool = defaultTool
    }
        
    func setupColorPicker() {
        color_picker.supportsAlpha = true
        color_picker.selectedColor = .black
        
        color_picker.addTarget(self, action: #selector(colorDidChange(_:)), for: .valueChanged)
    }
    
    @objc func colorDidChange(_ sender: UIColorWell) {
        
        let selectedColor = sender.selectedColor
        txt_typingSig.textColor = selectedColor
        
        if sigType != "Type Signature" {
            let newTool = PKInkingTool(.pen, color: selectedColor!, width: 5)
            canvasView.tool = newTool
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.text?.isEmpty ?? true {
            textField.font = UIFont(name: "AvenirNext-Regular", size: 20)
        }
    }
}
