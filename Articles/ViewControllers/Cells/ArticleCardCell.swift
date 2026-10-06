import UIKit

/// The full-width article card from the list layout.
final class ArticleCardCell: UICollectionViewCell, NibReusable {
    @IBOutlet private(set) var articleImageView: RemoteImageView!
    @IBOutlet private var cardView: UIView!
    @IBOutlet private var contentStack: UIStackView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var footerStack: UIStackView!
    @IBOutlet private var dateStack: UIStackView!
    @IBOutlet private var calendarIconView: UIImageView!
    @IBOutlet private var dateLabel: UILabel!
    @IBOutlet private var spacerView: UIView!
    @IBOutlet private var readMoreButton: ReadMoreButton!

    /// Called when the "Read More" button is tapped.
    var onReadMore: (() -> Void)?

    override var isHighlighted: Bool {
        didSet { CardStyle.animateHighlight(of: self, isHighlighted: isHighlighted) }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        cardView.pinEdges(to: contentView)
        CardStyle.apply(to: self, cardView: cardView)

        articleImageView.layer.cornerRadius = AppMetrics.Card.imageCornerRadius
        calendarIconView.image = AppIcon.calendar
        // The design's 45 pt title box holds two 24 pt lines, which overflow it
        // by 3 pt; the gap to the footer is tightened by the same amount.
        contentStack.setCustomSpacing(5, after: titleLabel)

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        articleImageView.cancelLoading()
        onReadMore = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: AppMetrics.Card.cornerRadius).cgPath
    }

    func configure(with display: ArticleDisplay) {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory

        titleLabel.numberOfLines = isAccessibilitySize ? 4 : 2
        titleLabel.attributedText = TextStyler.attributedString(
            display.title,
            font: AppFont.cardTitle,
            color: AppColor.textOnCard,
            lineHeightMultiple: AppFont.cardTitleLineHeight
        )

        dateStack.isHidden = display.listDate == nil
        dateLabel.attributedText = TextStyler.attributedString(
            display.listDate ?? "",
            font: AppFont.cardDate,
            color: AppColor.textMuted,
            kerning: AppFont.cardDateKerning
        )

        // At accessibility sizes the date and the button no longer fit side
        // by side, so the footer stacks vertically.
        footerStack.axis = isAccessibilitySize ? .vertical : .horizontal
        footerStack.alignment = isAccessibilitySize ? .leading : .center
        spacerView.isHidden = isAccessibilitySize

        articleImageView.setImage(with: display.imageURL)

        accessibilityLabel = [display.title, display.listDate].compactMap { $0 }.joined(separator: ", ")
        accessibilityHint = "Opens the article"
    }

    @IBAction private func readMoreTapped() {
        onReadMore?()
    }
}
