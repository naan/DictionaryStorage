import Foundation
import DictionaryStorage

// MARK: - Support Custom Types

extension DictionaryStorage {

    static public func decode(_ type: Date.Type, value: Any?) -> Date? {
        if let intValue = value as? Double {
            return Date(timeIntervalSince1970: intValue)
        } else {
            return nil
        }
    }

    static func encode(_ value: Date?) -> Any? {
        return value?.timeIntervalSince1970
    }
}

extension DictionaryStorage {

    static public func decode(_ type: UUID.Type, value: Any?) -> UUID? {
        if let value = value as? String {
            return UUID(uuidString: value)
        } else {
            return nil
        }
    }

    static func encode(_ value: UUID?) -> Any? {
        return value?.uuidString
    }

}

extension DictionaryStorage {

    static public func decode(_ type: Data.Type, value: Any?) -> Data? {
        if let value = value as? String {
            return Data(base64Encoded: value, options: .ignoreUnknownCharacters)
        } else {
            return nil
        }
    }

    static func encode(_ value: Data?) -> Any? {
        return value?.base64EncodedString()
    }

}
