import UIKit

/// The article list from the design: header, pull-to-refresh, list / grid
/// layouts, search, and the loading, offline, error and empty states.
final class ArticleListViewController: UIViewController {
    @IBOutlet private var headerView: ArticleListHeaderView!
    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var stateContainer: UIView!

    private let articlesManager: ArticlesManagerProtocol
    private let connectivityManager: ConnectivityManagerProtocol
    private let favoritesManager: FavoritesManagerProtocol
    private weak var router: ArticleRouting?

    private let dataSource = ArticleListDataSource()
    private let refreshControl = UIRefreshControl()
    private lazy var bannerPresenter = BannerPresenter(hostView: view)
    private lazy var stateController = ContentStateViewController(kind: .loading) { [weak self] in
        self?.loadArticles()
    }

    private var articles: [Article] = []
    private var latestResult: ArticlesLoadResult?
    private var searchQuery = ""
    private var layoutMode: ArticleListLayoutMode = .list
    private(set) var currentFilter: ArticleListSectionFilter = .all
    /// Whether the manager can append another page to `articles`.
    private var hasMore = false
    private(set) var isLoadingNextPage = false
    private var nextPageTask: Task<Void, Never>?
    private var currentHasFooter = false
    private var loadTask: Task<Void, Never>?
    private var connectivityObservation: ConnectivityObservation?
    private var savedObserver: NSObjectProtocol?

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    // MARK: - Lifecycle

    init?(
        coder: NSCoder,
        articlesManager: ArticlesManagerProtocol,
        connectivityManager: ConnectivityManagerProtocol,
        favoritesManager: FavoritesManagerProtocol,
        router: ArticleRouting
    ) {
        self.articlesManager = articlesManager
        self.connectivityManager = connectivityManager
        self.favoritesManager = favoritesManager
        self.router = router
        super.init(coder: coder)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use ViewControllerFactory to create ArticleListViewController")
    }

    deinit {
        loadTask?.cancel()
        nextPageTask?.cancel()
        if let savedObserver {
            NotificationCenter.default.removeObserver(savedObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        headerView.delegate = self
        headerView.updateSavedCount(favoritesManager.savedArticles().count)
        embed(stateController, in: stateContainer)
        observeConnectivity()
        observeSavedArticles()
        observeDynamicType()

        // Paint the cached list immediately, then refresh it in the background.
        if let cached = articlesManager.cachedArticles() {
            latestResult = cached
            articles = cached.articles
            hasMore = cached.hasMore
        }
        render()
        loadArticles()
    }

    // MARK: - Setup

    private func configureCollectionView() {
        dataSource.registerCells(in: collectionView)
        dataSource.onReadMore = { [weak self] article in self?.open(article) }
        dataSource.isSaved = { [weak self] article in self?.favoritesManager.isSaved(article) ?? false }
        dataSource.savedImageURL = { [weak self] article in self?.favoritesManager.savedImageURL(for: article) }
        dataSource.onToggleSave = { [weak self] article in self?.favoritesManager.toggleSave(article) }

        collectionView.dataSource = dataSource
        collectionView.delegate = self
        collectionView.collectionViewLayout = ArticleListLayoutFactory.makeLayout(for: layoutMode)

        refreshControl.tintColor = AppColor.accent
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    private func observeSavedArticles() {
        savedObserver = NotificationCenter.default.addObserver(
            forName: AppConstants.SavedArticles.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.headerView.updateSavedCount(self.favoritesManager.savedArticles().count)
            if self.currentFilter == .saved {
                self.render()
            } else {
                self.updateVisibleSavedStates()
            }
        }
    }

    private func updateVisibleSavedStates() {
        guard let collectionView else { return }
        for cell in collectionView.visibleCells {
            if let cardCell = cell as? ArticleCardCell,
               let indexPath = collectionView.indexPath(for: cardCell),
               let article = dataSource.article(at: indexPath) {
                cardCell.updateSavedState(favoritesManager.isSaved(article))
            } else if let gridCell = cell as? ArticleGridCell,
                      let indexPath = collectionView.indexPath(for: gridCell),
                      let article = dataSource.article(at: indexPath) {
                gridCell.updateSavedState(favoritesManager.isSaved(article))
            }
        }
    }

    private func observeConnectivity() {
        connectivityObservation = connectivityManager.observe { [weak self] isOnline in
            self?.connectivityChanged(isOnline: isOnline)
        }
    }

    private func observeDynamicType() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.collectionView.reloadData()
        }
    }

    // MARK: - Loading

    private func cancelNextPage() {
        nextPageTask?.cancel()
        nextPageTask = nil
        isLoadingNextPage = false
        dataSource.isLoadingMore = false
    }

    @objc private func refreshPulled() {
        loadArticles()
    }

    /// Loads the first page afresh; anything loaded before is replaced.
    private func loadArticles() {
        cancelNextPage()
        loadTask?.cancel()
        loadTask = Task { [weak self, articlesManager] in
            let result = await articlesManager.loadArticles()
            guard !Task.isCancelled else { return }
            self?.apply(result)
        }
        // Rendered after the task exists so an empty screen shows "loading"
        // rather than the previous failure while the retry is in flight.
        render()
    }

    private func apply(_ result: ArticlesLoadResult) {
        loadTask = nil
        latestResult = result
        articles = result.articles
        hasMore = result.hasMore
        refreshControl.endRefreshing()
        render()
        reportFailureIfNeeded(of: result)
    }

    /// Asks the manager for the next page once the last loaded card is about
    /// to appear. The manager decides where that page comes from.
    private func loadNextPageIfNeeded() {
        guard currentFilter == .all, hasMore, !isLoadingNextPage, loadTask == nil else { return }
        isLoadingNextPage = true
        dataSource.isLoadingMore = true

        if let footer = collectionView.supplementaryView(
            forElementKind: ArticleListLayoutFactory.footerElementKind,
            at: IndexPath(item: 0, section: 0)
        ) as? LoadingFooterView {
            footer.startAnimating()
        }

        nextPageTask = Task { [weak self, articlesManager] in
            let result = await articlesManager.loadNextPage()
            guard !Task.isCancelled, let self else { return }
            self.nextPageTask = nil
            self.isLoadingNextPage = false
            self.dataSource.isLoadingMore = false
            self.latestResult = result
            self.articles = result.articles
            self.hasMore = result.hasMore
            self.render()
            if result.error != nil {
                self.bannerPresenter.toast(.loadMoreFailed)
            }
        }
    }

    /// When a refresh fails but saved articles are on screen, say so without
    /// taking the content away.
    private func reportFailureIfNeeded(of result: ArticlesLoadResult) {
        guard currentFilter == .all else { return }
        guard let error = result.error, !result.articles.isEmpty else {
            bannerPresenter.unpin()
            return
        }

        if error.isConnectivityIssue || !connectivityManager.isOnline {
            bannerPresenter.pin(.offline(savedAgo: savedAgo(for: result)))
        } else {
            bannerPresenter.toast(.refreshFailed)
        }
    }

    private func savedAgo(for result: ArticlesLoadResult?) -> String? {
        guard case .cache(let savedAt)? = result?.origin else { return nil }
        return ArticleDateFormatter.shortRelativeString(for: savedAt).lowercased()
    }

    // MARK: - Connectivity

    private func connectivityChanged(isOnline: Bool) {
        if isOnline {
            bannerPresenter.unpin()
            bannerPresenter.toast(.backOnline)
            loadArticles()
        } else if currentFilter == .saved {
            // Saved articles remain 100% accessible offline
            render()
        } else if articles.isEmpty {
            render()
        } else {
            bannerPresenter.pin(.offline(savedAgo: savedAgo(for: latestResult)))
        }
    }

    // MARK: - Rendering

    private var totalFilteredArticles: [Article] {
        let baseArticles = currentFilter == .saved ? favoritesManager.savedArticles() : articles
        return ArticleSearchFilter.filter(baseArticles, matching: searchQuery)
    }

    /// The footer spinner only makes sense on the paged feed, not on the
    /// local saved list.
    private var showsLoadMoreFooter: Bool {
        currentFilter == .all && hasMore
    }

    private func render() {
        dataSource.articles = totalFilteredArticles

        let needsFooter = showsLoadMoreFooter
        if needsFooter != currentHasFooter {
            currentHasFooter = needsFooter
            collectionView.setCollectionViewLayout(
                ArticleListLayoutFactory.makeLayout(for: layoutMode, hasFooter: needsFooter),
                animated: false
            )
        }

        collectionView.reloadData()

        if let state = currentState(visibleCount: totalFilteredArticles.count) {
            stateController.show(state)
            setStateVisible(true)
        } else {
            setStateVisible(false)
        }
    }

    /// The full-area state to show instead of the list, or `nil` for content.
    private func currentState(visibleCount: Int) -> ContentStateView.Kind? {
        if currentFilter == .saved {
            let saved = favoritesManager.savedArticles()
            if saved.isEmpty {
                return .emptySaved
            }
            if visibleCount == 0 && !searchQuery.isEmpty {
                return .noResults(query: searchQuery)
            }
            return nil
        }

        guard articles.isEmpty else {
            return visibleCount == 0 ? .noResults(query: searchQuery) : nil
        }
        if loadTask != nil || latestResult == nil {
            return connectivityManager.isOnline ? .loading : .offline
        }
        guard let error = latestResult?.error else {
            return .empty
        }
        if error.isConnectivityIssue || !connectivityManager.isOnline {
            return .offline
        }
        return .error(message: error.userMessage)
    }

    private func setStateVisible(_ visible: Bool) {
        guard stateContainer.isHidden == visible else { return }
        stateContainer.isHidden = false
        collectionView.isHidden = false
        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState]) {
            self.stateContainer.alpha = visible ? 1 : 0
            self.collectionView.alpha = visible ? 0 : 1
        } completion: { _ in
            self.stateContainer.isHidden = !visible
            self.collectionView.isHidden = visible
        }
    }

    // MARK: - Navigation

    private func open(_ article: Article) {
        view.endEditing(true)
        router?.showDetail(for: article) { [weak self] in
            self?.transitionSourceView(for: article)
        }
    }

    /// The image of the card showing `article`, if that card is on screen.
    private func transitionSourceView(for article: Article) -> UIView? {
        guard
            let indexPath = dataSource.indexPath(for: article),
            let cell = collectionView.cellForItem(at: indexPath)
        else {
            return nil
        }
        return (cell as? ArticleCardCell)?.articleImageView ?? (cell as? ArticleGridCell)?.articleImageView
    }
}

// MARK: - UICollectionViewDelegate

extension ArticleListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let article = dataSource.article(at: indexPath) else { return }
        open(article)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        let count = dataSource.articles.count
        guard count > 0, indexPath.item >= count - 1 else { return }
        loadNextPageIfNeeded()
    }
}

// MARK: - ArticleListHeaderViewDelegate

extension ArticleListViewController: ArticleListHeaderViewDelegate {
    func headerViewDidToggleLayout(_ headerView: ArticleListHeaderView) {
        layoutMode.toggle()
        headerView.showsGridLayout = layoutMode == .grid
        dataSource.layoutMode = layoutMode

        UIView.transition(with: collectionView, duration: 0.3, options: .transitionCrossDissolve) {
            self.collectionView.reloadData()
            self.collectionView.setCollectionViewLayout(
                ArticleListLayoutFactory.makeLayout(for: self.layoutMode, hasFooter: self.currentHasFooter),
                animated: false
            )
            self.collectionView.setContentOffset(.zero, animated: false)
        }
    }

    func headerView(_ headerView: ArticleListHeaderView, didChangeSearchText text: String) {
        searchQuery = text
        render()
    }

    func headerViewDidEndSearch(_ headerView: ArticleListHeaderView) {
        searchQuery = ""
        render()
    }

    func headerView(_ headerView: ArticleListHeaderView, didSelectFilter filter: ArticleListSectionFilter) {
        guard currentFilter != filter else { return }
        currentFilter = filter
        refreshControl.isEnabled = (filter == .all)
        if filter == .saved {
            bannerPresenter.unpin()
        } else if !connectivityManager.isOnline && !articles.isEmpty {
            bannerPresenter.pin(.offline(savedAgo: savedAgo(for: latestResult)))
        }
        render()
    }
}
