import AWSDynamoDB
import AWSLambdaEvents
import AWSLambdaRuntime
import AsyncHTTPClient
import Common
import Foundation

@main
struct EventHandlerLambda: LambdaHandler {
    typealias In = EventBridgeEvent<CloudwatchDetails.Scheduled>
    typealias Out = Void

    let recordTable: RecordTable
    let region = "us-west-1"
    let steamClient: SteamClient
    
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
        await Self.warmAPI()
    }

    static func warmAPI() async {
        guard let url = ProcessInfo.processInfo.environment["TORPIN_API_URL"] else {
            LogManager.shared.info("TORPIN_API_URL not set")
            return
        }

        var request = HTTPClientRequest(url: url)
        request.method = .GET

        do {
            let response = try await HTTPClient.shared.execute(request, timeout: .seconds(5))
            LogManager.shared.info("Warm API status: \(response.status)")
        } catch {
            LogManager.shared.error("Warm API call failed: \(error)")
        }
    }
}
