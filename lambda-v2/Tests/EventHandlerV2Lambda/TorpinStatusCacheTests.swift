import AWSS3
import XCTest
@testable import EventHandlerV2Lambda

final class TorpinStatusCacheTests: XCTestCase {
    func testPutStatusWritesBothStaticEndpointObjects() async throws {
        let s3Client = MockS3Client()
        let cache = S3TorpinStatusCache(bucketName: "status-bucket", s3Client: s3Client)

        try await cache.putStatus(isBrianTorpin: true)

        XCTAssertEqual(s3Client.inputs.map(\.bucket), ["status-bucket", "status-bucket"])
        XCTAssertEqual(s3Client.inputs.map(\.cacheControl), [
            S3TorpinStatusCache.cacheControl,
            S3TorpinStatusCache.cacheControl,
        ])
        XCTAssertEqual(s3Client.inputs.map(\.contentType), [
            S3TorpinStatusCache.contentType,
            S3TorpinStatusCache.contentType,
        ])
        XCTAssertEqual(s3Client.inputs.map(\.key), S3TorpinStatusCache.keys)

        let bodies = try await s3Client.inputs.asyncMap { input in
            try await input.body?.readData()
        }
        XCTAssertEqual(bodies, [
            #"{"isBrianTorpin":true}"#.data(using: .utf8),
            #"{"isBrianTorpin":true}"#.data(using: .utf8),
        ])
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
