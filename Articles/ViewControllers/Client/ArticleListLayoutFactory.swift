import UIKit

/// The two ways the list screen can arrange its cards.
enum ArticleListLayoutMode {
    case list
    case grid

    mutating func toggle() {
        self = self == .list ? .grid : .list
    }
}

/// Builds the collection view layout for each mode. Column counts are derived
/// from the card widths in the design, so the same code yields one column on
/// an iPhone, and more wherever there is room for them.
enum ArticleListLayoutFactory {
    static func makeLayout(for mode: ArticleListLayoutMode) -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let metrics = Metrics(mode: mode)
            let inset = AppMetrics.List.horizontalInset
            let availableWidth = environment.container.effectiveContentSize.width - 2 * inset
            let fitting = Int((availableWidth + metrics.columnSpacing) / (metrics.preferredWidth + metrics.columnSpacing))
            let columns = max(metrics.minimumColumns, fitting)

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1 / CGFloat(columns)),
                heightDimension: .estimated(metrics.estimatedHeight)
            )
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(metrics.estimatedHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: NSCollectionLayoutItem(layoutSize: itemSize),
                count: columns
            )
            group.interItemSpacing = .fixed(metrics.columnSpacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = metrics.rowSpacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: inset,
                bottom: AppMetrics.List.bottomInset,
                trailing: inset
            )
            return section
        }
    }

    private struct Metrics {
        let preferredWidth: CGFloat
        let estimatedHeight: CGFloat
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat
        let minimumColumns: Int

        init(mode: ArticleListLayoutMode) {
            switch mode {
            case .list:
                preferredWidth = AppMetrics.List.preferredCardWidth
                estimatedHeight = AppMetrics.List.estimatedCardHeight
                columnSpacing = AppMetrics.List.cardSpacing
                rowSpacing = AppMetrics.List.cardSpacing
                minimumColumns = 1
            case .grid:
                preferredWidth = AppMetrics.List.preferredGridCardWidth
                estimatedHeight = AppMetrics.List.estimatedGridCardHeight
                columnSpacing = AppMetrics.List.gridColumnSpacing
                rowSpacing = AppMetrics.List.gridRowSpacing
                minimumColumns = 2
            }
        }
    }
}
