@main
struct TorpinService {
	static func main() async {		
		let steamClient = SteamClient()
		
		do {
			let brianIsTorpin = try await steamClient.networkCall()
			print("Brian is torpin: \(brianIsTorpin)")
		} catch {
			print("It broke")
		}
	}
}