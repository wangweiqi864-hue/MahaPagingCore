//
//  MahaPagingSmoothView.swift
//  MahaPagingView
//
//  Created by jiaxin on 2019/11/20.
//  Copyright © 2019 jiaxin. All rights reserved.
//

import UIKit

@objc public protocol MahaPagingSmoothViewListViewDelegate {
    /// 返回listView。如果是vc包裹的就是vc.view；如果是自定义view包裹的，就是自定义view自己。
    func listView() -> UIView
    /// 返回MahaPagingSmoothViewListViewDelegate内部持有的UIScrollView或UITableView或UICollectionView
    func listScrollView() -> UIScrollView
    @objc optional func listDidAppear()
    @objc optional func listDidDisappear()
}

@objc
public protocol MahaPagingSmoothViewDataSource {
    /// 返回页面header的高度
    func heightForPagingHeader(in pagingView: MahaPagingSmoothView) -> CGFloat
    /// 返回页面header视图
    func viewForPagingHeader(in pagingView: MahaPagingSmoothView) -> UIView
    /// 返回悬浮视图的高度
    func heightForPinHeader(in pagingView: MahaPagingSmoothView) -> CGFloat
    /// 返回悬浮视图
    func viewForPinHeader(in pagingView: MahaPagingSmoothView) -> UIView
    /// 返回列表的数量
    func numberOfLists(in pagingView: MahaPagingSmoothView) -> Int
    /// 根据index初始化一个对应列表实例，需要是遵从`MahaPagingSmoothViewListViewDelegate`协议的对象。
    /// 如果列表是用自定义UIView封装的，就让自定义UIView遵从`MahaPagingSmoothViewListViewDelegate`协议，该方法返回自定义UIView即可。
    /// 如果列表是用自定义UIViewController封装的，就让自定义UIViewController遵从`MahaPagingSmoothViewListViewDelegate`协议，该方法返回自定义UIViewController即可。
    func pagingView(_ pagingView: MahaPagingSmoothView, initListAtIndex index: Int) -> MahaPagingSmoothViewListViewDelegate
}

@objc
public protocol MahaPagingSmoothViewDelegate {
    @objc optional func pagingSmoothViewDidScroll(_ scrollView: UIScrollView)
}


open class MahaPagingSmoothView: UIView {
    public private(set) var listDict = [Int : MahaPagingSmoothViewListViewDelegate]()
    public let listCollectionView: MahaPagingSmoothCollectionView
    public var defaultSelectedIndex: Int = 0
    public weak var delegate: MahaPagingSmoothViewDelegate?

    weak var dataSource: MahaPagingSmoothViewDataSource?
    private var listHeaderViewsByIndex = [Int : UIView]()
    private var isSynchronizingListContentOffset = false
    private let pagingHeaderContainerView: UIView
    private var currentPagingHeaderContainerOriginY: CGFloat = 0
    private var currentIndex: Int = 0
    private var currentListScrollView: UIScrollView?
    private var pagingHeaderHeight: CGFloat = 0
    private var pinHeaderHeight: CGFloat = 0
    private var pagingHeaderContainerHeight: CGFloat = 0
    private let collectionViewCellReuseIdentifier = "cell"
    private var initialContentOffsetYForNewList: CGFloat = 0
    private var fallbackScrollView: UIScrollView?

    deinit {
        removeObserversFromAllLists()
    }

    public init(dataSource: MahaPagingSmoothViewDataSource) {
        self.dataSource = dataSource
        pagingHeaderContainerView = UIView()
        let layout = MahaRTLFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = .horizontal
        listCollectionView = MahaPagingSmoothCollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        super.init(frame: CGRect.zero)

        listCollectionView.dataSource = self
        listCollectionView.delegate = self
        listCollectionView.isPagingEnabled = true
        listCollectionView.bounces = false
        listCollectionView.showsHorizontalScrollIndicator = false
        listCollectionView.scrollsToTop = false
        listCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: collectionViewCellReuseIdentifier)
        if #available(iOS 10.0, *) {
            listCollectionView.isPrefetchingEnabled = false
        }
        if #available(iOS 11.0, *) {
            listCollectionView.contentInsetAdjustmentBehavior = .never
        }
        listCollectionView.bindPagingHeaderContainerView(pagingHeaderContainerView)
        addSubview(listCollectionView)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func reloadData() {
        guard let dataSource = dataSource else { return }
        resetRuntimeState()
        removeAllListHeaders()
        removeAllLoadedLists()
        configureHeaderMetrics(using: dataSource)
        rebuildPagingHeaderViews(using: dataSource)
        listCollectionView.setContentOffset(contentOffsetForList(at: defaultSelectedIndex), animated: false)
        listCollectionView.reloadData()
        updateFallbackScrollViewIfNeeded(listCount: dataSource.numberOfLists(in: self))
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        listCollectionView.frame = bounds
        if pagingHeaderContainerView.frame == CGRect.zero {
            reloadData()
        }
        if fallbackScrollView != nil {
            fallbackScrollView?.frame = bounds
        }
    }

    func listDidScroll(scrollView: UIScrollView) {
        if listCollectionView.isDragging || listCollectionView.isDecelerating {
            return
        }
        let index = listIndex(for: scrollView)
        if index != currentIndex {
            return
        }
        currentListScrollView = scrollView
        let contentOffsetY = scrollView.contentOffset.y + pagingHeaderContainerHeight
        if contentOffsetY < pagingHeaderHeight {
            synchronizeHeaderWithCurrentList(scrollView, contentOffsetY: contentOffsetY)
        } else {
            pinHeaderToTopIfNeeded()
            synchronizeSiblingListsAfterHeaderPinnedIfNeeded()
        }
    }

    //MARK: - KVO

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            if let scrollView = object as? UIScrollView {
                listDidScroll(scrollView: scrollView)
            }
        }else if keyPath == "contentSize" {
            if let scrollView = object as? UIScrollView {
                ensureMinimumContentSize(for: scrollView)
            }
        }else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    //MARK: - Private
    func listHeader(for listScrollView: UIScrollView) -> UIView? {
        for (index, list) in listDict {
            if list.listScrollView() == listScrollView {
                return listHeaderViewsByIndex[index]
            }
        }
        return nil
    }

    func listIndex(for listScrollView: UIScrollView) -> Int {
        for (index, list) in listDict {
            if list.listScrollView() == listScrollView {
                return index
            }
        }
        return 0
    }

    func listDidAppear(at index: Int) {
        guard isValidListIndex(index) else {
            return
        }
        listDict[index]?.listDidAppear?()
    }

    func listDidDisappear(at index: Int) {
        guard isValidListIndex(index) else {
            return
        }
        listDict[index]?.listDidDisappear?()
    }

    /// 列表左右切换滚动结束之后，需要把pagerHeaderContainerView添加到当前index的列表上面
    func horizontalScrollDidEnd(at index: Int) {
        currentIndex = index
        guard let listHeader = listHeaderViewsByIndex[index], let listScrollView = listDict[index]?.listScrollView() else {
            return
        }
        updateScrollsToTopTarget(using: listScrollView)
        if listScrollView.contentOffset.y <= -pinHeaderHeight {
            pagingHeaderContainerView.frame.origin.y = 0
            listHeader.addSubview(pagingHeaderContainerView)
        }
    }

    private func resetRuntimeState() {
        currentListScrollView = nil
        currentIndex = defaultSelectedIndex
        currentPagingHeaderContainerOriginY = 0
        isSynchronizingListContentOffset = false
    }

    private func removeObserversFromAllLists() {
        listDict.values.forEach { list in
            let listScrollView = list.listScrollView()
            listScrollView.removeObserver(self, forKeyPath: "contentOffset")
            listScrollView.removeObserver(self, forKeyPath: "contentSize")
        }
    }

    private func removeAllListHeaders() {
        listHeaderViewsByIndex.values.forEach { $0.removeFromSuperview() }
        listHeaderViewsByIndex.removeAll()
    }

    private func removeAllLoadedLists() {
        removeObserversFromAllLists()
        listDict.values.forEach { $0.listView().removeFromSuperview() }
        listDict.removeAll()
    }

    private func configureHeaderMetrics(using dataSource: MahaPagingSmoothViewDataSource) {
        pagingHeaderHeight = dataSource.heightForPagingHeader(in: self)
        pinHeaderHeight = dataSource.heightForPinHeader(in: self)
        pagingHeaderContainerHeight = pagingHeaderHeight + pinHeaderHeight
    }

    private func rebuildPagingHeaderViews(using dataSource: MahaPagingSmoothViewDataSource) {
        pagingHeaderContainerView.subviews.forEach { $0.removeFromSuperview() }
        let pagingHeaderView = dataSource.viewForPagingHeader(in: self)
        let pinHeaderView = dataSource.viewForPinHeader(in: self)
        pagingHeaderContainerView.addSubview(pagingHeaderView)
        pagingHeaderContainerView.addSubview(pinHeaderView)

        pagingHeaderContainerView.frame = CGRect(x: 0, y: 0, width: bounds.size.width, height: pagingHeaderContainerHeight)
        pagingHeaderView.frame = CGRect(x: 0, y: 0, width: bounds.size.width, height: pagingHeaderHeight)
        pinHeaderView.frame = CGRect(x: 0, y: pagingHeaderHeight, width: bounds.size.width, height: pinHeaderHeight)
    }

    private func updateFallbackScrollViewIfNeeded(listCount: Int) {
        if listCount == 0 {
            let scrollView = fallbackScrollView ?? UIScrollView()
            if fallbackScrollView == nil {
                addSubview(scrollView)
                fallbackScrollView = scrollView
            }
            scrollView.frame = bounds
            if let pagingHeaderView = pagingHeaderContainerView.subviews.first {
                scrollView.addSubview(pagingHeaderView)
            }
            scrollView.contentSize = CGSize(width: bounds.size.width, height: pagingHeaderHeight)
        } else {
            fallbackScrollView?.removeFromSuperview()
            fallbackScrollView = nil
        }
    }

    private func synchronizeHeaderWithCurrentList(_ scrollView: UIScrollView, contentOffsetY: CGFloat) {
        isSynchronizingListContentOffset = true
        currentPagingHeaderContainerOriginY = -contentOffsetY
        synchronizeSiblingLists(to: scrollView.contentOffset)
        if let headerView = listHeader(for: scrollView), pagingHeaderContainerView.superview != headerView {
            pagingHeaderContainerView.frame.origin.y = 0
            headerView.addSubview(pagingHeaderContainerView)
        }
    }

    private func pinHeaderToTopIfNeeded() {
        if pagingHeaderContainerView.superview != self {
            pagingHeaderContainerView.frame.origin.y = -pagingHeaderHeight
            addSubview(pagingHeaderContainerView)
        }
    }

    private func synchronizeSiblingListsAfterHeaderPinnedIfNeeded() {
        guard isSynchronizingListContentOffset else {
            return
        }
        isSynchronizingListContentOffset = false
        currentPagingHeaderContainerOriginY = -pagingHeaderHeight
        synchronizeSiblingLists(to: CGPoint(x: 0, y: -pinHeaderHeight))
    }

    private func synchronizeSiblingLists(to contentOffset: CGPoint) {
        for list in listDict.values where list.listScrollView() !== currentListScrollView {
            list.listScrollView().setContentOffset(contentOffset, animated: false)
        }
    }

    private func ensureMinimumContentSize(for scrollView: UIScrollView) {
        let minimumContentHeight = bounds.size.height - pinHeaderHeight
        guard minimumContentHeight > scrollView.contentSize.height else {
            return
        }
        scrollView.contentSize = CGSize(width: scrollView.contentSize.width, height: minimumContentHeight)
        if let currentListScrollView, scrollView != currentListScrollView {
            scrollView.contentOffset = CGPoint(x: 0, y: initialContentOffsetYForNewList)
        }
    }

    private func isValidListIndex(_ index: Int) -> Bool {
        guard let dataSource = dataSource else { return false }
        let count = dataSource.numberOfLists(in: self)
        return count > 0 && index >= 0 && index < count
    }

    private func contentOffsetForList(at index: Int) -> CGPoint {
        CGPoint(x: listCollectionView.bounds.size.width * CGFloat(index), y: 0)
    }

    private func updateScrollsToTopTarget(using scrollView: UIScrollView) {
        listDict.values.forEach { $0.listScrollView().scrollsToTop = ($0.listScrollView() === scrollView) }
    }

    private func configuredList(for index: Int, using dataSource: MahaPagingSmoothViewDataSource) -> MahaPagingSmoothViewListViewDelegate {
        if let existingList = listDict[index] {
            return existingList
        }

        let list = dataSource.pagingView(self, initListAtIndex: index)
        listDict[index] = list
        prepareListViewForDisplay(list, at: index)
        return list
    }

    private func prepareListViewForDisplay(_ list: MahaPagingSmoothViewListViewDelegate, at index: Int) {
        let listView = list.listView()
        listView.setNeedsLayout()
        listView.layoutIfNeeded()

        let listScrollView = list.listScrollView()
        if listScrollView.isKind(of: UITableView.self) {
            let tableView = listScrollView as? UITableView
            tableView?.estimatedRowHeight = 0
            tableView?.estimatedSectionHeaderHeight = 0
            tableView?.estimatedSectionFooterHeight = 0
        }
        if #available(iOS 11.0, *) {
            listScrollView.contentInsetAdjustmentBehavior = .never
        }
        listScrollView.contentInset = UIEdgeInsets(top: pagingHeaderContainerHeight, left: 0, bottom: 0, right: 0)
        initialContentOffsetYForNewList = -pagingHeaderContainerHeight + min(-currentPagingHeaderContainerOriginY, pagingHeaderHeight)
        listScrollView.contentOffset = CGPoint(x: 0, y: initialContentOffsetYForNewList)

        let headerView = UIView(
            frame: CGRect(
                x: 0,
                y: -pagingHeaderContainerHeight,
                width: bounds.size.width,
                height: pagingHeaderContainerHeight
            )
        )
        listScrollView.addSubview(headerView)
        if pagingHeaderContainerView.superview == nil {
            headerView.addSubview(pagingHeaderContainerView)
        }
        listHeaderViewsByIndex[index] = headerView
        listScrollView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
        listScrollView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }

    private func attachListViewIfNeeded(_ list: MahaPagingSmoothViewListViewDelegate, to cell: UICollectionViewCell) {
        let listView = list.listView()
        if listView.superview != cell.contentView {
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            listView.frame = cell.contentView.bounds
            cell.contentView.addSubview(listView)
        }
    }

    private func isAlignedToPage(_ indexPercent: CGFloat, index: Int) -> Bool {
        indexPercent - CGFloat(index) == 0
    }

    private func shouldFinishHorizontalScroll(at index: Int, scrollView: UIScrollView) -> Bool {
        guard index != currentIndex,
              !(scrollView.isDragging || scrollView.isDecelerating),
              let listScrollView = listDict[index]?.listScrollView() else {
            return false
        }
        return listScrollView.contentOffset.y <= -pinHeaderHeight
    }

    private func presentFloatingHeaderDuringHorizontalScrollIfNeeded() {
        if pagingHeaderContainerView.superview != self {
            pagingHeaderContainerView.frame.origin.y = currentPagingHeaderContainerOriginY
            addSubview(pagingHeaderContainerView)
        }
    }
}

extension MahaPagingSmoothView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return bounds.size
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let dataSource = dataSource else { return 0 }
        return dataSource.numberOfLists(in: self)
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let dataSource = dataSource else { return UICollectionViewCell(frame: CGRect.zero) }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: collectionViewCellReuseIdentifier, for: indexPath)
        let list = configuredList(for: indexPath.item, using: dataSource)
        listDict.values.forEach { $0.listScrollView().scrollsToTop = ($0 === list) }
        attachListViewIfNeeded(list, to: cell)
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        listDidAppear(at: indexPath.item)
    }

    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        listDidDisappear(at: indexPath.item)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        delegate?.pagingSmoothViewDidScroll?(scrollView)
        let indexPercent = scrollView.contentOffset.x / scrollView.bounds.size.width
        let index = Int(scrollView.contentOffset.x / scrollView.bounds.size.width)
        if isAlignedToPage(indexPercent, index: index) && shouldFinishHorizontalScroll(at: index, scrollView: scrollView) {
            horizontalScrollDidEnd(at: index)
        } else {
            presentFloatingHeaderDuringHorizontalScrollIfNeeded()
        }
        if index != currentIndex {
            currentIndex = index
        }
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            let index = Int(scrollView.contentOffset.x / scrollView.bounds.size.width)
            horizontalScrollDidEnd(at: index)
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let index = Int(scrollView.contentOffset.x / scrollView.bounds.size.width)
        horizontalScrollDidEnd(at: index)
    }
}

public class MahaPagingSmoothCollectionView: UICollectionView, UIGestureRecognizerDelegate {
    private var pagingHeaderContainerView: UIView?

    func bindPagingHeaderContainerView(_ pagingHeaderContainerView: UIView) {
        self.pagingHeaderContainerView = pagingHeaderContainerView
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let touchPoint = touch.location(in: pagingHeaderContainerView)
        if pagingHeaderContainerView?.bounds.contains(touchPoint) == true {
            return false
        }
        return true
    }
}
