import UIKit

/// Bottom loading spinner shown during infinite scrolling pagination.
final class LoadingFooterView: UICollectionReusableView {
    static let reuseIdentifier = "LoadingFooterView"

    private let spinner = UIActivityIndicatorView(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        spinner.color = AppColor.accent
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        spinner.stopAnimating()
    }

    func startAnimating() {
        spinner.startAnimating()
    }

    func stopAnimating() {
        spinner.stopAnimating()
    }
}

/// Feeds the list screen's collection view with article cards.
final class ArticleListDataSource: NSObject, UICollectionViewDataSource {
    var articles: [Article] = []
    var layoutMode: ArticleListLayoutMode = .list
    var isLoadingMore = false
    /// Called when the "Read More" button on a card is tapped.
    var onReadMore: ((Article) -> Void)?
    /// Checks whether an article is currently saved.
    var isSaved: ((Article) -> Bool)?
    /// Called when the save button on a card is tapped.
    var onToggleSave: ((Article) -> Void)?

    func registerCells(in collectionView: UICollectionView) {
        collectionView.register(ArticleCardCell.self)
        collectionView.register(ArticleGridCell.self)
        collectionView.register(
            LoadingFooterView.self,
            forSupplementaryViewOfKind: ArticleListLayoutFactory.footerElementKind,
            withReuseIdentifier: LoadingFooterView.reuseIdentifier
        )
    }

    func article(at indexPath: IndexPath) -> Article? {
        articles.indices.contains(indexPath.item) ? articles[indexPath.item] : nil
    }

    func indexPath(for article: Article) -> IndexPath? {
        articles.firstIndex(of: article).map { IndexPath(item: $0, section: 0) }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        articles.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let article = articles[indexPath.item]
        let display = ArticleDisplay(article: article)
        let isArticleSaved = isSaved?(article) ?? false

        switch layoutMode {
        case .list:
            let cell = collectionView.dequeue(ArticleCardCell.self, for: indexPath)
            cell.configure(with: display, isSaved: isArticleSaved)
            cell.onReadMore = { [weak self] in self?.onReadMore?(article) }
            cell.onToggleSave = { [weak self] in self?.onToggleSave?(article) }
            return cell
        case .grid:
            let cell = collectionView.dequeue(ArticleGridCell.self, for: indexPath)
            cell.configure(with: display, isSaved: isArticleSaved)
            cell.onToggleSave = { [weak self] in self?.onToggleSave?(article) }
            return cell
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == ArticleListLayoutFactory.footerElementKind else {
            return UICollectionReusableView()
        }
        let footer = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: LoadingFooterView.reuseIdentifier,
            for: indexPath
        ) as? LoadingFooterView ?? LoadingFooterView()

        if isLoadingMore {
            footer.startAnimating()
        } else {
            footer.stopAnimating()
        }
        return footer
    }
}
