@preconcurrency import AWSDynamoDB
import Foundation

public actor SessionManager {
    private nonisolated let tableName = "Torpin"
    private nonisolated let client: DynamoDBClient

    public init(client: DynamoDBClient) {
        self.client = client
    }

    public func hasActiveSession() async throws -> Bool {
        return try await getActiveSession() != nil
    }

    public func createSession(at date: Date) async throws {
        LogManager.shared.info("Creating session")
        let record = SessionRecord(startDate: date)
        let item = try await record.getAsItem()
        LogManager.shared.info("Using item: \(item)")
        let input = PutItemInput(item: item, tableName: tableName)
        LogManager.shared.info("Using input: \(input)")
        _ = try await client.putItem(input: input)
        LogManager.shared.info("Created session starting at \(date)")
    }

    public func closeActiveSession(at date: Date) async throws {
        guard let session = try await getActiveSession() else { return }
        let iso = ISO8601DateFormatter()
        let key: [String:DynamoDBClientTypes.AttributeValue] = [
            "recordType": .s(RecordType.sessionRecord.rawValue),
            "date": .s(iso.string(from: session.startDate))
        ]
        let values: [String:DynamoDBClientTypes.AttributeValue] = [
            ":endDate": .s(iso.string(from: date))
        ]
        let input = UpdateItemInput(
            expressionAttributeValues: values,
            key: key,
            tableName: tableName,
            updateExpression: "SET endDate = :endDate"
        )
        _ = try await client.updateItem(input: input)
        LogManager.shared.info("Closed session starting at \(session.startDate)")
    }

    private func getActiveSession() async throws -> SessionRecord? {
        LogManager.shared.info("Getting active session")
        let values: [String:DynamoDBClientTypes.AttributeValue] = [
            ":recordType": .s(RecordType.sessionRecord.rawValue)
        ]
        let input = QueryInput(
            expressionAttributeValues: values,
            keyConditionExpression: "recordType = :recordType",
            tableName: tableName
        )
        LogManager.shared.info("Using input: \(input)")
        let output = try await client.query(input: input)
        LogManager.shared.info("Received output: \(output)")
        let items = output.items ?? []
        for item in items {
            if item["endDate"] == nil {
                return try SessionRecord(withItem: item)
            }
        }
        return nil
    }
}

extension SessionManager: @unchecked Sendable {}
