import UIKit

/// The compact two-column article card from the grid layout.
final class ArticleGridCell: UICollectionViewCell, NibReusable {
    @IBOutlet private(set) var articleImageView: RemoteImageView!
    @IBOutlet private var cardView: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var titleMinimumHeight: NSLayoutConstraint!
    @IBOutlet private var saveButton: UIButton!

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
        articleImageView.targetSize = CGSize(width: 260, height: 150)

        configureSaveButtonAppearance()

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    private func configureSaveButtonAppearance() {
        saveButton.tintColor = .white
        saveButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        saveButton.layer.cornerRadius = 15
        saveButton.layer.borderWidth = 1
        saveButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        saveButton.clipsToBounds = true
        saveButton.imageView?.contentMode = .scaleAspectFit
    }

    private var lastSaveTapTime: TimeInterval = 0

    override func prepareForReuse() {
        super.prepareForReuse()
        articleImageView.cancelLoading()
        onToggleSave = nil
        lastSaveTapTime = 0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CardStyle.updateShape(of: self)
        saveButton.layer.cornerRadius = saveButton.bounds.height / 2
    }

    func configure(with display: ArticleDisplay, isSaved: Bool = false, localImageURL: URL? = nil) {
        let font = AppFont.cardTitle
        titleLabel.attributedText = TextStyler.attributedString(
            display.title,
            font: font,
            color: AppColor.textOnCard,
            lineHeightMultiple: AppFont.cardTitleLineHeight
        )
        // Always reserve two lines so cards in the same row share a height.
        titleMinimumHeight.constant = 2 * (font.pointSize * AppFont.cardTitleLineHeight).rounded()

        articleImageView.setImage(with: display.imageURL, localFile: localImageURL)
        updateSavedState(isSaved)

        accessibilityLabel = display.title
        accessibilityHint = "Opens the article"
    }

    /// Updates only the save button's icon and label without rebuilding the entire cell.
    func updateSavedState(_ isSaved: Bool) {
        saveButton.setImage(AppIcon.favoriteIcon(isSaved: isSaved, size: CGSize(width: 16, height: 13.5)), for: .normal)
        saveButton.accessibilityLabel = isSaved ? "Remove from saved articles" : "Save article for later"
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
