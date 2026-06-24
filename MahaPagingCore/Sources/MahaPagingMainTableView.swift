//
//  MahaPagingViewMainTableView.swift
//  MahaPagingView
//
//  Created by jiaxin on 2018/5/22.
//  Copyright © 2018年 jiaxin. All rights reserved.
//

import UIKit

@objc public protocol MahaPagingMainTableViewGestureDelegate {
    //如果headerView（或其他地方）有水平滚动的scrollView，当其正在左右滑动的时候，就不能让列表上下滑动，所以有此代理方法进行对应处理
    func mainTableViewGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
}

open class MahaPagingMainTableView: UITableView, UIGestureRecognizerDelegate {
    public weak var gestureDelegate: MahaPagingMainTableViewGestureDelegate?

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let gestureDelegate {
            return gestureDelegate.mainTableViewGestureRecognizer(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer)
        }
        return shouldRecognizePanGestureSimultaneously(gestureRecognizer, with: otherGestureRecognizer)
    }

    private func shouldRecognizePanGestureSimultaneously(_ gestureRecognizer: UIGestureRecognizer, with otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer.isKind(of: UIPanGestureRecognizer.self) && otherGestureRecognizer.isKind(of: UIPanGestureRecognizer.self)
    }
}
