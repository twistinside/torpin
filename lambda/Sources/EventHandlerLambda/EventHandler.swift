import AWSLambdaRuntime
import AWSLambdaEvents
import Common
import Foundation

@main
struct EventHandlerLambda: LambdaHandler {
    typealias In = EventBridgeEvent<CloudwatchDetails.Scheduled>
    typealias Out = Void
    
    let steamClient: SteamClient
    let recordTable: RecordTable
    
    init(context: LambdaInitializationContext) async throws {
        LogManager.initialize(from: context)
        self.steamClient = SteamClient()
        self.recordTable = RecordTable()
    }
    
    func handle(_ event: In, context: LambdaContext) async throws -> Out {
        LogManager.shared.info("Event triggered")
        let torpin = try await steamClient.isBrianTorpin()
        let torpinRecord = TorpinRecord(date: Date(), torpin: torpin)
        _ = try await recordTable.add(torpinRecord)
        LogManager.shared.info("Brian is torpin: \(torpin)")
    }
}
