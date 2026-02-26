//
//  UILable.swift
//  PDF Tools
//
//  Created by mac on 17/02/26.
//

import UIKit

extension UILabel {
    func increaseFontSize(by amount: CGFloat = 1.0) {
        self.font = self.font.withSize(self.font.pointSize + amount)
    }
    func decreaseFontSize(by amount: CGFloat = 1.0) {
        self.font = self.font.withSize(self.font.pointSize - amount)
    }
}
