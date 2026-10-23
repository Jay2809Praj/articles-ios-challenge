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
    @IBOutlet private var saveButton: UIButton!

    /// Called when the "Read More" button is tapped.
    var onReadMore: (() -> Void)?

    /// Called when the save button is tapped.
    var onToggleSave: (() -> Void)?

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

        configureSaveButtonAppearance()

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    private func configureSaveButtonAppearance() {
        saveButton.tintColor = .white
        saveButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        saveButton.layer.cornerRadius = 19
        saveButton.layer.borderWidth = 1
        saveButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        saveButton.clipsToBounds = true
        saveButton.imageView?.contentMode = .scaleAspectFit
    }

    private var lastSaveTapTime: TimeInterval = 0

    override func prepareForReuse() {
        super.prepareForReuse()
        articleImageView.cancelLoading()
        onReadMore = nil
        onToggleSave = nil
        lastSaveTapTime = 0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CardStyle.updateShape(of: self)
        saveButton.layer.cornerRadius = saveButton.bounds.height / 2
    }

    func configure(with display: ArticleDisplay, isSaved: Bool = false) {
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
        updateSavedState(isSaved)

        accessibilityLabel = [display.title, display.listDate].compactMap { $0 }.joined(separator: ", ")
        accessibilityHint = "Opens the article"
    }

    /// Updates only the save button's icon and label without rebuilding the entire cell.
    func updateSavedState(_ isSaved: Bool) {
        saveButton.setImage(AppIcon.favoriteIcon(isSaved: isSaved, size: CGSize(width: 20, height: 16.5)), for: .normal)
        saveButton.accessibilityLabel = isSaved ? "Remove from saved articles" : "Save article for later"
    }

    @IBAction private func readMoreTapped() {
        onReadMore?()
    }

    @IBAction private func saveTapped() {
        let now = CACurrentMediaTime()
        guard now - lastSaveTapTime > 0.25 else { return }
        lastSaveTapTime = now

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        saveButton.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0.8,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.saveButton.transform = .identity
        }
        onToggleSave?()
    }
}
