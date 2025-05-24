import AWSDynamoDB
import AWSLambdaRuntime
import AWSLambdaEvents
import Common
import Foundation

@main
struct EventHandlerLambda: LambdaHandler {
    typealias In = EventBridgeEvent<CloudwatchDetails.Scheduled>
    typealias Out = Void

    let region = "us-west-2"

    let steamClient: SteamClient
    let recordTable: RecordTable
    
    init(context: LambdaInitializationContext) async throws {
        LogManager.initialize(from: context)
        self.steamClient = SteamClient()
        let config = try await DynamoDBClient.DynamoDBClientConfiguration()
        config.region = self.region
        let client = DynamoDBClient(config: config)
        self.recordTable = RecordTable(client: client)
    }
    
    func handle(_ event: In, context: LambdaContext) async throws -> Out {
        LogManager.shared.info("Event triggered")
        let torpin = try await steamClient.isBrianTorpin()
        let torpinRecord = TorpinRecord(date: Date(), torpin: torpin)
        _ = try await recordTable.add(torpinRecord)
        LogManager.shared.info("Brian is torpin: \(torpin)")
    }
}
