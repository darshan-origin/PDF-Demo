//
//  Untitled.swift
//  PDF Tools
//
//  Created by mac on 18/02/26.
//
import UIKit

extension UITextField {
    func setDottedUnderline(color: UIColor, width: CGFloat, dashPattern: [NSNumber] = [2, 2]) {
        self.borderStyle = .none
        self.layer.sublayers?.forEach { if $0.name == "dottedUnderline" { $0.removeFromSuperlayer() } }

        let shapeLayer = CAShapeLayer()
        shapeLayer.name = "dottedUnderline"
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = width
        shapeLayer.lineDashPattern = dashPattern
        shapeLayer.lineJoin = .round

        let path = UIBezierPath()
        let y = self.bounds.height - 1  
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: self.bounds.width, y: y))
        shapeLayer.path = path.cgPath

        self.layer.addSublayer(shapeLayer)
    }
}
