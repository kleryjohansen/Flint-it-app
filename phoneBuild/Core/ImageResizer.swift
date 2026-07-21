import UIKit

/// Utility untuk resize gambar sebelum disimpan / dikirim.
/// Single source of truth — semua path (disk, CloudKit, Multipeer) panggil ini.
enum ImageResizer {
    /// Resize gambar ke max width/height tertentu, pertahankan aspect ratio.
    /// Kalau gambar sudah lebih kecil dari max, return as-is (no work).
    static func resize(_ image: UIImage, maxDimension: CGFloat = 256) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        if scale >= 1.0 { return image }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
