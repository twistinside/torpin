@preconcurrency import AWSDynamoDB
import AWSS3
import AWSLambdaEvents
import AWSLambdaRuntime
import Common
import Foundation

protocol RecordTableWriting: Sendable {
    func add(_ record: TorpinRecord) async throws
}

protocol SessionManaging: Sendable {
    func closeActiveSession(at date: Date) async throws
    func createSession(at date: Date) async throws
    func hasActiveSession() async throws -> Bool
}

protocol SteamTorpinChecking: Sendable {
    func isBrianTorpin() async throws -> Bool
}

enum EventHandlerAction: Equatable {
    case closeActiveSession
    case createSession
    case noOp
}

struct EventHandler {
    let recordTable: RecordTableWriting
    let sessionManager: SessionManaging
    let statusCache: TorpinStatusCaching
    let steamClient: SteamTorpinChecking

    static func action(isTorpin: Bool, hasActiveSession: Bool) -> EventHandlerAction {
        switch (isTorpin, hasActiveSession) {
        case (false, true):
            return .closeActiveSession
        case (true, false):
            return .createSession
        default:
            return .noOp
        }
    }

    func handle(_ event: EventBridgeEvent<CloudwatchDetails.Scheduled>, context: LambdaContext) async throws {
        _ = event
        LogManager.initialize(from: context)
        let date = Date()

        async let torpin = steamClient.isBrianTorpin()
        async let active = sessionManager.hasActiveSession()
        let (isTorpin, hasActive) = try await (torpin, active)

        try await updateRecords(isTorpin: isTorpin, hasActiveSession: hasActive, at: date)
    }

    func updateRecords(isTorpin: Bool, hasActiveSession hasActive: Bool, at date: Date) async throws {
        switch Self.action(isTorpin: isTorpin, hasActiveSession: hasActive) {
        case .closeActiveSession:
            try await sessionManager.closeActiveSession(at: date)
        case .createSession:
            try await sessionManager.createSession(at: date)
        case .noOp:
            break
        }

        let torpinRecord = TorpinRecord(date: date, torpin: isTorpin)
        _ = try await recordTable.add(torpinRecord)
        try await statusCache.putStatus(isBrianTorpin: isTorpin)
    }
}

extension RecordTable: RecordTableWriting {}
extension SessionManager: SessionManaging {}
extension SteamClient: SteamTorpinChecking {}
extension EventHandler: Sendable {}

@main
struct EventHandlerV2Lambda {
    private static let region = "us-west-1"
    private static let statusCacheBucketName = ProcessInfo.processInfo.environment["STATUS_CACHE_BUCKET"] ?? ""
    private static let tableName = ProcessInfo.processInfo.environment["TABLE_NAME"] ?? "Torpin"

    static func main() async throws {
        guard !self.statusCacheBucketName.isEmpty else {
            throw EventHandlerConfigurationError.missingStatusCacheBucket
        }

        let dynamoConfig = try await DynamoDBClient.DynamoDBClientConfig(region: self.region)
        let dynamoClient = DynamoDBClient(config: dynamoConfig)
        let s3Client = try S3Client(region: self.region)
        let eventHandler = EventHandler(
            recordTable: RecordTable(client: dynamoClient, tableName: self.tableName),
            sessionManager: SessionManager(client: dynamoClient, tableName: self.tableName),
            statusCache: S3TorpinStatusCache(bucketName: self.statusCacheBucketName, s3Client: s3Client),
            steamClient: SteamClient()
        )
        let runtime = LambdaRuntime {
            (event: EventBridgeEvent<CloudwatchDetails.Scheduled>, context: LambdaContext) async throws in
            try await eventHandler.handle(event, context: context)
        }
        try await runtime.run()
    }
}

enum EventHandlerConfigurationError: Error {
    case missingStatusCacheBucket
}
