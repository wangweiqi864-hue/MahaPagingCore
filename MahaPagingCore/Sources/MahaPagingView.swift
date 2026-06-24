//
//  MahaPagingView.swift
//  MahaPagingView
//
//  Created by jiaxin on 2018/5/22.
//  Copyright © 2018年 jiaxin. All rights reserved.
//

import UIKit

public protocol MahaPagingViewDelegate: NSObjectProtocol {
    /// tableHeaderView的高度，因为内部需要比对判断，只能是整型数
    func tableHeaderViewHeight(in pagingView: MahaPagingView) -> Int
    /// 返回tableHeaderView
    func tableHeaderView(in pagingView: MahaPagingView) -> UIView
    /// 返回悬浮HeaderView的高度，因为内部需要比对判断，只能是整型数
    func heightForPinSectionHeader(in pagingView: MahaPagingView) -> Int
    /// 返回悬浮HeaderView
    func viewForPinSectionHeader(in pagingView: MahaPagingView) -> UIView
    /// 返回列表的数量
    func numberOfLists(in pagingView: MahaPagingView) -> Int
    /// 根据index初始化一个对应列表实例，需要是遵从`MahaPagingViewListViewDelegate`协议的对象。
    /// 如果列表是用自定义UIView封装的，就让自定义UIView遵从`MahaPagingViewListViewDelegate`协议，该方法返回自定义UIView即可。
    /// 如果列表是用自定义UIViewController封装的，就让自定义UIViewController遵从`MahaPagingViewListViewDelegate`协议，该方法返回自定义UIViewController即可。
    ///
    /// - Parameters:
    ///   - pagingView: pagingView description
    ///   - index: 新生成的列表实例
    func pagingView(_ pagingView: MahaPagingView, initListAtIndex index: Int) -> MahaPagingViewListViewDelegate


    /// 返回对应index的列表唯一标识
    /// - Parameters:
    ///   - pagingView: pagingView description
    ///   - index: 列表的下标
    func pagingView(_ pagingView: MahaPagingView, listIdentifierAtIndex index: Int) -> String?

    /// 将要被弃用！请使用pagingView(_ pagingView: MahaPagingView, mainTableViewDidScroll scrollView: UIScrollView) 方法作为替代。
    @available(*, message: "Use pagingView(_ pagingView: MahaPagingView, mainTableViewDidScroll scrollView: UIScrollView) method")
    func mainTableViewDidScroll(_ scrollView: UIScrollView)
    func pagingView(_ pagingView: MahaPagingView, mainTableViewDidScroll scrollView: UIScrollView)
    func pagingView(_ pagingView: MahaPagingView, mainTableViewWillBeginDragging scrollView: UIScrollView)
    func pagingView(_ pagingView: MahaPagingView, mainTableViewDidEndDragging scrollView: UIScrollView, willDecelerate decelerate: Bool)
    func pagingView(_ pagingView: MahaPagingView, mainTableViewDidEndDecelerating scrollView: UIScrollView)
    func pagingView(_ pagingView: MahaPagingView, mainTableViewDidEndScrollingAnimation scrollView: UIScrollView)


    /// 返回自定义UIScrollView或UICollectionView的Class
    /// 某些特殊情况需要自己处理列表容器内UIScrollView内部逻辑。比如项目用了FDFullscreenPopGesture，需要处理手势相关代理。
    ///
    /// - Parameter pagingView: MahaPagingView
    /// - Returns: 自定义UIScrollView实例
    func scrollViewClassInListContainerView(in pagingView: MahaPagingView) -> AnyClass?
}

public extension MahaPagingViewDelegate {
    func pagingView(_ pagingView: MahaPagingView, listIdentifierAtIndex index: Int) -> String? { nil }

    func mainTableViewDidScroll(_ scrollView: UIScrollView) {}
    func pagingView(_ pagingView: MahaPagingView, mainTableViewDidScroll scrollView: UIScrollView) {}
    func pagingView(_ pagingView: MahaPagingView, mainTableViewWillBeginDragging scrollView: UIScrollView) {}
    func pagingView(_ pagingView: MahaPagingView, mainTableViewDidEndDragging scrollView: UIScrollView, willDecelerate decelerate: Bool) {}
    func pagingView(_ pagingView: MahaPagingView, mainTableViewDidEndDecelerating scrollView: UIScrollView) {}
    func pagingView(_ pagingView: MahaPagingView, mainTableViewDidEndScrollingAnimation scrollView: UIScrollView) {}


    /// 返回自定义UIScrollView或UICollectionView的Class
    /// 某些特殊情况需要自己处理列表容器内UIScrollView内部逻辑。比如项目用了FDFullscreenPopGesture，需要处理手势相关代理。
    ///
    /// - Parameter pagingView: MahaPagingView
    /// - Returns: 自定义UIScrollView实例
    func scrollViewClassInListContainerView(in pagingView: MahaPagingView) -> AnyClass? { nil }
}

open class MahaPagingView: UIView {
    /// 需要和categoryView.defaultSelectedIndex保持一致
    public var defaultSelectedIndex: Int = 0 {
        didSet {
            listContainerView.defaultSelectedIndex = defaultSelectedIndex
        }
    }
    public private(set) lazy var mainTableView: MahaPagingMainTableView = MahaPagingMainTableView(frame: CGRect.zero, style: .plain)
    public private(set) lazy var listContainerView: MahaPagingListContainerView = MahaPagingListContainerView(dataSource: self, type: listContainerType)
    /// 当前已经加载过可用的列表字典，key就是index值，value是对应的列表。
    public private(set) var validListDict = [Int:MahaPagingViewListViewDelegate]()
    /// 顶部固定sectionHeader的垂直偏移量。数值越大越往下沉。
    public var pinSectionHeaderVerticalOffset: Int = 0
    /// 切换页面时是否回到y offset 是否重设为0 回到顶部
    public var scrollToTopWhenChangedPage: Bool = false
    
    public var isListHorizontalScrollEnabled = true {
        didSet {
            listContainerView.scrollView.isScrollEnabled = isListHorizontalScrollEnabled
        }
    }
    /// 是否允许当前列表自动显示或隐藏列表是垂直滚动指示器。true：悬浮的headerView滚动到顶部开始滚动列表时，就会显示，反之隐藏。false：内部不会处理列表的垂直滚动指示器。默认为：true。
    public var automaticallyDisplayListVerticalScrollIndicator = true
    /// 当allowsCacheList为true时，请务必实现代理方法`func pagingView(_ pagingView: MahaPagingView, listIdentifierAtIndex index: Int) -> String`
    public var allowsCacheList: Bool = false
    public private(set) var currentScrollingListView: UIScrollView?
    internal var currentList: MahaPagingViewListViewDelegate?
    private weak var pagingDelegate: MahaPagingViewDelegate?
    private var headerContainerView: UIView!
    private let tableViewCellReuseIdentifier = "cell"
    private let listContainerType: MahaPagingListContainerType
    private var cachedListsByIdentifier = [String:MahaPagingViewListViewDelegate]()

    public init(delegate: MahaPagingViewDelegate, listContainerType: MahaPagingListContainerType = .collectionView) {
        pagingDelegate = delegate
        self.listContainerType = listContainerType
        super.init(frame: CGRect.zero)

        listContainerView.delegate = self
        configureMainTableView()
        rebuildTableHeaderView()
        addSubview(mainTableView)
    }

    @available(*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        updateMainTableViewFrameIfNeeded()
    }

    open func reloadData() {
        resetLoadedState()
        restoreCachedListsIfNeeded()
        rebuildTableHeaderView()
        resetMainTableViewContentOffsetIfNeeded()
        mainTableView.reloadData()
        listContainerView.reloadData()
    }

    open func resizeTableHeaderViewHeight(animatable: Bool = false, duration: TimeInterval = 0.25, curve: UIView.AnimationCurve = .linear) {
        guard let pagingDelegate = pagingDelegate else { return }
        let targetHeight = CGFloat(pagingDelegate.tableHeaderViewHeight(in: self))
        if animatable {
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: animationOptions(for: curve),
                animations: {
                    self.setHeaderContainerHeight(to: targetHeight)
                    self.mainTableView.setNeedsLayout()
                    self.mainTableView.layoutIfNeeded()
                }
            )
        } else {
            setHeaderContainerHeight(to: targetHeight)
        }
    }

    open func preferredProcessListViewDidScroll(scrollView: UIScrollView) {
        if mainTableView.contentOffset.y < maximumMainTableViewContentOffsetY() {
            currentList?.listScrollViewWillResetContentOffset()
            resetListScrollViewToMinimumContentOffset(scrollView)
            updateListVerticalScrollIndicatorIfNeeded(for: scrollView, isVisible: false)
        } else {
            lockMainTableViewAtMaximumContentOffset()
            updateListVerticalScrollIndicatorIfNeeded(for: scrollView, isVisible: true)
        }
    }

    open func preferredProcessMainTableViewDidScroll(_ scrollView: UIScrollView) {
        guard let activeListScrollView = currentScrollingListView else { return }
        if isListScrollingBeyondMinimumOffset(activeListScrollView) {
            lockMainTableViewAtMaximumContentOffset()
        }

        if mainTableView.contentOffset.y < maximumMainTableViewContentOffsetY() {
            resetAllListScrollViewsToMinimumContentOffset()
        }

        if scrollView.contentOffset.y > maximumMainTableViewContentOffsetY(),
           activeListScrollView.contentOffset.y == minimumContentOffsetY(for: activeListScrollView) {
            lockMainTableViewAtMaximumContentOffset()
        }
    }

    //MARK: - Internal

    func updateMainTableViewContentInsetIfNeeded(to inset: UIEdgeInsets) {
        guard mainTableView.contentInset != inset else {
            return
        }
        mainTableView.delegate = nil
        mainTableView.contentInset = inset
        mainTableView.delegate = self
    }

    func canResetMainTableViewContentInsetToZero(for scrollView: UIScrollView) -> Bool {
        !(scrollView.contentInset.top != 0 && scrollView.contentInset.top != CGFloat(pinSectionHeaderVerticalOffset))
    }

    func maximumMainTableViewContentOffsetY() -> CGFloat {
        guard let pagingDelegate = pagingDelegate else { return 0 }
        return CGFloat(pagingDelegate.tableHeaderViewHeight(in: self)) - CGFloat(pinSectionHeaderVerticalOffset)
    }

    func lockMainTableViewAtMaximumContentOffset() {
        mainTableView.contentOffset = CGPoint(x: 0, y: maximumMainTableViewContentOffsetY())
    }

    func minimumContentOffsetY(for listScrollView: UIScrollView) -> CGFloat {
        if #available(iOS 11.0, *) {
            return -listScrollView.adjustedContentInset.top
        }
        return -listScrollView.contentInset.top
    }

    func resetListScrollViewToMinimumContentOffset(_ listScrollView: UIScrollView) {
        listScrollView.contentOffset = CGPoint(x: listScrollView.contentOffset.x, y: minimumContentOffsetY(for: listScrollView))
    }

    func isCurrentListScrollingBeyondMinimumOffset() -> Bool {
        guard let activeListScrollView = currentScrollingListView else {
            return false
        }
        return isListScrollingBeyondMinimumOffset(activeListScrollView)
    }

    func pinnedSectionHeaderHeight() -> CGFloat {
        guard let pagingDelegate = pagingDelegate else { return 0 }
        return CGFloat(pagingDelegate.heightForPinSectionHeader(in: self))
    }

    func handleListDidScroll(_ listScrollView: UIScrollView) {
        currentScrollingListView = listScrollView
        preferredProcessListViewDidScroll(scrollView: listScrollView)
    }

    //MARK: - Private

    private func configureMainTableView() {
        mainTableView.showsVerticalScrollIndicator = false
        mainTableView.showsHorizontalScrollIndicator = false
        mainTableView.separatorStyle = .none
        mainTableView.dataSource = self
        mainTableView.delegate = self
        mainTableView.scrollsToTop = false
        mainTableView.register(UITableViewCell.self, forCellReuseIdentifier: tableViewCellReuseIdentifier)
        if #available(iOS 11.0, *) {
            mainTableView.contentInsetAdjustmentBehavior = .never
        }
        #if compiler(>=5.5)
        if #available(iOS 15.0, *) {
            mainTableView.sectionHeaderTopPadding = 0
        }
        #endif
    }

    private func updateMainTableViewFrameIfNeeded() {
        guard mainTableView.frame != bounds else {
            return
        }
        mainTableView.frame = bounds
        mainTableView.reloadData()
    }

    private func resetLoadedState() {
        currentList = nil
        currentScrollingListView = nil
        validListDict.removeAll()
    }

    private func restoreCachedListsIfNeeded() {
        guard allowsCacheList, let listCount = pagingDelegate?.numberOfLists(in: self) else {
            return
        }

        var latestIndicesByIdentifier = [String: Int]()
        for index in 0..<listCount {
            guard let identifier = pagingDelegate?.pagingView(self, listIdentifierAtIndex: index) else {
                continue
            }
            latestIndicesByIdentifier[identifier] = index
        }

        for identifier in Array(cachedListsByIdentifier.keys) {
            if let index = latestIndicesByIdentifier[identifier], let cachedList = cachedListsByIdentifier[identifier] {
                validListDict[index] = cachedList
            } else {
                cachedListsByIdentifier.removeValue(forKey: identifier)
            }
        }
    }

    private func resetMainTableViewContentOffsetIfNeeded() {
        if pinSectionHeaderVerticalOffset != 0 && mainTableView.contentOffset.y > CGFloat(pinSectionHeaderVerticalOffset) {
            mainTableView.contentOffset = .zero
        }
    }

    private func rebuildTableHeaderView() {
        guard let pagingDelegate = pagingDelegate else { return }
        let tableHeaderView = pagingDelegate.tableHeaderView(in: self)
        let containerView = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: 0,
                height: CGFloat(pagingDelegate.tableHeaderViewHeight(in: self))
            )
        )
        containerView.addSubview(tableHeaderView)
        tableHeaderView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableHeaderView.topAnchor.constraint(equalTo: containerView.topAnchor),
            tableHeaderView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableHeaderView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            tableHeaderView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        headerContainerView = containerView
        mainTableView.tableHeaderView = containerView
    }

    private func animationOptions(for curve: UIView.AnimationCurve) -> UIView.AnimationOptions {
        switch curve {
        case .easeIn:
            return .curveEaseIn
        case .easeOut:
            return .curveEaseOut
        case .easeInOut:
            return .curveEaseInOut
        default:
            return .curveLinear
        }
    }

    private func setHeaderContainerHeight(to height: CGFloat) {
        var headerBounds = headerContainerView.bounds
        headerBounds.size.height = height
        headerContainerView.frame = headerBounds
        mainTableView.tableHeaderView = headerContainerView
    }

    private func updateListVerticalScrollIndicatorIfNeeded(for listScrollView: UIScrollView, isVisible: Bool) {
        guard automaticallyDisplayListVerticalScrollIndicator else {
            return
        }
        listScrollView.showsVerticalScrollIndicator = isVisible
    }

    private func isListScrollingBeyondMinimumOffset(_ listScrollView: UIScrollView) -> Bool {
        listScrollView.contentOffset.y > minimumContentOffsetY(for: listScrollView)
    }

    private func resetAllListScrollViewsToMinimumContentOffset() {
        for list in validListDict.values {
            list.listScrollViewWillResetContentOffset()
            resetListScrollViewToMinimumContentOffset(list.listScrollView())
        }
    }
}

//MARK: - UITableViewDataSource, UITableViewDelegate
extension MahaPagingView: UITableViewDataSource, UITableViewDelegate {
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return max(bounds.height - pinnedSectionHeaderHeight() - CGFloat(pinSectionHeaderVerticalOffset), 0)
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: tableViewCellReuseIdentifier, for: indexPath)
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor.clear
        if listContainerView.superview != cell.contentView {
            cell.contentView.addSubview(listContainerView)
        }
        if listContainerView.frame != cell.bounds {
            listContainerView.frame = cell.bounds
        }
        return cell
    }

    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return pinnedSectionHeaderHeight()
    }

    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let pagingDelegate = pagingDelegate else { return nil }
        return pagingDelegate.viewForPinSectionHeader(in: self)
    }

    //加上footer之后，下滑滚动就变得丝般顺滑了
    open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }

    open func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView(frame: CGRect.zero)
        footerView.backgroundColor = UIColor.clear
        return footerView
    }

    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if pinSectionHeaderVerticalOffset != 0 {
            if !isCurrentListScrollingBeyondMinimumOffset() {
                if scrollView.contentOffset.y >= CGFloat(pinSectionHeaderVerticalOffset) {
                    updateMainTableViewContentInsetIfNeeded(
                        to: UIEdgeInsets(top: CGFloat(pinSectionHeaderVerticalOffset), left: 0, bottom: 0, right: 0)
                    )
                } else if canResetMainTableViewContentInsetToZero(for: scrollView) {
                    updateMainTableViewContentInsetIfNeeded(to: .zero)
                }
            }
        }
        preferredProcessMainTableViewDidScroll(scrollView)
        pagingDelegate?.mainTableViewDidScroll(scrollView)
        pagingDelegate?.pagingView(self, mainTableViewDidScroll: scrollView)
    }

    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        //用户正在上下滚动的时候，就不允许左右滚动
        listContainerView.scrollView.isScrollEnabled = false
        pagingDelegate?.pagingView(self, mainTableViewWillBeginDragging: scrollView)
    }

    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if isListHorizontalScrollEnabled && !decelerate {
            listContainerView.scrollView.isScrollEnabled = true
        }
        pagingDelegate?.pagingView(self, mainTableViewDidEndDragging: scrollView, willDecelerate: decelerate)
    }

    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if isListHorizontalScrollEnabled {
            listContainerView.scrollView.isScrollEnabled = true
        }
        if canResetMainTableViewContentInsetToZero(for: scrollView),
           mainTableView.contentInset.top != 0,
           pinSectionHeaderVerticalOffset != 0 {
            updateMainTableViewContentInsetIfNeeded(to: .zero)
        }
        pagingDelegate?.pagingView(self, mainTableViewDidEndDecelerating: scrollView)
    }

    open func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if isListHorizontalScrollEnabled {
            listContainerView.scrollView.isScrollEnabled = true
        }
        pagingDelegate?.pagingView(self, mainTableViewDidEndScrollingAnimation: scrollView)
    }
}

extension MahaPagingView: MahaPagingListContainerViewDataSource {
    public func numberOfLists(in listContainerView: MahaPagingListContainerView) -> Int {
        guard let pagingDelegate = pagingDelegate else { return 0 }
        return pagingDelegate.numberOfLists(in: self)
    }

    public func listContainerView(_ listContainerView: MahaPagingListContainerView, initListAt index: Int) -> MahaPagingViewListViewDelegate {
        guard let pagingDelegate = pagingDelegate else { fatalError("MahaPagingView delegate must not be nil") }

        if let cachedList = validListDict[index] {
            return cachedList
        }

        if allowsCacheList,
           let listIdentifier = pagingDelegate.pagingView(self, listIdentifierAtIndex: index),
           let cachedList = cachedListsByIdentifier[listIdentifier] {
            validListDict[index] = cachedList
            return cachedList
        }

        let list = pagingDelegate.pagingView(self, initListAtIndex: index)
        list.listViewDidScrollCallback { [weak self, weak list] scrollView in
            self?.currentList = list
            self?.handleListDidScroll(scrollView)
        }
        validListDict[index] = list

        if allowsCacheList, let listIdentifier = pagingDelegate.pagingView(self, listIdentifierAtIndex: index) {
            cachedListsByIdentifier[listIdentifier] = list
        }

        return list
    }

    public func scrollViewClass(in listContainerView: MahaPagingListContainerView) -> AnyClass? {
        return pagingDelegate?.scrollViewClassInListContainerView(in: self)
    }
}

extension MahaPagingView: MahaPagingListContainerViewDelegate {
    public func listContainerViewWillBeginDragging(_ listContainerView: MahaPagingListContainerView) {
        mainTableView.isScrollEnabled = false
    }

    public func listContainerViewDidEndScrolling(_ listContainerView: MahaPagingListContainerView) {
        mainTableView.isScrollEnabled = true
    }

    public func listContainerView(_ listContainerView: MahaPagingListContainerView, listDidAppearAt index: Int) {
        currentScrollingListView = validListDict[index]?.listScrollView()
        if scrollToTopWhenChangedPage {
            for listItem in validListDict.values {
                listItem.listScrollView().scrollsToTop = (listItem === validListDict[index])
            }
        }
    }
}
