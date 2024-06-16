//
//  Created by Kazuho Okui on 3/17/24.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(DictionaryStorageMacros)
    import DictionaryStorageMacros
#endif

// swiftlint:disable function_body_length
final class StringRepresentationMacroTests: XCTestCase {

    private let macros: [String: Macro.Type] = [
        "StringRawRepresentation": StringRepresentationMacro.self,
        "CustomName": CustomNameMacro.self
    ]

    func testStringRawRepresentation() throws {
        assertMacroExpansion(
            """
            @StringRawRepresentation
            enum Visa {
                case tourist // test comment
                case business
                case student
                case other(String)
            }
            """,
            expandedSource: """
                enum Visa {
                    case tourist // test comment
                    case business
                    case student
                    case other(String)

                  var rawValue: String {
                    switch self {
                    case .tourist:
                      return "tourist"
                    case .business:
                      return "business"
                    case .student:
                      return "student"
                    case .other(let value):
                      return value
                    }
                  }

                  init?(rawValue: String) {
                    switch rawValue {
                    case "tourist":
                      self = .tourist
                    case "business":
                      self = .business
                    case "student":
                      self = .student
                    default:
                      self = .other(rawValue)
                    }
                  }
                }

                extension Visa: RawRepresentable {
                }

                extension Visa: Equatable {
                }
                """,
            macros: macros,
            indentationWidth: .spaces(2)
        )
    }

    func testCustomName() throws {
        assertMacroExpansion(
            """
            @StringRawRepresentation
            enum Type {
              case text
              case email
              @CustomName("select-one") case option
              case other(String)
            }
            """,
            expandedSource: """
                enum Type {
                  case text
                  case email
                  case option
                  case other(String)

                  var rawValue: String {
                    switch self {
                    case .text:
                      return "text"
                    case .email:
                      return "email"
                    case .option:
                      return "select-one"
                    case .other(let value):
                      return value
                    }
                  }

                  init?(rawValue: String) {
                    switch rawValue {
                    case "text":
                      self = .text
                    case "email":
                      self = .email
                    case "select-one":
                      self = .option
                    default:
                      self = .other(rawValue)
                    }
                  }
                }

                extension Type: RawRepresentable {
                }

                extension Type: Equatable {
                }
                """,
            macros: macros,
            indentationWidth: .spaces(2)
        )
    }

    func testWithClass() {
        assertMacroExpansion(
            """
            @StringRawRepresentation
            class Visa {
              var expiration: Date
            }
            """,
            expandedSource: """
                class Visa {
                  var expiration: Date
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@StringRawRepresentation only works with Enums", line: 1, column: 1),
                DiagnosticSpec(message: "@StringRawRepresentation only works with Enums", line: 1, column: 1)
            ],
            macros: macros,
            indentationWidth: .spaces(2)
        )

    }

    func testIgnoreCustomRawRepresentable() {
        assertMacroExpansion(
            """
            @StringRawRepresentation
            enum Visa: RawRepresentable {
              case hello(String)
              case world(Int)
            }
            """,
            expandedSource: """
                enum Visa: RawRepresentable {
                  case hello(String)
                  case world(Int)
                }
                """,
            macros: macros,
            indentationWidth: .spaces(2)
        )
    }

    func testPublic() {
        assertMacroExpansion(
            """
            @StringRawRepresentation
            public enum Visa {
              case hello
              case world(String)
            }
            """,
            expandedSource: """
                public enum Visa {
                  case hello
                  case world(String)

                  public var rawValue: String {
                    switch self {
                    case .hello:
                      return "hello"
                    case .world(let value):
                      return value
                    }
                  }

                  public init?(rawValue: String) {
                    switch rawValue {
                    case "hello":
                      self = .hello
                    default:
                      self = .world(rawValue)
                    }
                  }
                }

                extension Visa: RawRepresentable {
                }

                extension Visa: Equatable {
                }
                """,
            macros: macros,
            indentationWidth: .spaces(2)
        )
    }

    func testDefault() {
        assertMacroExpansion(
            """
            @StringRawRepresentation
            public enum Visa {
              case hello
            }
            """,
            expandedSource: """
                public enum Visa {
                  case hello

                  public var rawValue: String {
                    switch self {
                    case .hello:
                      return "hello"
                    }
                  }

                  public init?(rawValue: String) {
                    switch rawValue {
                    case "hello":
                      self = .hello
                    default:
                      return nil
                    }
                  }
                }

                extension Visa: RawRepresentable {
                }

                extension Visa: Equatable {
                }
                """,
            macros: macros,
            indentationWidth: .spaces(2)
        )
    }

    func testMultipleElements() {
        assertMacroExpansion(
            """
            @StringRawRepresentation
            public enum Visa {
              case hello, world
              case custom(String)
            }
            """,
            expandedSource: """
                public enum Visa {
                  case hello, world
                  case custom(String)

                  public var rawValue: String {
                    switch self {
                    case .hello:
                      return "hello"
                    case .world:
                      return "world"
                    case .custom(let value):
                      return value
                    }
                  }

                  public init?(rawValue: String) {
                    switch rawValue {
                    case "hello":
                      self = .hello
                    case "world":
                      self = .world
                    default:
                      self = .custom(rawValue)
                    }
                  }
                }

                extension Visa: RawRepresentable {
                }

                extension Visa: Equatable {
                }
                """,
            macros: macros,
            indentationWidth: .spaces(2)
        )
    }

}
// swiftlint:enable function_body_length
