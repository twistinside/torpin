import AWSLambdaRuntime
import AWSLambdaEvents
import Common
import Foundation

@main
struct EventHandlerLambda: SimpleLambdaHandler {
    typealias Event = EventBridgeEvent<CloudwatchDetails.Scheduled>
    typealias Output = Void

    let steamClient = SteamClient()

    func handle(_ event: Event, context: LambdaContext) async throws {
        LogManager.initialize(from: context)
        LogManager.shared.info("Event triggered")
        let isBrianTorpin = try await steamClient.isBrianTorpin()
        LogManager.shared.info("Brian is torpin: \(isBrianTorpin)")
    }
}
