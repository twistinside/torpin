import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import HTTPTypes

struct TorpinResult: Codable, CustomStringConvertible {
	let isBrianTorpin: Bool
	var description: String {
		return "{isBrianTorpin: \(isBrianTorpin)}"
	}
}

@main
struct TorpinServiceLambda: SimpleLambdaHandler {
	
	typealias Event = APIGatewayRequest
	typealias Output = APIGatewayResponse

	let decoder = JSONDecoder()
	let steamClient = SteamClient()

	func handle(_ event: Event, context: LambdaContext) async throws -> Output {
		LogManager.initialize(from: context)
		LogManager.shared.info("Event received: \(event)")
		let isBrianTorpin = try await steamClient.isBrianTorpin()
		let result = TorpinResult(isBrianTorpin: isBrianTorpin)		
		return APIGatewayResponse(statusCode: HTTPResponse.Status(200) ,body: "\(result)");
	}
}
