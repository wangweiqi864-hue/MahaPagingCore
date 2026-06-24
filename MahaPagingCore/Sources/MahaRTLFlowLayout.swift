//
//  MahaPagingView.swift
//  MahaRTLFlowLayout
//
//  Created by jx on 2025/5/27.
//

import UIKit

class MahaRTLFlowLayout: UICollectionViewFlowLayout {
    override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        UIView.userInterfaceLayoutDirection(for: UIView.appearance().semanticContentAttribute) == .rightToLeft
    }
}
