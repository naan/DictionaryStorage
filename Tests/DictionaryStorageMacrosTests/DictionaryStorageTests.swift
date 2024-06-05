import MacroTesting
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(DictionaryStorageMacros)
    import DictionaryStorageMacros
#endif

// swiftlint:disable function_body_length type_body_length
final class DictionaryStorageMacroTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(
            isRecording: false,
            macros: [
                "DictionaryStorage": DictionaryStorageMacro.self,
                "DictionaryStorageProperty": DictionaryStoragePropertyMacro.self
            ]
        ) {
            super.invokeTest()
        }
    }

    private let macros: [String: Macro.Type] = [
        "DictionaryStorage": DictionaryStorageMacro.self,
        "DictionaryStorageProperty": DictionaryStoragePropertyMacro.self
    ]

    func testIgnorePrivate() {
        assertMacro {
            """
            @DictionaryStorage(.hashable)
            struct Test {
              public private(set) var user: User.Id?
              private(set) var test: Int?
              private var myId: User.Id?
              var x: Int = 1

              var y: Int {
                0
              }

              func test() {
              }
            }
            """
        } expansion: {
            """
            struct Test {
              public private(set) var user: User.Id?
              private(set) var test: Int?
              private var myId: User.Id?
              var x: Int = 1 {
                get {
                  _storage["x", default: 1] as? Int ?? 1
                }
                set {
                  _storage["x"] = newValue
                }
              }

              var y: Int {
                0
              }

              func test() {
              }

              init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              var rawDictionary: [String: Any] {
                _storage
              }

              static func == (lhs: Test, rhs: Test) -> Bool {
                return lhs.user == rhs.user &&
                lhs.test == rhs.test &&
                lhs.x == rhs.x
              }

              func hash(into hasher: inout Hasher) {
                hasher.combine(user)
                hasher.combine(test)
                hasher.combine(x)
              }
            }

            extension Test: DictionaryRepresentable {
            }

            extension Test: Equatable {
            }

            extension Test: Hashable {
            }
            """
        }
    }

    func testSingleAttachment() {
        assertMacro {
            """
            @DictionaryStorage(.equatable)
            struct Test {
              @DictionaryStorageProperty("myValue")
              var y: Int = 2
            }
            """
        } expansion: {
            """
            struct Test {
              var y: Int = 2 {
                get {
                  _storage["myValue", default: 2] as? Int ?? 2
                }
                set {
                  _storage["myValue"] = newValue
                }
              }

              init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              var rawDictionary: [String: Any] {
                _storage
              }

              static func == (lhs: Test, rhs: Test) -> Bool {
                return lhs.y == rhs.y
              }
            }

            extension Test: DictionaryRepresentable {
            }

            extension Test: Equatable {
            }
            """
        }
    }

    func testArray() {
        assertMacro {
            """
            @DictionaryStorage
            struct Test {
              var x: [Int] = [1, 2]
              var y: [Int]?
              var location: [Location] = []
              var history: [Location]?
            }
            """
        } expansion: {
            """
            struct Test {
              var x: [Int] = [1, 2] {
                get {
                  _storage["x", default: [1, 2]] as? [Int] ?? [1, 2]
                }
                set {
                  _storage["x"] = newValue
                }
              }
              var y: [Int]? {
                get {
                  _storage["y"] as? [Int]
                }
                set {
                  _storage["y"] = newValue
                }
              }
              var location: [Location] = [] {
                get {
                  guard let values = _storage["location"] as? [Any] else {
                    return []
                  }
                  return values.compactMap {
                    DictionaryStorage.decode(Location.self, value: $0)
                  }
                }
                set {
                  _storage["location"] = newValue.compactMap {
                    DictionaryStorage.encode($0)
                  }
                }
              }
              var history: [Location]? {
                get {
                  guard let values = _storage["history"] as? [Any] else {
                    return nil
                  }
                  return values.compactMap {
                    DictionaryStorage.decode(Location.self, value: $0)
                  }
                }
                set {
                  _storage["history"] = newValue?.compactMap {
                    DictionaryStorage.encode($0)
                  }
                }
              }

              init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              var rawDictionary: [String: Any] {
                _storage
              }
            }

            extension Test: DictionaryRepresentable {
            }
            """
        }
    }

    func testIgnoreDictionaryStorageProperty() {
        assertMacro {
            """
            @DictionaryStorage
            struct Test {
              @DictionaryStorageProperty
              var z: Int = 3

              var x: Int = 1

              @DictionaryStorageProperty("myValue")
              var y: Int = 2
            }
            """
        } expansion: {
            """
            struct Test {
              var z: Int = 3 {
                get {
                  _storage["z", default: 3] as? Int ?? 3
                }
                set {
                  _storage["z"] = newValue
                }
              }

              var x: Int = 1 {
                get {
                  _storage["x", default: 1] as? Int ?? 1
                }
                set {
                  _storage["x"] = newValue
                }
              }
              var y: Int = 2 {
                get {
                  _storage["myValue", default: 2] as? Int ?? 2
                }
                set {
                  _storage["myValue"] = newValue
                }
              }

              init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              var rawDictionary: [String: Any] {
                _storage
              }
            }

            extension Test: DictionaryRepresentable {
            }
            """
        }
    }

    func testDate() {
        assertMacro {
            """
            @DictionaryStorage
            struct Test {
              var changedAt: Date = Date()
              var createdAt: Date?
              var history: [Date] = []
              var passwordHistory: [Date]?
            }
            """
        } expansion: {
            """
            struct Test {
              var changedAt: Date = Date() {
                get {
                  guard let value = _storage["changedAt"] else {
                    return Date()
                  }
                  return DictionaryStorage.decode(Date.self, value: value) ?? Date()
                }
                set {
                  _storage["changedAt"] = DictionaryStorage.encode(newValue)
                }
              }
              var createdAt: Date? {
                get {
                  guard let value = _storage["createdAt"] else {
                    return nil
                  }
                  return DictionaryStorage.decode(Date.self, value: value) ?? nil
                }
                set {
                  _storage["createdAt"] = DictionaryStorage.encode(newValue)
                }
              }
              var history: [Date] = [] {
                get {
                  guard let values = _storage["history"] as? [Any] else {
                    return []
                  }
                  return values.compactMap {
                    DictionaryStorage.decode(Date.self, value: $0)
                  }
                }
                set {
                  _storage["history"] = newValue.compactMap {
                    DictionaryStorage.encode($0)
                  }
                }
              }
              var passwordHistory: [Date]? {
                get {
                  guard let values = _storage["passwordHistory"] as? [Any] else {
                    return nil
                  }
                  return values.compactMap {
                    DictionaryStorage.decode(Date.self, value: $0)
                  }
                }
                set {
                  _storage["passwordHistory"] = newValue?.compactMap {
                    DictionaryStorage.encode($0)
                  }
                }
              }

              init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              var rawDictionary: [String: Any] {
                _storage
              }
            }

            extension Test: DictionaryRepresentable {
            }
            """
        }
    }

    func testCustomType() {
        assertMacro {
            """
            @DictionaryStorage
            struct Test {
              var location: Location = Location()
              var newLocation: Location?
            }
            """
        } expansion: {
            """
            struct Test {
              var location: Location = Location() {
                get {
                  guard let value = _storage["location"] else {
                    return Location()
                  }
                  return DictionaryStorage.decode(Location.self, value: value) ?? Location()
                }
                set {
                  _storage["location"] = DictionaryStorage.encode(newValue)
                }
              }
              var newLocation: Location? {
                get {
                  guard let value = _storage["newLocation"] else {
                    return nil
                  }
                  return DictionaryStorage.decode(Location.self, value: value) ?? nil
                }
                set {
                  _storage["newLocation"] = DictionaryStorage.encode(newValue)
                }
              }

              init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              var rawDictionary: [String: Any] {
                _storage
              }
            }

            extension Test: DictionaryRepresentable {
            }
            """
        }
    }

    func testUUID() {
        assertMacro {
            """
            @DictionaryStorage
            struct Test {
              var credId: UUID = UUID()
              var userId: UUID?
            }
            """
        } expansion: {
            """
            struct Test {
              var credId: UUID = UUID() {
                get {
                  guard let value = _storage["credId"] else {
                    return UUID()
                  }
                  return DictionaryStorage.decode(UUID.self, value: value) ?? UUID()
                }
                set {
                  _storage["credId"] = DictionaryStorage.encode(newValue)
                }
              }
              var userId: UUID? {
                get {
                  guard let value = _storage["userId"] else {
                    return nil
                  }
                  return DictionaryStorage.decode(UUID.self, value: value) ?? nil
                }
                set {
                  _storage["userId"] = DictionaryStorage.encode(newValue)
                }
              }

              init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              var rawDictionary: [String: Any] {
                _storage
              }
            }

            extension Test: DictionaryRepresentable {
            }
            """
        }
    }

    func testExpansionWithoutInitializersEmitsError() {
        assertMacro {
            """
            @DictionaryStorage
            class Point {
              let x: Int
              let y: Int
              var z: Int?
            }
            """
        } diagnostics: {
            """
            @DictionaryStorage
            class Point {
              let x: Int
              ╰─ 🛑 non-optional stored property must have an initializer
              let y: Int
              ╰─ 🛑 non-optional stored property must have an initializer
              var z: Int?
            }
            """
        }
    }

    func testExpansionIgnoresComputedProperties() {
        assertMacro {
            """
            @DictionaryStorage
            struct Test {
              var value: Int {
                get { return 0 }
                set {}
              }
            }
            """
        } expansion: {
            """
            struct Test {
              var value: Int {
                get { return 0 }
                set {}
              }

              init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              var rawDictionary: [String: Any] {
                _storage
              }
            }

            extension Test: DictionaryRepresentable {
            }
            """
        }
    }

    func testPublic() throws {
        assertMacro {
            """
            @DictionaryStorage
            public struct Test {
              public var value: Int = 1
              private var privateValue: Int?
            }
            """
        } expansion: {
            """
            public struct Test {
              public var value: Int = 1 {
                get {
                  _storage["value", default: 1] as? Int ?? 1
                }
                set {
                  _storage["value"] = newValue
                }
              }
              private var privateValue: Int?

              public init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              public var rawDictionary: [String: Any] {
                _storage
              }
            }

            extension Test: DictionaryRepresentable {
            }
            """
        }
    }

    func testNestedEnum() {
        assertMacro {
            """
            @DictionaryStorage
            public struct InputFieldData {

              public enum FiledType: String {
                case text
                case email
              }

              public var label: String?
            }

            extension InputFieldData.FieldType {
              var label: String {
                switch self {
                  case .text:
                    "Text"
                  case .email:
                    "Email"
                }
              }
            }
            """
        } expansion: {
            """
            public struct InputFieldData {

              public enum FiledType: String {
                case text
                case email
              }

              public var label: String? {
                get {
                  _storage["label"] as? String
                }
                set {
                  _storage["label"] = newValue
                }
              }

              public init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              public var rawDictionary: [String: Any] {
                _storage
              }
            }

            extension InputFieldData.FieldType {
              var label: String {
                switch self {
                  case .text:
                    "Text"
                  case .email:
                    "Email"
                }
              }
            }

            extension InputFieldData: DictionaryRepresentable {
            }
            """
        }
    }

    func testBackTick() {
        assertMacro {
            """
            @DictionaryStorage
            public struct Data {

              public enum `Type`: String {
                case text
                case email
              }

              public var `type`: `Type` = .text
              public var `var`: Int = 0
            }
            """
        } diagnostics: {
            """

            """
        }expansion: {
            """
            public struct Data {

              public enum `Type`: String {
                case text
                case email
              }

              public var `type`: `Type` = .text {
                get {
                  guard let value = _storage["type"] else {
                    return .text
                  }
                  return DictionaryStorage.decode(`Type`.self, value: value) ?? .text
                }
                set {
                  _storage["type"] = DictionaryStorage.encode(newValue)
                }
              }
              public var `var`: Int = 0 {
                get {
                  _storage["var", default: 0] as? Int ?? 0
                }
                set {
                  _storage["var"] = newValue
                }
              }

              public init(_ dictionary: [String: Any]) {
                self._storage = dictionary
              }

              private var _storage: [String: Any] = [:]

              public var rawDictionary: [String: Any] {
                _storage
              }
            }

            extension Data: DictionaryRepresentable {
            }
            """
        }

    }
}
// swiftlint:enable function_body_length type_body_length
