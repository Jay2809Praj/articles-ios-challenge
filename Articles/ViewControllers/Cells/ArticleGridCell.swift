import UIKit

/// The compact two-column article card from the grid layout.
final class ArticleGridCell: UICollectionViewCell, NibReusable {
    @IBOutlet private(set) var articleImageView: RemoteImageView!
    @IBOutlet private var cardView: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var titleMinimumHeight: NSLayoutConstraint!

    override var isHighlighted: Bool {
        didSet { CardStyle.animateHighlight(of: self, isHighlighted: isHighlighted) }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        cardView.pinEdges(to: contentView)
        CardStyle.apply(to: self, cardView: cardView)

        articleImageView.layer.cornerRadius = AppMetrics.Card.imageCornerRadius
        articleImageView.targetSize = CGSize(width: 260, height: 150)

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        articleImageView.cancelLoading()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CardStyle.updateShape(of: self)
    }

    func configure(with display: ArticleDisplay) {
        let font = AppFont.cardTitle
        titleLabel.attributedText = TextStyler.attributedString(
            display.title,
            font: font,
            color: AppColor.textOnCard,
            lineHeightMultiple: AppFont.cardTitleLineHeight
        )
        // Always reserve two lines so cards in the same row share a height.
        titleMinimumHeight.constant = 2 * (font.pointSize * AppFont.cardTitleLineHeight).rounded()

        articleImageView.setImage(with: display.imageURL)

        accessibilityLabel = display.title
        accessibilityHint = "Opens the article"
    }
}
