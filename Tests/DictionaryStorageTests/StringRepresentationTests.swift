//
//  Created by Kazuho Okui on 3/17/24.
//

import DictionaryStorage
import XCTest

@StringRawRepresentation
public enum InputType {
    case text
    case email
    case password
    @CustomName("select-one") case option
    case unknown(String)
}

final class StringRepresentationTests: XCTestCase {

    func testExample() throws {

        XCTAssertEqual(InputType(rawValue: "email"), .email)
        XCTAssertEqual(InputType(rawValue: "text"), .text)
        XCTAssertEqual(InputType(rawValue: "custom"), .unknown("custom"))
        XCTAssertEqual(InputType(rawValue: "select-one"), .option)
        XCTAssertEqual(InputType(rawValue: "password"), .password)

    }
}
