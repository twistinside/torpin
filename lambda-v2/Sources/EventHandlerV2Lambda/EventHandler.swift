@preconcurrency import AWSDynamoDB
import AWSLambdaEvents
import AWSLambdaRuntime
import Common
import Foundation

enum EventHandlerAction: Equatable {
    case closeActiveSession
    case createSession
    case noOp
}

struct EventHandler {
    let recordTable: RecordTable
    let sessionManager: SessionManager
    let steamClient: SteamClient

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
    }
}

extension EventHandler: Sendable {}

@main
struct EventHandlerV2Lambda {
    private static let region = "us-west-1"
    private static let tableName = ProcessInfo.processInfo.environment["TABLE_NAME"] ?? "Torpin"

    static func main() async throws {
        let config = try await DynamoDBClient.DynamoDBClientConfig(region: self.region)
        let client = DynamoDBClient(config: config)
        let eventHandler = EventHandler(
            recordTable: RecordTable(client: client, tableName: self.tableName),
            sessionManager: SessionManager(client: client, tableName: self.tableName),
            steamClient: SteamClient()
        )
        let runtime = LambdaRuntime {
            (event: EventBridgeEvent<CloudwatchDetails.Scheduled>, context: LambdaContext) async throws in
            try await eventHandler.handle(event, context: context)
        }
        try await runtime.run()
    }
}
