//
//  UIView.swift
//  PDF Tools
//
//  Created by mac on 18/02/26.
//

import UIKit

extension UIView {
    func addBottomDropShadow(shadowColor: UIColor = .black, opacity: Float = 0.4, radius: CGFloat = 4.0, offsetHeight: CGFloat = 1.0) {
        layer.masksToBounds = false
        layer.shadowColor = shadowColor.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = CGSize(width: 0, height: offsetHeight)
        layer.shadowRadius = radius
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
    }
    
    
    func applyShadow(
        cornerRadius: CGFloat = 12,
        shadowColor: UIColor = .black,
        shadowOpacity: Float = 0.1,
        shadowRadius: CGFloat = 8,
        shadowOffset: CGSize = CGSize(width: 0, height: 4)
    ) {
        self.layer.cornerRadius = cornerRadius
        self.layer.masksToBounds = false
        self.layer.shadowColor = shadowColor.cgColor
        self.layer.shadowOpacity = shadowOpacity
        self.layer.shadowRadius = shadowRadius
        self.layer.shadowOffset = shadowOffset
        
        let path = UIBezierPath(
            roundedRect: self.bounds,
            cornerRadius: cornerRadius
        )
        self.layer.shadowPath = path.cgPath
    }
}
