import XCTest
@testable import EventHandlerV2Lambda

final class EventHandlerTests: XCTestCase {
    func testActionReturnsCloseActiveSessionWhenNotTorpinAndSessionActive() {
        XCTAssertEqual(
            EventHandler.action(isTorpin: false, hasActiveSession: true),
            .closeActiveSession
        )
    }

    func testActionReturnsCreateSessionWhenTorpinAndNoSessionActive() {
        XCTAssertEqual(
            EventHandler.action(isTorpin: true, hasActiveSession: false),
            .createSession
        )
    }

    func testActionReturnsNoOpWhenNotTorpinAndNoSessionActive() {
        XCTAssertEqual(
            EventHandler.action(isTorpin: false, hasActiveSession: false),
            .noOp
        )
    }

    func testActionReturnsNoOpWhenTorpinAndSessionActive() {
        XCTAssertEqual(
            EventHandler.action(isTorpin: true, hasActiveSession: true),
            .noOp
        )
    }
}
