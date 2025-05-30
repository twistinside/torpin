import AsyncHTTPClient
import Foundation

public class SteamClient {
	
	let decoder = JSONDecoder()
	var steamID: String? = ProcessInfo.processInfo.environment["STEAM_ID"];
	var steamKey: String? = ProcessInfo.processInfo.environment["STEAM_API_KEY"];
	
	public init() { }
	
	public func isBrianTorpin() async throws -> Bool {
		guard let steamKey else {
			LogManager.shared.error("No steam key present in environment")
			return false
		}
		
		guard let steamID else {
			LogManager.shared.error("No steam ID present in environment")
			return false
		}
		
		LogManager.shared.info("Steam ID from environment: \(steamID)")
		LogManager.shared.info("Steam key from environment: \(steamKey)")
		
		var request = HTTPClientRequest(url: "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=\(steamKey)&steamids=\(steamID)")
		request.method = .GET
		request.headers.add(name: "Accept-Encoding", value: "identity")
		
		let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
		guard response.status == .ok else {
			LogManager.shared.error("Error: Received status code \(response.status)")
			return false
		}
		
		let body = try await response.body.collect(upTo: 1024 * 1024) // 1 MB
		guard let data = body.getBytes(at: 0, length: body.readableBytes) else {
			LogManager.shared.error("Failed to collect response body")
			return false
		}
		
		LogManager.shared.info("Steam body: \(body)")
		
		let steamResponse: SteamResponse
		do {
			steamResponse = try decoder.decode(SteamResponse.self, from: Data(data))
		} catch {
			LogManager.shared.error("Failed to decode JSON: \(error)")
			return false
		}
		
		LogManager.shared.info("Steam response: \(steamResponse)")
		
		// Access and use the decoded data
		guard let player = steamResponse.response.players.first, let gameId = player.gameid else {
			LogManager.shared.info("No player found or no game ID present")
			return false
		} 
		
		return gameId == "552990"
	}
}

extension SteamClient: @unchecked Sendable {}

struct SteamResponse: Codable {
	let response: PlayersResponse
}

struct PlayersResponse: Codable {
	let players: [Player]
}

struct Player: Codable {
	let avatar: String
	let avatarfull: String
	let avatarhash: String
	let avatarmedium: String
	let communityvisibilitystate: Int
	let gameextrainfo: String?
	let gameid: String?
	let lastlogoff: Int
	let loccountrycode: String
	let personaname: String
	let personastate: Int
	let personastateflags: Int
	let primaryclanid: String
	let profilestate: Int
	let profileurl: String
	let steamid: String
	let timecreated: Int
}
