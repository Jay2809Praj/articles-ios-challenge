import UIKit

/// Builds attributed strings that reproduce the design's line heights and tracking.
enum TextStyler {
    static func attributedString(
        _ text: String,
        font: UIFont,
        color: UIColor,
        lineHeightMultiple: CGFloat? = nil,
        kerning: CGFloat = 0,
        alignment: NSTextAlignment = .natural,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineBreakMode

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .kern: kerning
        ]

        if let lineHeightMultiple {
            // Figma centres glyphs in the line box, UIKit sits them on its
            // bottom edge – the baseline offset re-centres them.
            let lineHeight = (font.pointSize * lineHeightMultiple).rounded()
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
            attributes[.baselineOffset] = (lineHeight - font.lineHeight) / 2
        }

        attributes[.paragraphStyle] = paragraph
        return NSAttributedString(string: text, attributes: attributes)
    }
}
