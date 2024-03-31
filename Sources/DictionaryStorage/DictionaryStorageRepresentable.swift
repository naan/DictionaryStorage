//
//  Created by Kazuho Okui on 3/17/24.
//

import Foundation

/// A protocol that enables `@`DictionaryStorage` to encode/decode custom data.
///
/// Confirm to this protocol with your custom data so that `@DictionaryStorage` can encode/decode it.
public protocol DictionaryRepresentable {
    init(_ dictionary: [String: Any])
    var rawDictionary: [String: Any] { get }
}

public struct DictionaryStorage {}

extension DictionaryStorage {

    static public func decode<T>(_ type: T.Type, value: Any?) -> T? where T: DictionaryRepresentable {
        if let dict = value as? [String: Any] {
            return type.init(dict)
        }
        return nil
    }

    static public func decode<T, U>(_ type: T.Type, value: Any?) -> T? where T: RawRepresentable<U> {
        if let value = value as? U {
            return type.init(rawValue: value)
        }
        return nil
    }

}

extension DictionaryStorage {

    static public func encode<T>(_ value: T?) -> Any? where T: DictionaryRepresentable {
        return value?.rawDictionary
    }

    static public func encode<T, U>(_ value: T?) -> Any? where T: RawRepresentable<U> {
        return value?.rawValue
    }
}
