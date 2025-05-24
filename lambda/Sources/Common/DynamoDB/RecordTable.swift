import AWSDynamoDB

public class RecordTable {
    private let tableName = "Torpin"

    private let client: DynamoDBClient

    public init(client: DynamoDBClient) {
        self.client = client
    }

    public func add(_ record: TorpinRecord) async throws {
        let item = try await record.getAsItem()

        let input = PutItemInput(
            item: item,
            tableName: self.tableName
        )
        _ = try await client.putItem(input: input)
        LogManager.shared.info("Put item: \(input)")
    }
}