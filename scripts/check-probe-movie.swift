import AVFoundation
import CoreVideo
import Foundation

/// macOS CI executes the same encoder used on iPhone, then decodes its output.
@main
struct CheckProbeMovie {
    static func main() async throws {
        let url = try await ProbeMovieFactory.shared.movie()
        defer { try? FileManager.default.removeItem(at: url) }
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first, tracks.count == 1 else { throw Failure.invalidTracks }
        let size = try await track.load(.naturalSize)
        let duration = try await asset.load(.duration)
        guard size.width == 320, size.height == 180, (7.8...8.2).contains(duration.seconds) else {
            throw Failure.invalidGeometryOrDuration
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? Failure.cannotDecode }
        var count = 0
        var fingerprints = Set<UInt64>()
        while let sample = output.copyNextSampleBuffer() {
            guard let image = CMSampleBufferGetImageBuffer(sample) else { throw Failure.cannotDecode }
            CVPixelBufferLockBaseAddress(image, .readOnly)
            guard let base = CVPixelBufferGetBaseAddress(image) else {
                CVPixelBufferUnlockBaseAddress(image, .readOnly)
                throw Failure.cannotDecode
            }
            let row = base.assumingMemoryBound(to: UInt8.self).advanced(by: CVPixelBufferGetBytesPerRow(image) * 90)
            var fingerprint: UInt64 = 14695981039346656037
            for index in stride(from: 0, to: 320 * 4, by: 4) {
                fingerprint = (fingerprint ^ UInt64(row[index])) &* 1099511628211
            }
            fingerprints.insert(fingerprint)
            CVPixelBufferUnlockBaseAddress(image, .readOnly)
            count += 1
        }
        guard reader.status == .completed, count == 120, fingerprints.count > 10 else {
            throw reader.error ?? Failure.cannotDecode
        }
        print("Teste local: H.264 320×180, 120 frames decodificados, movimento presente. Não comprova saída CarPlay.")
    }

    private enum Failure: Error {
        case invalidTracks, invalidGeometryOrDuration, cannotDecode
    }
}
