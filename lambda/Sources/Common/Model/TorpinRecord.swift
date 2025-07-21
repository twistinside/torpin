import AWSDynamoDB
import Foundation

public struct TorpinRecord: Codable {
    public let date: Date
    public let torpin: Bool

    let recordType: RecordType

    public init(date: Date, torpin: Bool) {
        self.date = date
        self.recordType = .torpinRecord
        self.torpin = torpin
    }

    init(withItem item: [String:DynamoDBClientTypes.AttributeValue]) throws  {
        guard let dateAttribute = item["date"],
              let recordTypeAttribute = item["recordType"] else {
            throw RecordError.ItemNotFound
        }
        let torpinAttribute = item["torpin"]

        if case .s(let rawValue) = dateAttribute, let date = ISO8601DateFormatter().date(from: rawValue) {
            self.date = date
        } else {
            throw RecordError.InvalidAttributes
        }

        if case .s(let rawValue) = recordTypeAttribute, let parsedType = RecordType(rawValue: rawValue) {
            self.recordType = parsedType
        } else {
            throw RecordError.InvalidAttributes
        }

        if case .bool(let torpin) = torpinAttribute {
            self.torpin = torpin
        } else {
            throw RecordError.InvalidAttributes
        }
    }

    func getAsItem() async throws -> [Swift.String:DynamoDBClientTypes.AttributeValue]  {
        let iso = ISO8601DateFormatter()
        let dateAttribute = iso.string(from: date)
        let item: [Swift.String:DynamoDBClientTypes.AttributeValue] = [
            "date": .s(dateAttribute),
            "recordType": .s(self.recordType.rawValue),
            "torpin": .bool(self.torpin)
        ]
        return item
    }
 }