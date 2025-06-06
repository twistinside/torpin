import AWSLambdaRuntime
import AWSLambdaEvents
import Common
import AWSDynamoDB
import Foundation
import HTTPTypes

struct TorpinResult: Codable {
    let isBrianTorpin: Bool
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
