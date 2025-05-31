import AWSLambdaRuntime
import AWSLambdaEvents
import Common
import Foundation
import HTTPTypes

struct TorpinResult: Codable {
    let isBrianTorpin: Bool
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
        let bodyData = try JSONEncoder().encode(result)
        let body = String(decoding: bodyData, as: UTF8.self)
        let response = APIGatewayResponse(
            statusCode: HTTPResponse.Status(200),
            headers: [
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json"
            ],
            body: body
        )
        LogManager.shared.info("Response: \(response)")
        return response;
    }
}
