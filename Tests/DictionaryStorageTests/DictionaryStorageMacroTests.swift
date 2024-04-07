import DictionaryStorage
import XCTest

@DictionaryStorage(.hashable)
struct Location {
    var latitude: Double = 0
    var longitude: Double = 0

    // swiftlint:disable:next unneeded_synthesized_initializer
    init(latitude: Double = 0, longitude: Double = 0) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

typealias UserId = UUID

@DictionaryStorage(.hashable)
struct Test {

    enum `Type`: String, Codable {
        case text, email
    }

    var `type`: `Type` = .text
    var `var`: Int = 0
    var loc: Location = Location()
    var location: Location?
    var history: [Location] = []
    var username: String = ""
    var data: Data?
    var changedAt: Date = Date()
    var createdAt: Date?
    var credId: UUID = UUID()
    @DictionaryStorageProperty("userId")
    var _userId: UUID = UUID()
    var userId: UserId? {
        return _userId
    }
}

final class DictionaryMacroTests: XCTestCase {

    func testMacro() throws {
        let data =
            """
            {
                "type" : "email",
                "var" : 100,
                "location" : { "latitude" : 10.5, "longitude": 12.3 },
                "history" : [
                    { "latitude" : 50, "longitude": 60 },
                    { "latitude" : 100, "longitude": 200 },
                ],
                "changedAt" : 1686950333,
                "username" : "kaz@naan.net",
                "data" : "QUJDREVGR0hJSktMTU4=",
                "credId" : "73FA4758-5D5E-42DC-A368-02AF72D69467",
                "userId" : "8F416357-853F-40BA-A6A9-5537B5A72225"
            }
            """.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssert(json != nil)
        let test = Test(json!)
        XCTAssert(test.type == .email)
        XCTAssert(test.var == 100)
        XCTAssert(test.loc == Location())
        XCTAssert(test.location == Location(latitude: 10.5, longitude: 12.3))
        XCTAssertEqual(test.history.count, 2)
        XCTAssertEqual(test.history[0].latitude, 50)
        XCTAssertEqual(test.history[0].longitude, 60)
        XCTAssertEqual(test.history[1].latitude, 100)
        XCTAssertEqual(test.history[1].longitude, 200)

        XCTAssert(test.username == "kaz@naan.net")
        XCTAssertEqual(String(data: test.data!, encoding: .utf8), "ABCDEFGHIJKLMN")
        XCTAssert(test.changedAt.timeIntervalSince1970 == 1_686_950_333)
        XCTAssert(test.createdAt == nil)
        XCTAssert(test.credId == UUID(uuidString: "73FA4758-5D5E-42DC-A368-02AF72D69467"))
        XCTAssert(test.userId == UUID(uuidString: "8F416357-853F-40BA-A6A9-5537B5A72225"))

        var test2 = Test(json!)
        XCTAssertEqual(test, test2)
        test2.username = "kaz@example.com"
        XCTAssertNotEqual(test, test2)

        test2.type = .text
        test2.var = 200
        XCTAssertEqual(test2.rawDictionary["type"] as? String, "text")
        XCTAssertEqual(test2.rawDictionary["var"] as? Int, 200)
    }
}
