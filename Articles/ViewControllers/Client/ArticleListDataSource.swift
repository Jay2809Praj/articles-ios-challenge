import UIKit

/// Feeds the list screen's collection view with article cards.
final class ArticleListDataSource: NSObject, UICollectionViewDataSource {
    var articles: [Article] = []
    var layoutMode: ArticleListLayoutMode = .list
    /// Called when the "Read More" button on a card is tapped.
    var onReadMore: ((Article) -> Void)?

    func registerCells(in collectionView: UICollectionView) {
        collectionView.register(ArticleCardCell.self)
        collectionView.register(ArticleGridCell.self)
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

        switch layoutMode {
        case .list:
            let cell = collectionView.dequeue(ArticleCardCell.self, for: indexPath)
            cell.configure(with: display)
            cell.onReadMore = { [weak self] in self?.onReadMore?(article) }
            return cell
        case .grid:
            let cell = collectionView.dequeue(ArticleGridCell.self, for: indexPath)
            cell.configure(with: display)
            return cell
        }
    }
}
