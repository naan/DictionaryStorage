// The Swift Programming Language
// https://docs.swift.org/swift-book

public enum DictionaryStorageOption {
    case equatable
    case hashable
}

// I like to use enum for DictionaryStorageOption enum directly but it seems there's a compiler bug where
// if I set custom enum to `memberAttribute` macro, the Swfit compiler crashes. Use struct instead.
/// Option for `@DictionaryStorage`.
///
public struct DictionaryStorageOptionHolder {
    private var value: DictionaryStorageOption
    init(_ value: DictionaryStorageOption) {
        self.value = value
    }
    /// Expand `@DictionaryStorage` applied struct/class to confirm to `Equatable`.
    public static let equatable = DictionaryStorageOptionHolder(.equatable)
    /// Expand `@DictionaryStorage` applied struct/class to confirm to `Hashable`.
    public static let hashable = DictionaryStorageOptionHolder(.hashable)
}

// MARK: - Dictionary Storage

/// Wrap up the stored properties of the given type in a dictionary turning them into computed properties.
///
/// This macro composes two different kinds of macro expansion:
///   * Member-attribute macro expansion, to put `DictionaryStorageProperty` macro on all stored properties of the type it is attached to.
///   * Member macro expansion, to add a `_storage` property with the actual dictionary, an initializer with a dictionarry, as well as a read-only property to access the backed dictionary.
@attached(member, names: named(_storage), named(init(_:)), named(rawDictionary), named(hash), named(==))
@attached(extension, conformances: DictionaryRepresentable, Equatable, Hashable)
@attached(memberAttribute)
public macro DictionaryStorage() =
    #externalMacro(module: "DictionaryStorageMacros", type: "DictionaryStorageMacro")

/// `@DictionaryStorage` with an option.
///
/// * .equatable: Conform the applied type to `Equatable`.
/// * .hashable: Conform the applied type to`Hashable`.
@attached(member, names: named(_storage), named(init(_:)), named(rawDictionary), named(hash), named(==))
@attached(extension, conformances: DictionaryRepresentable, Equatable, Hashable)
@attached(memberAttribute)
public macro DictionaryStorage(_ option: DictionaryStorageOptionHolder) =
    #externalMacro(module: "DictionaryStorageMacros", type: "DictionaryStorageMacro")

@attached(accessor)
public macro DictionaryStorageProperty() =
    #externalMacro(module: "DictionaryStorageMacros", type: "DictionaryStoragePropertyMacro")

/// `@DictionaryStorageProperty` with an option.
///
/// Specify `key` to customize a key in the dictionary.
@attached(accessor)
public macro DictionaryStorageProperty(_ key: String) =
    #externalMacro(module: "DictionaryStorageMacros", type: "DictionaryStoragePropertyMacro")

// MARK: - RawRepresentable

/// Automating RawRepresentable Conformance or enum with string.
@attached(member, names: named(rawValue), named(init))
@attached(extension, conformances: RawRepresentable, Equatable)
public macro StringRawRepresentation() =
    #externalMacro(module: "DictionaryStorageMacros", type: "StringRepresentationMacro")

/// Customize name of the key for @StringRawRepresentation.
@attached(peer)
public macro CustomName(_ name: String) =
    #externalMacro(module: "DictionaryStorageMacros", type: "CustomNameMacro")
