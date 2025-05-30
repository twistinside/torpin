import AWSDynamoDB
import Foundation

public struct SessionRecord: Codable {
    var endDate: Date?
    let recordType: RecordType
    let startDate: Date

    public init(startDate: Date, endDate: Date? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.recordType = .sessionRecord
    }

    init(withItem item: [String:DynamoDBClientTypes.AttributeValue]) throws  {
        let iso = ISO8601DateFormatter()
        guard let dateAttribute = item["startDate"],
              let recordTypeAttribute = item["recordType"] else {
            throw RecordError.ItemNotFound
        }
        if case .s(let rawValue) = dateAttribute, let date = iso.date(from: rawValue) {
            self.startDate = date
        } else {
            throw RecordError.InvalidAttributes
        }

        if case .s(let rawValue) = recordTypeAttribute, let parsedType = RecordType(rawValue: rawValue) {
            self.recordType = parsedType
        } else {
            throw RecordError.InvalidAttributes
        }

        if let endDateAttribute = item["endDate"] {
            if case .s(let rawValue) = endDateAttribute, let end = iso.date(from: rawValue) {
                self.endDate = end
            } else {
                throw RecordError.InvalidAttributes
            }
        } else {
            self.endDate = nil
        }
    }

    func getAsItem() async throws -> [Swift.String:DynamoDBClientTypes.AttributeValue]  {
        let iso = ISO8601DateFormatter()
        var item: [Swift.String:DynamoDBClientTypes.AttributeValue] = [
            "startDate": .s(iso.string(from: startDate)),
            "recordType": .s(self.recordType.rawValue),
        ]
        if let endDate {
            item["endDate"] = .s(iso.string(from: endDate))
        }
        return item
    }
}
