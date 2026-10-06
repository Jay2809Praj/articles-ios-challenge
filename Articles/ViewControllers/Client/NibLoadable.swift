import UIKit

/// A reusable view whose content lives in a XIB named after the class, with
/// the class set as the XIB's File's Owner.
protocol NibLoadable: UIView {}

extension NibLoadable {
    /// Loads the XIB and pins its root view to the edges of `container`
    /// (the receiver itself by default).
    func loadContentFromNib(into container: UIView? = nil) {
        let container = container ?? self
        let name = String(describing: Self.self)
        let nib = UINib(nibName: name, bundle: Bundle(for: Self.self))
        guard let content = nib.instantiate(withOwner: self).first as? UIView else {
            assertionFailure("\(name).xib has no root view")
            return
        }

        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        content.pinEdges(to: container)
    }
}

/// A collection view cell registered from a XIB named after the class.
protocol NibReusable: UICollectionViewCell {}

extension NibReusable {
    static var reuseIdentifier: String { String(describing: Self.self) }
    static var nib: UINib { UINib(nibName: reuseIdentifier, bundle: Bundle(for: Self.self)) }
}

extension UICollectionView {
    func register<Cell: NibReusable>(_ cell: Cell.Type) {
        register(cell.nib, forCellWithReuseIdentifier: cell.reuseIdentifier)
    }

    func dequeue<Cell: NibReusable>(_ cell: Cell.Type, for indexPath: IndexPath) -> Cell {
        guard let dequeued = dequeueReusableCell(withReuseIdentifier: cell.reuseIdentifier, for: indexPath) as? Cell else {
            fatalError("\(cell.reuseIdentifier) is not registered")
        }
        return dequeued
    }
}

extension UIView {
    /// Constrains the receiver to fill `other`. Both must share a hierarchy.
    func pinEdges(to other: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: other.topAnchor),
            leadingAnchor.constraint(equalTo: other.leadingAnchor),
            trailingAnchor.constraint(equalTo: other.trailingAnchor),
            bottomAnchor.constraint(equalTo: other.bottomAnchor)
        ])
    }
}
