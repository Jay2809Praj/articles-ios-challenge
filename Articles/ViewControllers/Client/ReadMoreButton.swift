import UIKit

/// The design's blue call-to-action: a label followed by an arrow, on an
/// accent-coloured rounded rectangle. Layout lives in `ReadMoreButton.xib`.
final class ReadMoreButton: UIControl, NibLoadable {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconView: UIImageView!

    var title: String = "Read More" {
        didSet { applyTitle() }
    }

    override var isHighlighted: Bool {
        didSet { animateHighlight() }
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.5 }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        loadContentFromNib()
        subviews.forEach { $0.isUserInteractionEnabled = false }

        backgroundColor = AppColor.accent
        layer.cornerRadius = AppMetrics.Card.buttonCornerRadius
        layer.cornerCurve = .continuous

        iconView.image = AppIcon.readMore
        titleLabel.textColor = AppColor.textOnCard
        titleLabel.adjustsFontForContentSizeCategory = true
        applyTitle()

        isAccessibilityElement = true
        accessibilityTraits = .button
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.applyTitle()
        }
    }

    /// Styles the button for floating above scrolling content: Liquid Glass
    /// tinted with the accent colour on iOS 26, the solid design button with
    /// a soft shadow on earlier systems.
    func applyFloatingStyle() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)

        guard #available(iOS 26.0, *) else { return }
        let glassView = GlassEffect.makeView(tint: AppColor.accent)
        glassView.isUserInteractionEnabled = false
        insertSubview(glassView, at: 0)
        glassView.pinEdges(to: self)
        GlassEffect.apply(.capsule, to: glassView)
        backgroundColor = .clear
    }

    private func applyTitle() {
        titleLabel.font = AppFont.button
        titleLabel.text = title
        accessibilityLabel = title
    }

    private func animateHighlight() {
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            self.alpha = self.isHighlighted ? 0.85 : (self.isEnabled ? 1 : 0.5)
        }
    }
}
