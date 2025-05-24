import AWSLambdaRuntime
import AWSLambdaEvents
import Common
import Foundation
import HTTPTypes

struct TorpinResult: Codable, CustomStringConvertible {
    let isBrianTorpin: Bool
    var description: String {
        return "{\"isBrianTorpin\": \(isBrianTorpin)}"
    }
}

@main
struct TorpinServiceLambda: LambdaHandler {
    typealias In = APIGatewayRequest
    typealias Out = APIGatewayResponse

    let steamClient: SteamClient

    init(context: LambdaInitializationContext) async throws {
        LogManager.initialize(from: context)
        self.steamClient = SteamClient()
    }

    func handle(_ event: In, context: LambdaContext) async throws -> Out {
        LogManager.shared.info("Event received: \(event)")
        let isBrianTorpin = try await steamClient.isBrianTorpin()
        let result = TorpinResult(isBrianTorpin: isBrianTorpin)
        return APIGatewayResponse(
            statusCode: HTTPResponse.Status(200),
            body: "\(result)"
        )
    }
}
