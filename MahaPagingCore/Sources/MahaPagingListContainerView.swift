//
//  MahaPagingListContainerView.swift
//  MahaPagingCore
//
//  Created by jiaxin on 2018/12/26.
//  Copyright © 2018 jiaxin. All rights reserved.
//

import UIKit

/// 列表容器视图的类型
///- ScrollView: UIScrollView。优势：没有其他副作用。劣势：实时的视图内存占用相对大一点，因为所有加载之后的列表视图都在视图层级里面。
/// - CollectionView: 使用UICollectionView。优势：因为列表被添加到cell上，实时的视图内存占用更少，适合内存要求特别高的场景。劣势：因为cell重用机制的问题，导致列表被移除屏幕外之后，会被放入缓存区，而不存在于视图层级中。如果刚好你的列表使用了下拉刷新视图，在快速切换过程中，就会导致下拉刷新回调不成功的问题。一句话概括：使用CollectionView的时候，就不要让列表使用下拉刷新加载。
public enum MahaPagingListContainerType {
    case scrollView
    case collectionView
}

public protocol MahaPagingViewListViewDelegate: NSObjectProtocol {
    /// 如果列表是VC，就返回VC.view
    /// 如果列表是View，就返回View自己
    ///
    /// - Returns: 返回列表视图
    func listView() -> UIView
    /// 返回listView内部持有的UIScrollView或UITableView或UICollectionView
    /// 主要用于mainTableView已经显示了header，listView的contentOffset需要重置时，内部需要访问到外部传入进来的listView内的scrollView
    ///
    /// - Returns: listView内部持有的UIScrollView或UITableView或UICollectionView
    func listScrollView() -> UIScrollView
    /// 当listView内部持有的UIScrollView或UITableView或UICollectionView的代理方法`scrollViewDidScroll`回调时，需要调用该代理方法传入的callback
    ///
    /// - Parameter callback: `scrollViewDidScroll`回调时调用的callback
    func listViewDidScrollCallback(callback: @escaping (UIScrollView)->())

    /// 将要重置listScrollView的contentOffset
    func listScrollViewWillResetContentOffset()
    /// 可选实现，列表将要显示的时候调用
    func listWillAppear()
    /// 可选实现，列表显示的时候调用
    func listDidAppear()
    /// 可选实现，列表将要消失的时候调用
    func listWillDisappear()
    /// 可选实现，列表消失的时候调用
    func listDidDisappear()
}

public extension MahaPagingViewListViewDelegate {
    
    func listScrollViewWillResetContentOffset() {}
    func listWillAppear() {}
    func listDidAppear() {}
    func listWillDisappear() {}
    func listDidDisappear() {}
}

public protocol MahaPagingListContainerViewDataSource: NSObjectProtocol {
    /// 返回list的数量
    ///
    /// - Parameter listContainerView: MahaPagingListContainerView
    func numberOfLists(in listContainerView: MahaPagingListContainerView) -> Int

    /// 根据index初始化一个对应列表实例，需要是遵从`MahaPagingViewListViewDelegate`协议的对象。
    /// 如果列表是用自定义UIView封装的，就让自定义UIView遵从`MahaPagingViewListViewDelegate`协议，该方法返回自定义UIView即可。
    /// 如果列表是用自定义UIViewController封装的，就让自定义UIViewController遵从`MahaPagingViewListViewDelegate`协议，该方法返回自定义UIViewController即可。
    /// 注意：一定要是新生成的实例！！！
    ///
    /// - Parameters:
    ///   - listContainerView: MahaPagingListContainerView
    ///   - index: 目标index
    /// - Returns: 遵从MahaPagingViewListViewDelegate协议的实例
    func listContainerView(_ listContainerView: MahaPagingListContainerView, initListAt index: Int) -> MahaPagingViewListViewDelegate


    /// 控制能否初始化对应index的列表。有些业务需求，需要在某些情况才允许初始化某些列表，通过通过该代理实现控制。
    func listContainerView(_ listContainerView: MahaPagingListContainerView, canInitListAt index: Int) -> Bool

    /// 返回自定义UIScrollView或UICollectionView的Class
    /// 某些特殊情况需要自己处理UIScrollView内部逻辑。比如项目用了FDFullscreenPopGesture，需要处理手势相关代理。
    ///
    /// - Parameter listContainerView: MahaPagingListContainerView
    /// - Returns: 自定义UIScrollView实例
    func scrollViewClass(in listContainerView: MahaPagingListContainerView) -> AnyClass?
}

public extension MahaPagingListContainerViewDataSource {
    func listContainerView(_ listContainerView: MahaPagingListContainerView, canInitListAt index: Int) -> Bool { true }
    func scrollViewClass(in listContainerView: MahaPagingListContainerView) -> AnyClass? { nil }
}

protocol MahaPagingListContainerViewDelegate: NSObjectProtocol {
    func listContainerViewDidScroll(_ listContainerView: MahaPagingListContainerView)
    func listContainerViewWillBeginDragging(_ listContainerView: MahaPagingListContainerView)
    func listContainerViewDidEndScrolling(_ listContainerView: MahaPagingListContainerView)
    func listContainerView(_ listContainerView: MahaPagingListContainerView, listDidAppearAt index: Int)
}

extension MahaPagingListContainerViewDelegate {
    
    func listContainerViewDidScroll(_ listContainerView: MahaPagingListContainerView) {}
    func listContainerViewWillBeginDragging(_ listContainerView: MahaPagingListContainerView) {}
    func listContainerViewDidEndScrolling(_ listContainerView: MahaPagingListContainerView) {}
    func listContainerView(_ listContainerView: MahaPagingListContainerView, listDidAppearAt index: Int) {}
}

open class MahaPagingListContainerView: UIView {
    public private(set) var type: MahaPagingListContainerType
    public private(set) weak var dataSource: MahaPagingListContainerViewDataSource?
    public private(set) var scrollView: UIScrollView!
    public var isCategoryNestPagingEnabled = false {
        didSet {
            if let containerScrollView = scrollView as? MahaPagingListContainerScrollView {
                containerScrollView.isCategoryNestPagingEnabled = isCategoryNestPagingEnabled
            }else if let containerScrollView = scrollView as? MahaPagingListContainerCollectionView {
                containerScrollView.isCategoryNestPagingEnabled = isCategoryNestPagingEnabled
            }
        }
    }
    /// 已经加载过的列表字典。key是index，value是对应的列表
    open var validListDict = [Int:MahaPagingViewListViewDelegate]()
    /// 滚动切换的时候，滚动距离超过一页的多少百分比，就触发列表的初始化。默认0.01（即列表显示了一点就触发加载）。范围0~1，开区间不包括0和1
    open var initListPercent: CGFloat = 0.01 {
        didSet {
            if initListPercent <= 0 || initListPercent >= 1 {
                assertionFailure("initListPercent值范围为开区间(0,1)，即不包括0和1")
            }
        }
    }
    public var listCellBackgroundColor: UIColor = .white
    /// 需要和segmentedView.defaultSelectedIndex保持一致，用于触发默认index列表的加载
    public var defaultSelectedIndex: Int = 0 {
        didSet {
            currentIndex = defaultSelectedIndex
        }
    }
    weak var delegate: MahaPagingListContainerViewDelegate?
    public private(set) var currentIndex: Int = 0
    private var listCollectionView: UICollectionView!
    private var containerViewController: MahaPagingListContainerViewController!
    private var pendingAppearIndex: Int = -1
    private var pendingDisappearIndex: Int = -1
    private let collectionViewCellReuseIdentifier = "cell"

    public init(dataSource: MahaPagingListContainerViewDataSource, type: MahaPagingListContainerType = .collectionView) {
        self.dataSource = dataSource
        self.type = type
        super.init(frame: CGRect.zero)

        configureViewHierarchy()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func commonInit() {
        configureViewHierarchy()
    }

    private func configureViewHierarchy() {
        guard let dataSource = dataSource else { return }
        configureContainerViewController()
        if type == .scrollView {
            configurePagingScrollView(using: dataSource)
        } else if type == .collectionView {
            configurePagingCollectionView(using: dataSource)
        }
    }

    private func configureContainerViewController() {
        containerViewController = MahaPagingListContainerViewController()
        containerViewController.view.backgroundColor = .clear
        addSubview(containerViewController.view)
        containerViewController.viewWillAppearClosure = { [weak self] in
            self?.listWillAppear(at: self?.currentIndex ?? 0)
        }
        containerViewController.viewDidAppearClosure = { [weak self] in
            self?.listDidAppear(at: self?.currentIndex ?? 0)
        }
        containerViewController.viewWillDisappearClosure = { [weak self] in
            self?.listWillDisappear(at: self?.currentIndex ?? 0)
        }
        containerViewController.viewDidDisappearClosure = { [weak self] in
            self?.listDidDisappear(at: self?.currentIndex ?? 0)
        }
    }

    private func configurePagingScrollView(using dataSource: MahaPagingListContainerViewDataSource) {
        if let scrollViewClass = dataSource.scrollViewClass(in: self) as? UIScrollView.Type {
            scrollView = scrollViewClass.init()
        } else {
            scrollView = MahaPagingListContainerScrollView()
        }
        scrollView.backgroundColor = .clear
        scrollView.delegate = self
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.scrollsToTop = false
        scrollView.bounces = false
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        containerViewController.view.addSubview(scrollView)
    }

    private func configurePagingCollectionView(using dataSource: MahaPagingListContainerViewDataSource) {
        let layout = MahaRTLFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        if let collectionViewClass = dataSource.scrollViewClass(in: self) as? UICollectionView.Type {
            listCollectionView = collectionViewClass.init(frame: .zero, collectionViewLayout: layout)
        } else {
            listCollectionView = MahaPagingListContainerCollectionView(frame: .zero, collectionViewLayout: layout)
        }
        listCollectionView.backgroundColor = .clear
        listCollectionView.isPagingEnabled = true
        listCollectionView.showsHorizontalScrollIndicator = false
        listCollectionView.showsVerticalScrollIndicator = false
        listCollectionView.scrollsToTop = false
        listCollectionView.bounces = false
        listCollectionView.dataSource = self
        listCollectionView.delegate = self
        listCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: collectionViewCellReuseIdentifier)
        if #available(iOS 10.0, *) {
            listCollectionView.isPrefetchingEnabled = false
        }
        if #available(iOS 11.0, *) {
            listCollectionView.contentInsetAdjustmentBehavior = .never
        }
        containerViewController.view.addSubview(listCollectionView)
        scrollView = listCollectionView
    }

    open override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        var next: UIResponder? = newSuperview
        while next != nil {
            if let viewController = next as? UIViewController {
                viewController.addChild(containerViewController)
                break
            }
            next = next?.next
        }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        guard let dataSource = dataSource else { return }
        containerViewController.view.frame = bounds
        if type == .scrollView {
            layoutPagingScrollView(using: dataSource)
        } else {
            layoutPagingCollectionView()
        }
    }

    //MARK: - Maha segmented list container bridge

    public func contentScrollView() -> UIScrollView {
        return scrollView
    }

    public func scrolling(from leftIndex: Int, to rightIndex: Int, percent: CGFloat, selectedIndex: Int) {
    }

    public func didClickSelectedItem(at index: Int) {
        guard isIndexValid(index) else {
            return
        }
        resetPendingTransitionIndices()
        if currentIndex != index {
            listWillDisappear(at: currentIndex)
            listWillAppear(at: index)
            listDidDisappear(at: currentIndex)
            listDidAppear(at: index)
        }
    }

    public func reloadData() {
        guard let dataSource = dataSource else { return }
        resetCurrentIndexIfNeeded(listCount: dataSource.numberOfLists(in: self))
        removeAllLoadedLists()
        validListDict.removeAll()
        if type == .scrollView {
            updateScrollViewContentSize(listCount: dataSource.numberOfLists(in: self))
        } else {
            listCollectionView.reloadData()
        }
        listWillAppear(at: currentIndex)
        listDidAppear(at: currentIndex)
    }

    //MARK: - Private
    func initListIfNeeded(at index: Int) {
        guard let list = createListIfNeeded(at: index) else {
            return
        }
        attachListViewIfNeeded(list, at: index)
    }

    private func listWillAppear(at index: Int) {
        guard isIndexValid(index) else {
            return
        }
        guard let list = createListIfNeeded(at: index) else {
            return
        }
        attachListViewIfNeeded(list, at: index)
        list.listWillAppear()
        beginAppearanceTransitionIfNeeded(for: list, appearing: true)
    }

    private func listDidAppear(at index: Int) {
        guard isIndexValid(index) else {
            return
        }
        currentIndex = index
        let list = validListDict[index]
        list?.listDidAppear()
        endAppearanceTransitionIfNeeded(for: list)
        delegate?.listContainerView(self, listDidAppearAt: index)
    }

    private func listWillDisappear(at index: Int) {
        guard isIndexValid(index) else {
            return
        }
        let list = validListDict[index]
        list?.listWillDisappear()
        beginAppearanceTransitionIfNeeded(for: list, appearing: false)
    }

    private func listDidDisappear(at index: Int) {
        guard isIndexValid(index) else {
            return
        }
        let list = validListDict[index]
        list?.listDidDisappear()
        endAppearanceTransitionIfNeeded(for: list)
    }

    private func isIndexValid(_ index: Int) -> Bool {
        guard let dataSource = dataSource else { return false }
        let count = dataSource.numberOfLists(in: self)
        if count <= 0 || index < 0 || index >= count {
            return false
        }
        return true
    }

    private func createListIfNeeded(at index: Int) -> MahaPagingViewListViewDelegate? {
        if let existingList = validListDict[index] {
            return existingList
        }
        guard let dataSource = dataSource, dataSource.listContainerView(self, canInitListAt: index) else {
            return nil
        }
        let list = dataSource.listContainerView(self, initListAt: index)
        validListDict[index] = list
        if let viewController = list as? UIViewController {
            containerViewController.addChild(viewController)
        }
        return list
    }

    private func attachListViewIfNeeded(_ list: MahaPagingViewListViewDelegate, at index: Int) {
        switch type {
        case .scrollView:
            let listView = list.listView()
            if listView.superview == nil {
                listView.frame = frameForListView(at: index)
                scrollView.addSubview(listView)
            } else if listView.frame != frameForListView(at: index) {
                listView.frame = frameForListView(at: index)
            }
        case .collectionView:
            guard let cell = listCollectionView.cellForItem(at: IndexPath(item: index, section: 0)) else {
                return
            }
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            let listView = list.listView()
            listView.frame = cell.contentView.bounds
            cell.contentView.addSubview(listView)
        }
    }

    private func layoutPagingScrollView(using dataSource: MahaPagingListContainerViewDataSource) {
        let needsFullLayout = scrollView.frame == .zero || scrollView.bounds.size != bounds.size
        scrollView.frame = bounds
        updateScrollViewContentSize(listCount: dataSource.numberOfLists(in: self))
        guard needsFullLayout else {
            return
        }
        for (index, list) in validListDict {
            list.listView().frame = frameForListView(at: index)
        }
        scrollView.contentOffset = contentOffsetForIndex(currentIndex, in: scrollView)
    }

    private func layoutPagingCollectionView() {
        let needsReload = listCollectionView.frame == .zero || listCollectionView.bounds.size != bounds.size
        listCollectionView.frame = bounds
        guard needsReload else {
            return
        }
        listCollectionView.collectionViewLayout.invalidateLayout()
        listCollectionView.reloadData()
        listCollectionView.setContentOffset(contentOffsetForIndex(currentIndex, in: listCollectionView), animated: false)
    }

    private func updateScrollViewContentSize(listCount: Int) {
        scrollView.contentSize = CGSize(
            width: scrollView.bounds.size.width * CGFloat(listCount),
            height: scrollView.bounds.size.height
        )
    }

    private func frameForListView(at index: Int) -> CGRect {
        return CGRect(
            x: CGFloat(index) * scrollView.bounds.size.width,
            y: 0,
            width: scrollView.bounds.size.width,
            height: scrollView.bounds.size.height
        )
    }

    private func contentOffsetForIndex(_ index: Int, in scrollView: UIScrollView) -> CGPoint {
        return CGPoint(x: CGFloat(index) * scrollView.bounds.size.width, y: 0)
    }

    private func resetCurrentIndexIfNeeded(listCount: Int) {
        guard currentIndex < 0 || currentIndex >= listCount else {
            return
        }
        defaultSelectedIndex = 0
        currentIndex = 0
    }

    private func removeAllLoadedLists() {
        validListDict.values.forEach { list in
            if let listViewController = list as? UIViewController {
                listViewController.removeFromParent()
            }
            list.listView().removeFromSuperview()
        }
    }

    private func resetPendingTransitionIndices() {
        pendingAppearIndex = -1
        pendingDisappearIndex = -1
    }

    private func shouldCompletePendingTransition(at currentIndexPercent: CGFloat) -> Bool {
        guard pendingAppearIndex != -1 || pendingDisappearIndex != -1 else {
            return false
        }
        if pendingAppearIndex > pendingDisappearIndex {
            return currentIndexPercent >= CGFloat(pendingAppearIndex)
        }
        return currentIndexPercent <= CGFloat(pendingAppearIndex)
    }

    private func completePendingTransitionIfNeeded(using scrollView: UIScrollView) {
        let currentIndexPercent = scrollView.contentOffset.x / scrollView.bounds.size.width
        guard shouldCompletePendingTransition(at: currentIndexPercent) else {
            return
        }
        let disappearIndex = pendingDisappearIndex
        let appearIndex = pendingAppearIndex
        resetPendingTransitionIndices()
        listDidDisappear(at: disappearIndex)
        listDidAppear(at: appearIndex)
    }

    private func cancelPendingTransitionIfNeeded() {
        guard pendingAppearIndex != -1 || pendingDisappearIndex != -1 else {
            return
        }
        listWillDisappear(at: pendingAppearIndex)
        listWillAppear(at: pendingDisappearIndex)
        listDidDisappear(at: pendingAppearIndex)
        listDidAppear(at: pendingDisappearIndex)
        resetPendingTransitionIndices()
    }

    private func updatePendingTransition(appearingIndex: Int, disappearingIndex: Int) {
        if pendingAppearIndex == -1 {
            pendingAppearIndex = appearingIndex
            listWillAppear(at: pendingAppearIndex)
        }
        if pendingDisappearIndex == -1 {
            pendingDisappearIndex = disappearingIndex
            listWillDisappear(at: pendingDisappearIndex)
        }
    }

    private func shouldInitializeList(at index: Int, remainderRatio: CGFloat, threshold: CGFloat, movingTowardRight: Bool) -> Bool {
        if validListDict[index] != nil {
            return false
        }
        return movingTowardRight ? remainderRatio > threshold : remainderRatio < (1 - threshold)
    }

    private func beginAppearanceTransitionIfNeeded(for list: MahaPagingViewListViewDelegate?, appearing: Bool) {
        guard let viewController = list as? UIViewController else {
            return
        }
        viewController.beginAppearanceTransition(appearing, animated: false)
    }

    private func endAppearanceTransitionIfNeeded(for list: MahaPagingViewListViewDelegate?) {
        guard let viewController = list as? UIViewController else {
            return
        }
        viewController.endAppearanceTransition()
    }
}

extension MahaPagingListContainerView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let dataSource = dataSource else { return 0 }
        return dataSource.numberOfLists(in: self)
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: collectionViewCellReuseIdentifier, for: indexPath)
        cell.contentView.backgroundColor = listCellBackgroundColor
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        let list = validListDict[indexPath.item]
        if list != nil {
            if list is UIViewController {
                list?.listView().frame = cell.contentView.bounds
            }else {
                list?.listView().frame = cell.bounds
            }
            cell.contentView.addSubview(list!.listView())
        }
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return bounds.size
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        delegate?.listContainerViewDidScroll(self)
        guard scrollView.isTracking || scrollView.isDragging else {
            return
        }
        let percent = scrollView.contentOffset.x / scrollView.bounds.size.width
        let maxCount = Int(round(scrollView.contentSize.width / scrollView.bounds.size.width))
        var leftIndex = Int(floor(Double(percent)))
        leftIndex = max(0, min(maxCount - 1, leftIndex))
        let rightIndex = leftIndex + 1
        if percent < 0 || rightIndex >= maxCount {
            completePendingTransitionIfNeeded(using: scrollView)
            return
        }
        let remainderRatio = percent - CGFloat(leftIndex)
        if rightIndex == currentIndex {
            if shouldInitializeList(at: leftIndex, remainderRatio: remainderRatio, threshold: initListPercent, movingTowardRight: false) {
                initListIfNeeded(at: leftIndex)
            } else if validListDict[leftIndex] != nil {
                updatePendingTransition(appearingIndex: leftIndex, disappearingIndex: rightIndex)
            }
        } else {
            if shouldInitializeList(at: rightIndex, remainderRatio: remainderRatio, threshold: initListPercent, movingTowardRight: true) {
                initListIfNeeded(at: rightIndex)
            } else if validListDict[rightIndex] != nil {
                updatePendingTransition(appearingIndex: rightIndex, disappearingIndex: leftIndex)
            }
        }
        completePendingTransitionIfNeeded(using: scrollView)
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        cancelPendingTransitionIfNeeded()
        delegate?.listContainerViewDidEndScrolling(self)
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.listContainerViewWillBeginDragging(self)
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            delegate?.listContainerViewDidEndScrolling(self)
        }
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        delegate?.listContainerViewDidEndScrolling(self)
    }
}

class MahaPagingListContainerViewController: UIViewController {
    var viewWillAppearClosure: (()->())?
    var viewDidAppearClosure: (()->())?
    var viewWillDisappearClosure: (()->())?
    var viewDidDisappearClosure: (()->())?
    override var shouldAutomaticallyForwardAppearanceMethods: Bool { return false }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillAppearClosure?()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewDidAppearClosure?()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewWillDisappearClosure?()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewDidDisappearClosure?()
    }
}

class MahaPagingListContainerScrollView: UIScrollView, UIGestureRecognizerDelegate {
    var isCategoryNestPagingEnabled = false
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if isCategoryNestPagingEnabled, let panGestureClass = NSClassFromString("UIScrollViewPanGestureRecognizer"), gestureRecognizer.isMember(of: panGestureClass) {
            let panGesture = gestureRecognizer as! UIPanGestureRecognizer
            let velocityX = panGesture.velocity(in: panGesture.view!).x
            if velocityX > 0 {
                //当前在第一个页面，且往左滑动，就放弃该手势响应，让外层接收，达到多个PagingView左右切换效果
                if contentOffset.x == 0 {
                    return false
                }
            }else if velocityX < 0 {
                //当前在最后一个页面，且往右滑动，就放弃该手势响应，让外层接收，达到多个PagingView左右切换效果
                if contentOffset.x + bounds.size.width == contentSize.width {
                    return false
                }
            }
        }
        return true
    }
}
class MahaPagingListContainerCollectionView: UICollectionView, UIGestureRecognizerDelegate {
    var isCategoryNestPagingEnabled = false
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if isCategoryNestPagingEnabled, let panGestureClass = NSClassFromString("UIScrollViewPanGestureRecognizer"), gestureRecognizer.isMember(of: panGestureClass)  {
            let panGesture = gestureRecognizer as! UIPanGestureRecognizer
            let velocityX = panGesture.velocity(in: panGesture.view!).x
            if velocityX > 0 {
                //当前在第一个页面，且往左滑动，就放弃该手势响应，让外层接收，达到多个PagingView左右切换效果
                if contentOffset.x == 0 {
                    return false
                }
            }else if velocityX < 0 {
                //当前在最后一个页面，且往右滑动，就放弃该手势响应，让外层接收，达到多个PagingView左右切换效果
                if contentOffset.x + bounds.size.width == contentSize.width {
                    return false
                }
            }
        }
        return true
    }
}
