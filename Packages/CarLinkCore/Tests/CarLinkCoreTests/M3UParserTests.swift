import XCTest
@testable import CarLinkCore

final class M3UParserTests: XCTestCase {
    let base = URL(string: "https://media.example/lists/channels.m3u")!

    func testQuotedCommaBOMCRLFAndRelativeURL() throws {
        let text = "\u{FEFF}#EXTM3U\r\n#EXTINF:-1 group-title=\"News, live\",Canal Um\r\n../live/one.m3u8\r\n"
        guard case .channels(let items) = try M3UParser.parse(text, sourceURL: base) else { return XCTFail() }
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Canal Um")
        XCTAssertEqual(items[0].group, "News, live")
        XCTAssertEqual(items[0].url.absoluteString, "https://media.example/live/one.m3u8")
    }

    func testHLSMasterIsNotImportedAsChannels() throws {
        let text = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000\nlow/index.m3u8\n"
        XCTAssertEqual(try M3UParser.parse(text, sourceURL: base), .hls(base))
    }

    func testHLSSegmentsAreNotImportedAsChannels() throws {
        let text = "#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,\nsegment001.ts\n"
        XCTAssertEqual(try M3UParser.parse(text, sourceURL: base), .hls(base))
    }

    func testRejectsUnsafeSchemesAndDeduplicates() throws {
        let text = "#EXTM3U\n#EXTINF:-1,Bad\nfile:///private/data\n#EXTINF:-1,Good\nhttps://example.com/a\nhttps://example.com/a\njavascript:alert(1)\n"
        guard case .channels(let items) = try M3UParser.parse(text, sourceURL: base) else { return XCTFail() }
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Good")
    }

    func testSizeLimit() {
        XCTAssertThrowsError(try M3UParser.parse(String(repeating: "a", count: M3UParser.maximumBytes + 1), sourceURL: base))
    }

    func testChannelLimit() {
        let text = (0...M3UParser.maximumChannels).map { "https://example.com/\($0)" }.joined(separator: "\n")
        XCTAssertThrowsError(try M3UParser.parse(text, sourceURL: base))
    }

    func testEmptyAndInvalidURLs() {
        XCTAssertThrowsError(try M3UParser.parse("#EXTM3U\n", sourceURL: base))
        for input in ["", "file:///tmp/a.mp4", "javascript:alert(1)", "https://", "https://a.com/\nheader"] {
            XCTAssertThrowsError(try URLPolicy.mediaURL(input))
        }
    }

    func testDiagnosticOriginRedactsCredentialsPathAndToken() throws {
        let url = try URLPolicy.mediaURL("https://user:password@example.com/private/token.mp4?secret=123")
        XCTAssertEqual(URLPolicy.displayOrigin(url), "https://example.com")
    }

    func testWebPageDetectionDoesNotConfuseOtherDomains() throws {
        XCTAssertTrue(URLPolicy.isWebPage(try URLPolicy.mediaURL("https://m.youtube.com/watch?v=1")))
        XCTAssertFalse(URLPolicy.isWebPage(try URLPolicy.mediaURL("https://notyoutube.com/video.mp4")))
    }

    func testLocalEntrySurvivesJSONRoundTripWithoutSandboxPath() throws {
        let item = MediaEntry(title: "Filme", location: "local.mp4", source: .local)
        let data = try JSONEncoder().encode(item)
        XCTAssertEqual(try JSONDecoder().decode(MediaEntry.self, from: data), item)
    }
}
