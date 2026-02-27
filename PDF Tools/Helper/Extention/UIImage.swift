//
//  Untitled.swift
//  PDF Tools
//
//  Created by mac on 18/02/26.
//

import UIKit

extension UIImage {
    func rotate(radians: CGFloat) -> UIImage {
        var newSize = CGRect(origin: .zero, size: self.size).applying(CGAffineTransform(rotationAngle: radians)).integral.size
        
        newSize.width = abs(newSize.width)
        newSize.height = abs(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return self }
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        context.rotate(by: radians)
        
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage ?? self
    }
    
    func withWatermark(image watermark: UIImage, opacity: CGFloat = 0.5) -> UIImage? {
        autoreleasepool {
            let size = self.size
            let renderer = UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat.default())
            return renderer.image { context in
                self.draw(in: CGRect(origin: .zero, size: size))
                
                let watermarkWidth = size.width * 0.15
                let watermarkHeight = (watermark.size.height / watermark.size.width) * watermarkWidth
                let padding: CGFloat = 20
                let rect = CGRect(x: size.width - watermarkWidth - padding, y: size.height - watermarkHeight - padding, width: watermarkWidth, height: watermarkHeight)
                
                watermark.draw(in: rect, blendMode: .normal, alpha: opacity)
            }
        }
    }
    
}
