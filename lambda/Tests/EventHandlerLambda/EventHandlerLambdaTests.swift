import XCTest
@testable import EventHandlerLambda

final class EventHandlerLambdaTests: XCTestCase {
    func testWarmAPIWithoutEnv() async {
        unsetenv("TORPIN_API_URL")
        await EventHandlerLambda.warmAPI()
    }
}
