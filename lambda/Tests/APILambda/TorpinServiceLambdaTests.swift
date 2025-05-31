import XCTest
@testable import TorpinServiceLambda

final class TorpinServiceLambdaTests: XCTestCase {
    func testTorpinResultEncoding() throws {
        let result = TorpinResult(isBrianTorpin: true)
        let data = try JSONEncoder().encode(result)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(json, "{\"isBrianTorpin\":true}")
    }
}

