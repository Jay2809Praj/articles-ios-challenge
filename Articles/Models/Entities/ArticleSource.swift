import Foundation

/// The publisher an article originates from.
struct ArticleSource: Codable, Hashable {
    let id: String?
    let name: String?

    init(id: String? = nil, name: String? = nil) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeCleanString(forKey: .id)
        name = container.decodeCleanString(forKey: .name)
    }
}
