import XCTest
import Common
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

    func testUpdateRecordsWritesTorpinStatusCache() async throws {
        let cache = MockStatusCache()
        let eventHandler = EventHandler(
            recordTable: MockRecordTable(),
            sessionManager: MockSessionManager(),
            statusCache: cache,
            steamClient: MockSteamClient()
        )

        try await eventHandler.updateRecords(
            isTorpin: true,
            hasActiveSession: false,
            at: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(cache.statuses, [true])
    }
}

private final class MockRecordTable: RecordTableWriting, @unchecked Sendable {
    func add(_ record: TorpinRecord) async throws {
        _ = record
    }
}

private final class MockSessionManager: SessionManaging, @unchecked Sendable {
    func closeActiveSession(at date: Date) async throws {
        _ = date
    }

    func createSession(at date: Date) async throws {
        _ = date
    }

    func hasActiveSession() async throws -> Bool {
        false
    }
}

private final class MockStatusCache: TorpinStatusCaching, @unchecked Sendable {
    private(set) var statuses: [Bool] = []

    func putStatus(isBrianTorpin: Bool) async throws {
        statuses.append(isBrianTorpin)
    }
}

private final class MockSteamClient: SteamTorpinChecking, @unchecked Sendable {
    func isBrianTorpin() async throws -> Bool {
        false
    }
}
