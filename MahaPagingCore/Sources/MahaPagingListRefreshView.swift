//
//  MahaPagingListRefreshView.swift
//  MahaPagingView
//
//  Created by jiaxin on 2018/8/28.
//  Copyright © 2018年 jiaxin. All rights reserved.
//

import UIKit

open class MahaPagingListRefreshView: MahaPagingView {
    private var previousScrollingListViewContentOffsetY: CGFloat = 0

    public override init(delegate: MahaPagingViewDelegate, listContainerType: MahaPagingListContainerType = .collectionView) {
        super.init(delegate: delegate, listContainerType: listContainerType)

        mainTableView.bounces = false
    }

    override open func preferredProcessMainTableViewDidScroll(_ scrollView: UIScrollView) {
        if shouldLockMainTableViewBounce(for: scrollView) {
            mainTableView.bounces = false
            mainTableView.contentOffset = .zero
            return
        }
        if pinSectionHeaderVerticalOffset != 0 && !currentListIsScrollingBeyondMinimumOffset {
            mainTableView.bounces = true
        }
        guard let activeListScrollView = currentScrollingListView else { return }
        if activeListScrollView.contentOffset.y > minimumContentOffsetY(for: activeListScrollView) {
            lockMainTableViewAtMaximumContentOffset()
        }

        if mainTableView.contentOffset.y < maximumMainTableViewContentOffsetY() {
            for list in validListDict.values {
                let listScrollView = list.listScrollView()
                if listScrollView.contentOffset.y > minimumContentOffsetY(for: listScrollView) {
                    resetListScrollViewToMinimumContentOffset(listScrollView)
                }
            }
        }

        if scrollView.contentOffset.y > maximumMainTableViewContentOffsetY()
            && activeListScrollView.contentOffset.y == minimumContentOffsetY(for: activeListScrollView) {
            lockMainTableViewAtMaximumContentOffset()
        }
    }
    
    override open func preferredProcessListViewDidScroll(scrollView: UIScrollView) {
        guard let activeListScrollView = currentScrollingListView else { return }
        var shouldProcess = true
        if activeListScrollView.contentOffset.y <= previousScrollingListViewContentOffsetY {
            if mainTableView.contentOffset.y == 0 {
                shouldProcess = false
            } else if mainTableView.contentOffset.y < maximumMainTableViewContentOffsetY() {
                resetListScrollViewToMinimumContentOffset(activeListScrollView)
                activeListScrollView.showsVerticalScrollIndicator = false
            }
        }
        if shouldProcess {
            if mainTableView.contentOffset.y < maximumMainTableViewContentOffsetY() {
                if activeListScrollView.contentOffset.y > minimumContentOffsetY(for: activeListScrollView) {
                    resetListScrollViewToMinimumContentOffset(activeListScrollView)
                    activeListScrollView.showsVerticalScrollIndicator = false
                }
            } else {
                lockMainTableViewAtMaximumContentOffset()
                activeListScrollView.showsVerticalScrollIndicator = true
            }
        }
        previousScrollingListViewContentOffsetY = activeListScrollView.contentOffset.y
    }
    
    private var currentListIsScrollingBeyondMinimumOffset: Bool {
        guard let activeListScrollView = currentScrollingListView else { return false }
        return activeListScrollView.contentOffset.y > minimumContentOffsetY(for: activeListScrollView)
    }

    private func shouldLockMainTableViewBounce(for scrollView: UIScrollView) -> Bool {
        pinSectionHeaderVerticalOffset != 0 && !currentListIsScrollingBeyondMinimumOffset && scrollView.contentOffset.y <= 0
    }
}
