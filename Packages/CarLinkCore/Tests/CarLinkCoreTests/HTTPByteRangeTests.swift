import XCTest
@testable import CarLinkCore

final class HTTPByteRangeTests: XCTestCase {
    func testNormalAndOpenRange() {
        XCTAssertEqual(HTTPByteRange.parse("bytes=10-19", size: 100)?.count, 10)
        XCTAssertEqual(HTTPByteRange.parse("bytes=10-", size: 100)?.end, 99)
        XCTAssertEqual(HTTPByteRange.parse("bytes=0-999", size: 100)?.count, 100)
    }
    func testSuffix() {
        XCTAssertEqual(HTTPByteRange.parse("bytes=-20", size: 100)?.start, 80)
        XCTAssertEqual(HTTPByteRange.parse("bytes=-200", size: 100)?.start, 0)
    }
    func testInvalidAndUnsatisfiableRanges() {
        for header in ["bytes=100-", "bytes=9-1", "bytes=-0", "bytes=a-b", "bytes=0-1,5-6", "items=0-1"] {
            XCTAssertNil(HTTPByteRange.parse(header, size: 100))
        }
        XCTAssertNil(HTTPByteRange.parse("bytes=0-", size: 0))
    }
}
