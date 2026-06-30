import AWSS3
import XCTest
@testable import EventHandlerV2Lambda

final class TorpinStatusCacheTests: XCTestCase {
    func testPutStatusWritesBothStaticEndpointObjects() async throws {
        let s3Client = MockS3Client()
        let cache = S3TorpinStatusCache(bucketName: "status-bucket", s3Client: s3Client)

        try await cache.putStatus(isBrianTorpin: true)

        let expectedCount = S3TorpinStatusCache.keys.count
        XCTAssertEqual(s3Client.inputs.map(\.bucket), Array(repeating: "status-bucket", count: expectedCount))
        XCTAssertEqual(
            s3Client.inputs.map(\.cacheControl),
            Array(repeating: S3TorpinStatusCache.cacheControl, count: expectedCount)
        )
        XCTAssertEqual(
            s3Client.inputs.map(\.contentType),
            Array(repeating: S3TorpinStatusCache.contentType, count: expectedCount)
        )
        XCTAssertEqual(s3Client.inputs.map(\.key), S3TorpinStatusCache.keys)

        let bodies = try await s3Client.inputs.asyncMap { input in
            try await input.body?.readData()
        }
        XCTAssertEqual(
            bodies,
            Array(repeating: #"{"isBrianTorpin":true}"#.data(using: .utf8), count: expectedCount)
        )
    }
}

private final class MockS3Client: S3Putting, @unchecked Sendable {
    private(set) var inputs: [PutObjectInput] = []

    func putObject(input: PutObjectInput) async throws -> PutObjectOutput {
        inputs.append(input)
        return PutObjectOutput()
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values: [T] = []
        for element in self {
            let value = try await transform(element)
            values.append(value)
        }
        return values
    }
}
