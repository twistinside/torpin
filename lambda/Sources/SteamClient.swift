import AsyncHTTPClient
import Compression
import Foundation

class SteamClient {
	
	let decoder = JSONDecoder()
	
	func networkCall() async throws -> Bool {
		var request = HTTPClientRequest(url: "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=D655A1F05B7643475CFB35BCFAEAB374&steamids=76561197978678172")
		request.method = .GET
		request.headers.add(name: "Accept-Encoding", value: "identity")
		
		let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
		guard response.status == .ok else {
			print("Error: Received status code \(response.status)")
			return false
		}
		
		let body = try await response.body.collect(upTo: 1024 * 1024) // 1 MB
		guard let data = body.getBytes(at: 0, length: body.readableBytes) else {
			print("Failed to collect response body")
			return false
		}
		
		let decoder = JSONDecoder()
		let steamResponse: SteamResponse
		do {
			steamResponse = try decoder.decode(SteamResponse.self, from: Data(data))
		} catch {
			print("Failed to decode JSON: \(error)")
			return false
		}
		
		// Access and use the decoded data
		guard let player = steamResponse.response.players.first,
		let gameId = player.gameid else {
			return false
		} 
		
		return gameId == 552990
	}
}

struct SteamResponse: Codable {
	let response: PlayersResponse
}

// Response containing players
struct PlayersResponse: Codable {
	let players: [Player]
}

// Player object
struct Player: Codable {
	let avatar: String
	let avatarfull: String
	let avatarhash: String
	let avatarmedium: String
	let communityvisibilitystate: Int
	let gameextrainfo: String?
	let gameid: Int?
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