import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

/// Generates a short, unprotected H.264 movie locally. No server or service login.
actor ProbeMovieFactory {
    static let shared = ProbeMovieFactory()
    private var pending: Task<URL, Error>?

    func movie() async throws -> URL {
        if let pending { return try await pending.value }
        let directory = FileManager.default.temporaryDirectory
        let url = directory.appendingPathComponent("carlink-window-\(UUID().uuidString).mp4")
        let pending = Task.detached(priority: .userInitiated) {
            try await Self.render(to: url)
            return url
        }
        self.pending = pending
        do { return try await pending.value }
        catch { self.pending = nil; throw error }
    }

    private static func render(to url: URL) async throws {
        let width = 320, height = 180, fps: Int32 = 15, frameCount = 120
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        defer {
            if writer.status != .completed {
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: url)
            }
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 350_000,
                                              AVVideoMaxKeyFrameIntervalKey: 15]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                kCVPixelBufferCGImageCompatibilityKey as String: true
            ])
        guard writer.canAdd(input) else { throw Failure.cannotEncode }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? Failure.cannotEncode }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw Failure.cannotEncode }
        let deadline = Date().addingTimeInterval(30)
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing, Date() < deadline else {
                    throw writer.error ?? Failure.cannotEncode
                }
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            var candidate: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &candidate) == kCVReturnSuccess,
                  let buffer = candidate else { throw Failure.cannotEncode }
            CVPixelBufferLockBaseAddress(buffer, [])
            let drawn: Bool
            if let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                       bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                       space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
                let colors: [(CGFloat, CGFloat, CGFloat)] = [(0.1, 0.85, 0.65), (0.15, 0.35, 0.95), (0.95, 0.3, 0.2)]
                for (index, color) in colors.enumerated() {
                    context.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 1)
                    context.fill(CGRect(x: CGFloat(index * width / 3), y: 0, width: CGFloat(width / 3 + 1), height: CGFloat(height)))
                }
                let x = CGFloat(frame) / CGFloat(frameCount - 1) * CGFloat(width - 18)
                context.setFillColor(gray: 1, alpha: 1)
                context.fill(CGRect(x: x, y: 10, width: 18, height: CGFloat(height - 20)))
                context.setFillColor(gray: 0, alpha: 1)
                context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: 6))
                context.setFillColor(gray: 1, alpha: 1)
                context.fill(CGRect(x: 0, y: 0, width: x + 18, height: 6))
                drawn = true
            } else { drawn = false }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard drawn, adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps)) else {
                throw writer.error ?? Failure.cannotEncode
            }
        }
        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else { throw writer.error ?? Failure.cannotEncode }
    }

    private enum Failure: Error { case cannotEncode }
}
