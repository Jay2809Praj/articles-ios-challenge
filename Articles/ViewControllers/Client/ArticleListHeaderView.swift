import UIKit

enum ArticleListSectionFilter: Int {
    case all = 0
    case saved = 1
}

protocol ArticleListHeaderViewDelegate: AnyObject {
    func headerViewDidToggleLayout(_ headerView: ArticleListHeaderView)
    func headerView(_ headerView: ArticleListHeaderView, didChangeSearchText text: String)
    func headerViewDidEndSearch(_ headerView: ArticleListHeaderView)
    func headerView(_ headerView: ArticleListHeaderView, didSelectFilter filter: ArticleListSectionFilter)
}

/// The list screen's header: the "Articles" title with the layout and search
/// buttons, which swaps to an inline search field when search is active.
final class ArticleListHeaderView: UIView, NibLoadable {
    @IBOutlet private var titleRow: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var layoutButton: UIButton!
    @IBOutlet private var searchButton: UIButton!
    @IBOutlet private var searchRow: UIStackView!
    @IBOutlet private var searchField: UISearchTextField!
    @IBOutlet private var cancelButton: UIButton!
    @IBOutlet private var filterSegmentedControl: UISegmentedControl!
    @IBOutlet private var storageLabel: UILabel!
    @IBOutlet private var storageTopConstraint: NSLayoutConstraint!
    @IBOutlet private var storageHeightConstraint: NSLayoutConstraint!

    weak var delegate: ArticleListHeaderViewDelegate?

    /// The icon offers the layout the user can switch *to*.
    var showsGridLayout = false {
        didSet { updateLayoutButton() }
    }

    private(set) var isSearching = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func endSearch() {
        guard isSearching else { return }
        searchField.text = nil
        searchField.resignFirstResponder()
        setSearching(false)
        delegate?.headerViewDidEndSearch(self)
    }

    // MARK: - Setup

    private func configure() {
        loadContentFromNib()
        backgroundColor = AppColor.background

        searchButton.setImage(AppIcon.search, for: .normal)
        searchButton.tintColor = AppColor.textPrimary
        searchButton.accessibilityLabel = "Search articles"
        layoutButton.tintColor = AppColor.textPrimary

        searchField.delegate = self
        searchField.tintColor = AppColor.accent
        cancelButton.tintColor = AppColor.accent

        configureFilterSegmentedControl()
        showsStorageUsage(false)
        applyFonts()
        updateLayoutButton()

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.applyFonts()
        }
    }

    private func configureFilterSegmentedControl() {
        filterSegmentedControl.selectedSegmentTintColor = AppColor.card
        let normalTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: AppColor.textMuted,
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ]
        let selectedTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 13, weight: .bold)
        ]
        filterSegmentedControl.setTitleTextAttributes(normalTextAttributes, for: .normal)
        filterSegmentedControl.setTitleTextAttributes(selectedTextAttributes, for: .selected)
    }

    private func applyFonts() {
        titleLabel.attributedText = TextStyler.attributedString(
            "Articles",
            font: AppFont.screenTitle,
            color: AppColor.textPrimary,
            kerning: AppFont.screenTitleKerning
        )
        titleLabel.accessibilityTraits = .header
        searchField.font = AppFont.banner
        cancelButton.titleLabel?.font = AppFont.banner
        storageLabel.font = AppFont.cardDate
        storageLabel.textColor = AppColor.textMuted
    }

    private func updateLayoutButton() {
        layoutButton.setImage(showsGridLayout ? AppIcon.list : AppIcon.grid, for: .normal)
        layoutButton.accessibilityLabel = showsGridLayout ? "Show as list" : "Show as grid"
    }

    private func setSearching(_ searching: Bool) {
        isSearching = searching
        let incoming: UIView = searching ? searchRow : titleRow
        let outgoing: UIView = searching ? titleRow : searchRow

        incoming.alpha = 0
        incoming.isHidden = false
        incoming.transform = CGAffineTransform(translationX: searching ? 24 : -24, y: 0)

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState]
        ) {
            incoming.alpha = 1
            incoming.transform = .identity
            outgoing.alpha = 0
        } completion: { _ in
            // A newer toggle may have reversed the roles mid-animation.
            outgoing.isHidden = self.isSearching == searching
        }
    }

    // MARK: - Actions

    @IBAction private func layoutTapped() {
        delegate?.headerViewDidToggleLayout(self)
    }

    @IBAction private func searchTapped() {
        setSearching(true)
        searchField.becomeFirstResponder()
    }

    @IBAction private func searchTextChanged() {
        delegate?.headerView(self, didChangeSearchText: searchField.text ?? "")
    }

    @IBAction private func cancelTapped() {
        endSearch()
    }

    @IBAction private func filterChanged(_ sender: UISegmentedControl) {
        let filter = ArticleListSectionFilter(rawValue: sender.selectedSegmentIndex) ?? .all
        delegate?.headerView(self, didSelectFilter: filter)
    }

    /// Updates the "Saved (n)" segment and the storage line shown under it
    /// while the Saved section is selected ("12.4 MB of 50 MB used").
    func updateSavedSummary(count: Int, usedBytes: Int64, limitBytes: Int64) {
        let title = count > 0 ? "Saved (\(count))" : "Saved"
        filterSegmentedControl.setTitle(title, forSegmentAt: 1)
        storageLabel.text = StorageSizeFormatter.usageSummary(used: usedBytes, limit: limitBytes)
        storageLabel.accessibilityLabel = "Saved articles storage: \(storageLabel.text ?? "")"
    }

    /// The storage line only matters while looking at saved articles.
    /// The storage line only matters while looking at saved articles. It is
    /// collapsed with constraints rather than `isHidden` inside a stack view,
    /// which has proven unreliable at restoring the height.
    func showsStorageUsage(_ shows: Bool) {
        storageHeightConstraint.isActive = !shows
        storageTopConstraint.constant = shows ? 6 : 0
        storageLabel.isHidden = !shows
        setNeedsLayout()
    }

    func selectFilter(_ filter: ArticleListSectionFilter) {
        filterSegmentedControl.selectedSegmentIndex = filter.rawValue
        showsStorageUsage(filter == .saved)
    }
}

extension ArticleListHeaderView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
