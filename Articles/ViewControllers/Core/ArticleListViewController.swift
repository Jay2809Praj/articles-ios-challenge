import UIKit

/// The article list from the design: header, pull-to-refresh, list / grid
/// layouts, search, and the loading, offline, error and empty states.
final class ArticleListViewController: UIViewController {
    @IBOutlet private var headerView: ArticleListHeaderView!
    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var stateContainer: UIView!

    private let articlesManager: ArticlesManagerProtocol
    private let connectivityManager: ConnectivityManagerProtocol
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
    private var loadTask: Task<Void, Never>?
    private var connectivityObservation: ConnectivityObservation?

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    // MARK: - Lifecycle

    init?(
        coder: NSCoder,
        articlesManager: ArticlesManagerProtocol,
        connectivityManager: ConnectivityManagerProtocol,
        router: ArticleRouting
    ) {
        self.articlesManager = articlesManager
        self.connectivityManager = connectivityManager
        self.router = router
        super.init(coder: coder)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use ViewControllerFactory to create ArticleListViewController")
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        headerView.delegate = self
        embed(stateController, in: stateContainer)
        observeConnectivity()
        observeDynamicType()

        // Paint the cached list immediately, then refresh it in the background.
        if let cached = articlesManager.cachedArticles() {
            latestResult = cached
            articles = cached.articles
        }
        render()
        loadArticles()
    }

    // MARK: - Setup

    private func configureCollectionView() {
        dataSource.registerCells(in: collectionView)
        dataSource.onReadMore = { [weak self] article in self?.open(article) }

        collectionView.dataSource = dataSource
        collectionView.delegate = self
        collectionView.collectionViewLayout = ArticleListLayoutFactory.makeLayout(for: layoutMode)

        refreshControl.tintColor = AppColor.accent
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        collectionView.refreshControl = refreshControl
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

    @objc private func refreshPulled() {
        loadArticles()
    }

    private func loadArticles() {
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
        refreshControl.endRefreshing()
        render()
        reportFailureIfNeeded(of: result)
    }

    /// When a refresh fails but saved articles are on screen, say so without
    /// taking the content away.
    private func reportFailureIfNeeded(of result: ArticlesLoadResult) {
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
        } else if articles.isEmpty {
            render()
        } else {
            bannerPresenter.pin(.offline(savedAgo: savedAgo(for: latestResult)))
        }
    }

    // MARK: - Rendering

    private var visibleArticles: [Article] {
        ArticleSearchFilter.filter(articles, matching: searchQuery)
    }

    private func render() {
        let visible = visibleArticles
        dataSource.articles = visible
        collectionView.reloadData()

        if let state = currentState(visibleCount: visible.count) {
            stateController.show(state)
            setStateVisible(true)
        } else {
            setStateVisible(false)
        }
    }

    /// The full-area state to show instead of the list, or `nil` for content.
    private func currentState(visibleCount: Int) -> ContentStateView.Kind? {
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
                ArticleListLayoutFactory.makeLayout(for: self.layoutMode),
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
}
