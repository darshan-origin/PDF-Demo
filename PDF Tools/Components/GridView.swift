//
//  GridView.swift
//  PDF Tools
//
//  Created by mac on 17/02/26.
//

import UIKit

class CameraGridView: UIView {
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(UIColor.white.withAlphaComponent(1).cgColor)
        context?.setLineWidth(2)

        let width = rect.width
        let height = rect.height

        for i in 1...2 {
            let x = CGFloat(i) * width / 3
            context?.move(to: CGPoint(x: x, y: 0))
            context?.addLine(to: CGPoint(x: x, y: height))
        }

        for i in 1...2 {
            let y = CGFloat(i) * height / 3
            context?.move(to: CGPoint(x: 0, y: y))
            context?.addLine(to: CGPoint(x: width, y: y))
        }

        context?.strokePath()
    }
}

class GridView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGrid()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGrid()
    }

    private func setupGrid() {
        self.backgroundColor = UIColor.clear
        self.isUserInteractionEnabled = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawGridLines()
    }

    private func drawGridLines() {
        layer.sublayers?.filter { $0 is CAShapeLayer }.forEach { $0.removeFromSuperlayer() }

        let width = bounds.width
        let height = bounds.height

        let firstThirdX = width / 3
        let secondThirdX = 2 * width / 3
        let firstThirdY = height / 3
        let secondThirdY = 2 * height / 3

        let paths = [
            UIBezierPath(rect: CGRect(x: firstThirdX, y: 0, width: 1, height: height)),
            UIBezierPath(rect: CGRect(x: secondThirdX, y: 0, width: 1, height: height)),
            UIBezierPath(rect: CGRect(x: 0, y: firstThirdY, width: width, height: 1)),
            UIBezierPath(rect: CGRect(x: 0, y: secondThirdY, width: width, height: 1))
        ]

        for path in paths {
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.strokeColor = UIColor.white.cgColor
            shapeLayer.lineWidth = 1.0
            shapeLayer.fillColor = UIColor.white.cgColor
            layer.addSublayer(shapeLayer)
        }
    }
}


