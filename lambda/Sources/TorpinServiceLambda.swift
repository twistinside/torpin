import AWSLambdaRuntime

struct Input: Codable {
	let number: Double
}

struct TorpinResult: Codable {
	let isBrianTorpin: Bool
}

@main
struct TorpinServiceLambda: SimpleLambdaHandler {
	typealias Event = Input
	typealias Output = TorpinResult

	let steamClient = SteamClient()

	func handle(_ event: Event, context: LambdaContext) async throws -> Output {
		LogManager.initialize(from: context)
		LogManager.shared.info("Event received: \(event)")
		let isBrianTorpin = try await steamClient.isBrianTorpin()
		return TorpinResult(isBrianTorpin: isBrianTorpin)
	}
}
