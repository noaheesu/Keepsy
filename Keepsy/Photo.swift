import UIKit

extension Data {
    /// Photos are only shown small, so full-size images would just bloat the store and iCloud sync.
    func downscaledJPEG(maxSide: CGFloat = 600) -> Data? {
        guard let image = UIImage(data: self) else { return nil }
        let scale = Swift.min(1, maxSide / Swift.max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return image.preparingThumbnail(of: size)?.jpegData(compressionQuality: 0.8)
    }
}
