import Kingfisher
import UIKit

/// An image view that loads remote images with Kingfisher and always has
/// something sensible to show: the design's placeholder while loading, and the
/// same placeholder when the URL is missing, invalid or fails to load.
final class RemoteImageView: UIImageView {
    /// Upper bound, in points, of the decoded image. Feed images are often
    /// several megapixels; downsampling keeps scrolling smooth.
    var targetSize = CGSize(width: 520, height: 300)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setImage(with url: URL?) {
        guard let url else {
            cancelLoading()
            image = AppIcon.imagePlaceholder
            return
        }

        kf.setImage(
            with: url,
            placeholder: AppIcon.imagePlaceholder,
            options: [
                .processor(DownsamplingImageProcessor(size: targetSize)),
                .scaleFactor(traitCollection.displayScale),
                .cacheOriginalImage,
                .transition(.fade(0.25)),
                .retryStrategy(DelayRetryStrategy(maxRetryCount: 1, retryInterval: .seconds(2))),
                .onFailureImage(AppIcon.imagePlaceholder)
            ]
        )
    }

    func cancelLoading() {
        kf.cancelDownloadTask()
    }

    private func configure() {
        contentMode = .scaleAspectFill
        clipsToBounds = true
        backgroundColor = AppColor.placeholderBackground
        image = AppIcon.imagePlaceholder
        kf.indicatorType = .none
    }
}
