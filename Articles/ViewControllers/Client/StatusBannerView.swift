import UIKit

/// A floating pill that reports connectivity and refresh problems.
/// Rendered with Liquid Glass on iOS 26 and a material blur before that.
final class StatusBannerView: UIView, NibLoadable {
    struct Content: Equatable {
        let message: String
        let symbolName: String

        static func offline(savedAgo: String?) -> Content {
            let detail = savedAgo.map { " · Saved \($0)" } ?? ""
            return Content(message: "You’re offline\(detail)", symbolName: AppIcon.Symbol.offline)
        }

        static let backOnline = Content(message: "Back online", symbolName: AppIcon.Symbol.online)
        static let refreshFailed = Content(
            message: "Couldn’t refresh. Showing saved articles.",
            symbolName: AppIcon.Symbol.warning
        )
        static let favoriteAdded = Content(message: "Added to favourites", symbolName: AppIcon.Symbol.favorite)
        static let favoriteRemoved = Content(message: "Removed from favourites", symbolName: AppIcon.Symbol.favorite)
    }

    @IBOutlet private var contentStack: UIStackView!
    @IBOutlet private var iconView: UIImageView!
    @IBOutlet private var messageLabel: UILabel!

    private let effectView = GlassEffect.makeView(fallbackStyle: .systemMaterial)

    var content: Content? {
        didSet { applyContent() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        GlassEffect.apply(.capsule, to: effectView)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2).cgPath
    }

    private func configure() {
        backgroundColor = .clear
        addSubview(effectView)
        effectView.pinEdges(to: self)
        loadContentFromNib(into: effectView.contentView)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        iconView.tintColor = .label
        messageLabel.textColor = .label
        messageLabel.font = AppFont.banner
        messageLabel.adjustsFontForContentSizeCategory = true

        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    private func applyContent() {
        messageLabel.text = content?.message
        iconView.image = content.flatMap { UIImage(systemName: $0.symbolName) }
        accessibilityLabel = content?.message
    }
}
