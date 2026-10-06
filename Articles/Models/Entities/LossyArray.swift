import Foundation

/// Decodes an array element by element, dropping the elements that fail
/// instead of failing the whole collection.
struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Element] = []
        if let count = container.count {
            decoded.reserveCapacity(count)
        }
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                decoded.append(element)
            } else {
                // Consume the broken element so the cursor keeps moving.
                _ = try? container.decode(DiscardedElement.self)
            }
        }
        elements = decoded
    }

    /// Accepts any JSON value (object, scalar or `null`) without inspecting it.
    private struct DiscardedElement: Decodable {
        init(from decoder: Decoder) throws {}
    }
}
