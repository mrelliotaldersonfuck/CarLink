import XCTest
@testable import CarLinkCore

final class YouTubeVideoIDTests: XCTestCase {
    func testWatchAndShortLinks() {
        XCTAssertEqual(YouTubeVideoID.parse("https://www.youtube.com/watch?v=M7lc1UVf-VE&feature=share"), "M7lc1UVf-VE")
        XCTAssertEqual(YouTubeVideoID.parse("https://youtu.be/M7lc1UVf-VE?si=private-token"), "M7lc1UVf-VE")
        XCTAssertEqual(YouTubeVideoID.parse(" m.youtube.com/watch?v=M7lc1UVf-VE "), "M7lc1UVf-VE")
    }

    func testEmbedShortsLiveAndRawID() {
        for path in ["embed", "shorts", "live"] {
            XCTAssertEqual(YouTubeVideoID.parse("https://youtube.com/\(path)/M7lc1UVf-VE"), "M7lc1UVf-VE")
        }
        XCTAssertEqual(YouTubeVideoID.parse("M7lc1UVf-VE"), "M7lc1UVf-VE")
        XCTAssertEqual(YouTubeVideoID.parse("https://www.youtube-nocookie.com/embed/M7lc1UVf-VE"), "M7lc1UVf-VE")
    }

    func testHostSpoofingAndCredentialsAreRejected() {
        for link in ["https://youtube.com.attacker.test/watch?v=M7lc1UVf-VE", "https://attacker.test/youtu.be/M7lc1UVf-VE", "https://youtube.com@attacker.test/watch?v=M7lc1UVf-VE", "https://person:secret@youtube.com/watch?v=M7lc1UVf-VE", "https://youtube.com:9999/watch?v=M7lc1UVf-VE"] {
            XCTAssertNil(YouTubeVideoID.parse(link))
        }
    }

    func testMalformedInputsAndScriptCharactersAreRejected() {
        for link in ["", "https://youtube.com/playlist?list=abc", "https://youtube.com/watch?v=too-short", "https://youtu.be/M7lc1UVf-VE/extra", "javascript://youtube.com/watch?v=M7lc1UVf-VE", "M7lc1UVf-<E", "M7lc1UVf-VE\nmore", String(repeating: "a", count: 4097)] {
            XCTAssertNil(YouTubeVideoID.parse(link))
        }
    }
}
