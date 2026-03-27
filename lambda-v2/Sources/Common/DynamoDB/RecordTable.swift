import AWSDynamoDB
import Foundation

public class RecordTable {
    private let client: DynamoDBClient
    private let tableName: String

    public init(
        client: DynamoDBClient,
        tableName: String = ProcessInfo.processInfo.environment["TABLE_NAME"] ?? "Torpin"
    ) {
        self.client = client
        self.tableName = tableName
    }

    public func add(_ record: TorpinRecord) async throws {
        let item = try await record.getAsItem()

        let input = PutItemInput(
            item: item,
            tableName: self.tableName
        )
        _ = try await client.putItem(input: input)
    }
}

extension RecordTable: @unchecked Sendable {}
