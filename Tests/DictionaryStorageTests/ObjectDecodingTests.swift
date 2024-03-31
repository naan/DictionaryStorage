//
//  Created by Kazuho Okui on 3/17/24.
//

import DictionaryStorage
import XCTest

@DictionaryStorage(.equatable)
struct Web {
    var type: Usage.UsageType = .web
    var name: String = ""
    var url: String = ""
}

@DictionaryStorage(.equatable)
struct App {
    var type: Usage.UsageType = .app
    var name: String = ""
    var bundleId: String = ""
}

struct Usage: DictionaryRepresentable {
    enum UsageType: String {
        case web
        case app
        case unknown
    }

    enum Value {
        case web(Web)
        case app(App)
        case unknown([String: Any])
    }

    var value: Value
    let type: UsageType
    var _storage: [String: Any]

    var rawDictionary: [String: Any] {
        _storage
    }

    init(_ dictionary: [String: Any]) {
        self._storage = dictionary
        if let typeString = dictionary["type"] as? String, let type = UsageType(rawValue: typeString) {
            self.type = type
            switch type {
            case .web:
                value = .web(Web(dictionary))
            case .app:
                value = .app(App(dictionary))
            case .unknown:
                value = .unknown(dictionary)
            }
        } else {
            self.type = .unknown
            value = .unknown(dictionary)
        }
    }
}

@DictionaryStorage
struct Object {
    var usages: [Usage] = []
}

final class ObjectTest: XCTestCase {
    func testMacro() throws {
        let data =
            """
            {
                "usages" : [
                    {
                        "type": "web",
                        "name": "Example.com",
                        "url": "https://www.example.com",
                    },
                    {
                        "type": "web",
                        "name": "Apple",
                        "url": "https://www.apple.com",
                    },
                    {
                        "type": "app",
                        "name": "Google",
                        "bundleId": "com.google.android",
                    },
                    {
                        "type": "alias",
                        "name": "Apple",
                    },
                    {
                        "name": "Google",
                    },
                ]
            }
            """.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        assert(json != nil)
        let test = Object(json!)
        XCTAssert(test.usages.count == 5)
        XCTAssert(test.usages[0].type == .web)
        if case let .web(web) = test.usages[0].value {
            XCTAssert(web.type == .web)
            XCTAssert(web.name == "Example.com")
            XCTAssert(web.url == "https://www.example.com")
        } else {
            XCTAssert(false)
        }

        if case let .app(app) = test.usages[2].value {
            XCTAssert(app.type == .app)
            XCTAssert(app.name == "Google")
            XCTAssert(app.bundleId == "com.google.android")
        } else {
            XCTAssert(false)
        }

        if case let .unknown(alias) = test.usages[3].value {
            XCTAssert(alias["type"] as? String == "alias")
            XCTAssert(alias["name"] as? String == "Apple")
        } else {
            XCTAssert(false)
        }

        var web = test.usages
            .compactMap {
                if case let .web(web) = $0.value {
                    return web
                } else {
                    return nil
                }
            }
        XCTAssert(web.count == 2)
        web[0].name = "My URL"

    }

    func testCodable() throws {
        let data =
            """
            {
                "location" : { "latitude" : 1.11, "longitude" : 2.3 },
                "changedAt" : 1686950333,
                "username" : "kaz@naan.net",
                "credId" : "73FA4758-5D5E-42DC-A368-02AF72D69467",
                "userIds" : ["73FA4758-5D5E-42DC-A368-02AF72D69467", "8F416357-853F-40BA-A6A9-5537B5A72225"]
            }
            """.data(using: .utf8)!

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)

        let location = DictionaryStorage.decode(Location.self, value: json!["location"])
        XCTAssertEqual(location?.latitude, 1.11)
        XCTAssertEqual(location?.longitude, 2.3)

        let locData = DictionaryStorage.encode(location)
        XCTAssertEqual(locData as? [String: Double], ["latitude": 1.11, "longitude": 2.3])

        let dateValue = DictionaryStorage.decode(Date.self, value: json!["changedAt"])
        XCTAssertEqual(dateValue?.timeIntervalSince1970, 1_686_950_333)

        let dateData = DictionaryStorage.encode(dateValue)
        XCTAssertEqual(dateData as? Double, 1_686_950_333)

        let uuidValue = DictionaryStorage.decode(UUID.self, value: json!["credId"])
        XCTAssertEqual(uuidValue?.uuidString, "73FA4758-5D5E-42DC-A368-02AF72D69467")

        let uuidData = DictionaryStorage.encode(uuidValue)
        XCTAssertEqual(uuidData as? String, "73FA4758-5D5E-42DC-A368-02AF72D69467")
    }
}
