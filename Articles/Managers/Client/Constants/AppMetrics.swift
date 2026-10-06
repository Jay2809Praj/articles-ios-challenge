import CoreGraphics

/// Spacing and sizing from the Figma file (393 pt wide frame).
enum AppMetrics {
    enum List {
        /// Distance from the screen edge to a card.
        static let horizontalInset: CGFloat = 8
        /// Vertical gap between two cards in the list layout.
        static let cardSpacing: CGFloat = 16
        /// Gaps between cards in the grid layout.
        static let gridColumnSpacing: CGFloat = 9
        static let gridRowSpacing: CGFloat = 8
        static let bottomInset: CGFloat = 24
        /// A list card is 377 pt wide in the design; wider containers get more columns.
        static let preferredCardWidth: CGFloat = 377
        static let preferredGridCardWidth: CGFloat = 184
        static let estimatedCardHeight: CGFloat = 337
        static let estimatedGridCardHeight: CGFloat = 170
    }

    enum Card {
        static let cornerRadius: CGFloat = 8
        static let imageCornerRadius: CGFloat = 8
        /// Glow around a card: 0 / 0 / 30, accent at 15 %.
        static let shadowRadius: CGFloat = 15
        static let shadowOpacity: Float = 0.15
        static let buttonCornerRadius: CGFloat = 8
    }

    enum Detail {
        static let imageCornerRadius: CGFloat = 12
        /// The readable column never grows beyond this on iPad.
        static let maximumContentWidth: CGFloat = 640
    }
}
