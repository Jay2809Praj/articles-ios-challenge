import UIKit

/// The article detail from the design: dark header with back and favourite
/// buttons, headline, age, hero image and body, plus a floating button that
/// opens the full article in Safari.
final class ArticleDetailViewController: UIViewController {
    @IBOutlet private var backButton: UIButton!
    @IBOutlet private var navigationTitleLabel: UILabel!
    @IBOutlet private var favoriteButton: UIButton!
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var titleBlock: UIStackView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var metaStack: UIStackView!
    @IBOutlet private var clockIconView: UIImageView!
    @IBOutlet private var metaLabel: UILabel!
    @IBOutlet private var imageShadowView: UIView!
    @IBOutlet private var articleImageView: RemoteImageView!
    @IBOutlet private var bodyLabel: UILabel!
    @IBOutlet private var readFullArticleButton: ReadMoreButton!

    private let article: Article
    private let display: ArticleDisplay
    private let favoritesManager: FavoritesManagerProtocol
    private weak var router: ArticleRouting?
    private lazy var bannerPresenter = BannerPresenter(hostView: view)

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    /// Where the hero image sits, in the view's coordinates – the zoom
    /// transition lands the card's image exactly here.
    var heroImageFrame: CGRect? {
        guard isViewLoaded else { return nil }
        view.layoutIfNeeded()
        return imageShadowView.convert(imageShadowView.bounds, to: view)
    }

    // MARK: - Lifecycle

    init?(
        coder: NSCoder,
        article: Article,
        favoritesManager: FavoritesManagerProtocol,
        router: ArticleRouting
    ) {
        self.article = article
        self.display = ArticleDisplay(article: article)
        self.favoritesManager = favoritesManager
        self.router = router
        super.init(coder: coder)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use ViewControllerFactory to create ArticleDetailViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        renderText()
        renderFavoriteState(animated: false)
        articleImageView.setImage(with: display.imageURL)

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.renderText()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateBackButtonVisibility()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBackButtonVisibility()

        imageShadowView.layer.shadowPath = UIBezierPath(
            roundedRect: imageShadowView.bounds,
            cornerRadius: AppMetrics.Detail.imageCornerRadius
        ).cgPath

        // Keep the end of the article clear of the floating button.
        let overlap = view.bounds.maxY - readFullArticleButton.frame.minY
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap - view.safeAreaInsets.bottom
    }

    // MARK: - Setup

    private func configureAppearance() {
        configureBackButton()

        favoriteButton.tintColor = AppColor.textOnCard
        clockIconView.image = AppIcon.clock

        titleBlock.isLayoutMarginsRelativeArrangement = true
        titleBlock.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)

        articleImageView.layer.cornerRadius = AppMetrics.Detail.imageCornerRadius
        articleImageView.targetSize = CGSize(width: 640, height: 360)
        imageShadowView.layer.shadowColor = UIColor.black.cgColor
        imageShadowView.layer.shadowOpacity = 0.25
        imageShadowView.layer.shadowRadius = 2
        imageShadowView.layer.shadowOffset = CGSize(width: 0, height: 4)

        readFullArticleButton.applyFloatingStyle()
        readFullArticleButton.isEnabled = display.webURL != nil
    }

    /// Liquid Glass on iOS 26; the design's translucent white circle before.
    private func configureBackButton() {
        var configuration: UIButton.Configuration
        if #available(iOS 26.0, *) {
            configuration = .clearGlass()
        } else {
            configuration = .plain()
            configuration.background.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        }
        configuration.image = AppIcon.back
        configuration.cornerStyle = .capsule
        configuration.contentInsets = .zero
        backButton.configuration = configuration
        backButton.accessibilityLabel = "Back"
    }

    private func updateBackButtonVisibility() {
        // On iPad the detail sits beside the list and has nowhere to go back to.
        backButton.isHidden = !(splitViewController?.isCollapsed ?? true)
    }

    // MARK: - Rendering

    private func renderText() {
        navigationTitleLabel.font = AppFont.navigationTitle
        navigationTitleLabel.textColor = AppColor.textOnCard
        navigationTitleLabel.text = "Article"
        navigationTitleLabel.accessibilityTraits = .header

        titleLabel.attributedText = TextStyler.attributedString(
            display.title,
            font: AppFont.detailTitle,
            color: AppColor.textOnCard,
            lineHeightMultiple: AppFont.detailTitleLineHeight,
            lineBreakMode: .byWordWrapping
        )

        metaStack.isHidden = display.detailMeta == nil
        clockIconView.isHidden = !display.hasDate
        metaLabel.font = AppFont.detailMeta
        metaLabel.textColor = AppColor.detailMeta
        metaLabel.text = display.detailMeta

        bodyLabel.attributedText = TextStyler.attributedString(
            display.body,
            font: AppFont.detailBody,
            color: AppColor.detailBody,
            lineHeightMultiple: AppFont.detailBodyLineHeight,
            lineBreakMode: .byWordWrapping
        )

        readFullArticleButton.title = display.webURL == nil ? "Full article unavailable" : "Read Full Article"
    }

    private func renderFavoriteState(animated: Bool) {
        let isFavorite = favoritesManager.isFavorite(article)
        favoriteButton.setImage(isFavorite ? AppIcon.favoriteRemove : AppIcon.favoriteAdd, for: .normal)
        favoriteButton.accessibilityLabel = isFavorite ? "Remove from favourites" : "Add to favourites"

        guard animated else { return }
        favoriteButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.45,
            initialSpringVelocity: 0.8,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.favoriteButton.transform = .identity
        }
    }

    // MARK: - Actions

    @IBAction private func backTapped() {
        router?.closeDetail()
    }

    @IBAction private func favoriteTapped() {
        let isFavorite = favoritesManager.toggleFavorite(article)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        renderFavoriteState(animated: true)
        bannerPresenter.toast(isFavorite ? .favoriteAdded : .favoriteRemoved)
    }

    @IBAction private func readFullArticleTapped() {
        guard let url = display.webURL else { return }
        router?.openInBrowser(url)
    }
}
