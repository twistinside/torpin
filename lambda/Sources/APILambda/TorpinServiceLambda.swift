import AWSLambdaRuntime
import AWSLambdaEvents
import Common
import AWSDynamoDB
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

    let region = "us-west-1"
    let sessionManager: SessionManager

    init(context: LambdaInitializationContext) async throws {
        LogManager.initialize(from: context)
        let config = try await DynamoDBClient.DynamoDBClientConfiguration()
        config.region = self.region
        let client = DynamoDBClient(config: config)
        self.sessionManager = SessionManager(client: client)
    }

    func handle(_ event: In, context: LambdaContext) async throws -> Out {
        LogManager.shared.info("Event received: \(event)")
        let isBrianTorpin = try await sessionManager.hasActiveSession()
        let result = TorpinResult(isBrianTorpin: isBrianTorpin)
        return APIGatewayResponse(
            statusCode: HTTPResponse.Status(200),
            body: "\(result)"
        )
    }
}
