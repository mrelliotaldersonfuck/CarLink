import Foundation

public struct HTTPByteRange: Equatable, Sendable {
    public let start: UInt64
    public let end: UInt64
    public var count: UInt64 { end - start + 1 }

    public static func parse(_ header: String, size: UInt64) -> HTTPByteRange? {
        guard size > 0, header.hasPrefix("bytes="), !header.contains(",") else { return nil }
        let parts = header.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        if parts[0].isEmpty {
            guard let suffix = UInt64(parts[1]), suffix > 0 else { return nil }
            return HTTPByteRange(start: size - min(size, suffix), end: size - 1)
        }
        guard let start = UInt64(parts[0]), start < size else { return nil }
        let end: UInt64
        if parts[1].isEmpty { end = size - 1 }
        else {
            guard let requested = UInt64(parts[1]), requested >= start else { return nil }
            end = min(requested, size - 1)
        }
        return HTTPByteRange(start: start, end: end)
    }
}
