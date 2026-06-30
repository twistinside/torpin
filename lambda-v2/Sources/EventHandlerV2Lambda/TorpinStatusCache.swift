import AWSS3
import Foundation
import Smithy

protocol S3Putting: Sendable {
    func putObject(input: PutObjectInput) async throws -> PutObjectOutput
}

protocol TorpinStatusCaching: Sendable {
    func putStatus(isBrianTorpin: Bool) async throws
}

struct TorpinStatusDocument: Encodable, Equatable {
    let isBrianTorpin: Bool
}

struct S3TorpinStatusCache {
    static let cacheControl = "public, max-age=60, s-maxage=60"
    static let contentType = "application/json"
    static let keys = ["v2", "v2/"]

    private let bucketName: String
    private let encoder: JSONEncoder
    private let s3Client: S3Putting

    init(bucketName: String, s3Client: S3Putting) {
        self.bucketName = bucketName
        self.encoder = JSONEncoder()
        self.s3Client = s3Client
    }

    func putStatus(isBrianTorpin: Bool) async throws {
        let document = TorpinStatusDocument(isBrianTorpin: isBrianTorpin)
        let data = try encoder.encode(document)

        for key in Self.keys {
            let input = PutObjectInput(
                body: .data(data),
                bucket: bucketName,
                cacheControl: Self.cacheControl,
                contentType: Self.contentType,
                key: key
            )
            _ = try await s3Client.putObject(input: input)
        }
    }
}

extension S3Client: S3Putting {}
extension S3TorpinStatusCache: TorpinStatusCaching {}
