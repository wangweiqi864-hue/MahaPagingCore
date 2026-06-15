//
//  MahaPagingView.swift
//  MahaRTLFlowLayout
//
//  Created by jx on 2025/5/27.
//

import UIKit

class MahaRTLFlowLayout: UICollectionViewFlowLayout {
    override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        get {
            return UIView.userInterfaceLayoutDirection(for: UIView.appearance().semanticContentAttribute) == .rightToLeft
        }
    }
}
