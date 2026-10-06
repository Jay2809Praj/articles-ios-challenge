import CoreGraphics

/// Spacing and sizing taken from the Figma design (375 pt wide frame).
enum AppMetrics {
    enum List {
        /// Distance from the screen edge to a card.
        static let horizontalInset: CGFloat = 8
        /// Vertical gap between two cards.
        static let cardSpacing: CGFloat = 16
        static let topInset: CGFloat = 4
        static let bottomInset: CGFloat = 24
        /// Widest a single card is allowed to grow before a second column is added.
        static let maximumCardWidth: CGFloat = 520
        static let estimatedCardHeight: CGFloat = 321
        static let estimatedGridCardHeight: CGFloat = 220
    }

    enum Card {
        static let cornerRadius: CGFloat = 6
        static let imageCornerRadius: CGFloat = 4
        static let buttonCornerRadius: CGFloat = 6
        static let selectionBorderWidth: CGFloat = 2
    }

    enum Detail {
        static let sheetCornerRadius: CGFloat = 24
        static let maximumContentWidth: CGFloat = 720
    }
}
