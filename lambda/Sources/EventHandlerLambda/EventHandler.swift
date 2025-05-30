import AWSDynamoDB
import AWSLambdaRuntime
import AWSLambdaEvents
import Common
import Foundation

@main
struct EventHandlerLambda: LambdaHandler {
    typealias In = EventBridgeEvent<CloudwatchDetails.Scheduled>
    typealias Out = Void

    let region = "us-west-1"

    let steamClient: SteamClient
    let recordTable: RecordTable
    let sessionManager: SessionManager
    
    init(context: LambdaInitializationContext) async throws {
        LogManager.initialize(from: context)
        self.steamClient = SteamClient()
        let config = try await DynamoDBClient.DynamoDBClientConfiguration()
        config.region = self.region
        let client = DynamoDBClient(config: config)
        self.recordTable = RecordTable(client: client)
        self.sessionManager = SessionManager(client: client)
    }
    
    func handle(_ event: In, context: LambdaContext) async throws -> Out {
        LogManager.shared.info("Event triggered")
        async let torpin = steamClient.isBrianTorpin()
        async let activeSession = sessionManager.hasActiveSession()
        let (torpin, hasActive) = try await (torpin, activeSession)
        let torpinRecord = TorpinRecord(date: Date(), torpin: torpin)
        _ = try await recordTable.add(torpinRecord)

        switch (torpin, hasActive) {
        case (true, false):
            try await sessionManager.createSession(at: torpinRecord.date)
        case (false, true):
            try await sessionManager.closeActiveSession(at: torpinRecord.date)
        default:
            break
        }

        LogManager.shared.info("Brian is torpin: \(torpin)")
    }
}
