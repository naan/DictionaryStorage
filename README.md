# @DictionaryStorage

A Swift Macro expands the stored properties of a type into computed properties that access to a storage dictionary. Inspired by WWDC 2023 Video [Expand on Swift macros](https://developer.apple.com/videos/play/wwdc2023/10167?time=748), [the sample code](https://github.com/apple/swift-syntax/blob/main/Examples/Sources/MacroExamples/Implementation/ComplexMacros/DictionaryIndirectionMacro.swift) of [swift-syntax](https://github.com/apple/swift-syntax) and Nikita Ermolenk's [Automating RawRepresentable Conformance with Swift Macros](https://otbivnoe.ru/2023/06/13/Automating-RawRepresentable-Conformance-with-Swift-Macros.html).

## Why @DictionaryStorage?

Swift's `Codable` is great for type safety. But sometimes, you need to work with a JSON object that changes often or has many different versions of it.

Suppose you have the following JSON object in version 1 of your app:

```json
{
    "name" : "John Doe",
    "age" : 30
}
```

Your `Person` type would be something like this:

```swift
struct Person: Codable {
    var name: String
    var age: Int
}
```

It works great. Then later in version 2, you add a new field:
```json
{
    "name" : "John Doe",
    "age" : 30,
    "gender" : "male"
}
```

The `Person` type for version 2 would be:

```swift
struct Person: Codable {
    enum Gender: String, Codable {
        case male, female
    }

    var name: String
    var age: Int
    var gender: Gender
}
```

But what if your customer's iPhone is updated to version 2 while their iPad remains on version 1, and the `Person` object is updated on both devices? The iPhone version saves the `gender` field but the iPad version then overwrites the JSON object without that field, the data gets lost due to the differences in app versions.

Similarly, if additional cases are added to the enum in a newer version of the app, the older version of the app no longer be able to decode the object.

```swift
struct Person: Codable {
    enum Gender: String {
        case male, female, neutral, trans, .....
    }
}

let json = 
"""
{
    "name" : "John Doe",
    "age" : 30,
    "gender" : "trans"
}
""".data(using: .utf8)!

// On an older version of the app
let person = try JSONDecoder(Person.self, json) 
// DecodingError: Cannot initialize `Gender` from invalid String value "trans"
```

One way to solve this problem is to decode the JSON into a raw dictionary and access them from your type's computed properties:

```swift
struct Person {
    enum Gender: RawRepresentable {
        case male, female
        case unknown(String)

        var rawValue: String {
            switch self {
            case .male:
            return "male"
            case .female:
            return "female"
            case .unknown(let value):
            return value
            }
        }

        init?(rawValue: String) {
            switch rawValue {
            case "male":
            self = .male
            case "female":
            self = .female
            default:
            self = .unknown(rawValue)
            }
        }
    }

    var name: String {
        get {
            return _storage["name"] as? String ?? ""
        }
        set {
            _storage["name"] = newValue
        }
    }
    var age: Int? {
        get {
            return _storage["age"] as? Int
        }
        set {
            _storage["age"] = newValue
        }
    }

    private var _storage: [String: Any]

    init(_ dictionary: [String: Any]) {
        self._storage = dictionary
    }
}
```

But this involves a significant amount of boilerplate.

Using `@DictionaryStorage`, you can write just like this:

```swift
@DictionaryStorage
struct Person {

    @StringRawRepresentation
    enum Gender {
        case male, female
        case unknown(String)
    }

    var name: String
    var age: Int?
}
```

The macro expands the code for you like the example above.


## Quick Start

To use `@DictionaryStorage`:

1. **Installation**

   In Xcode, add DictionaryStorage with: `File` → `Add Package Dependencies…` and input the package URL:

   > `https://github.com/naan/DictionaryStorage`

   Or, for SPM-based projects, add it to your package dependencies:

   ```swift
   dependencies: [
     .package(url: "https://github.com/naan/DictionaryStorage", from: "1.0.0")
   ]
   ```

   And then add the product to all targets that use DictionaryStorage:

   ```swift
   .product(name: "DictionaryStorage", package: "DictionaryStorage"),
   ```

2. **Import & basic usage**
   <br/> After importing DictionaryStorage, add `@DictionaryStorage` before your struct/class definition. The macro expands non-private stored properties into computed properties as well as adds an initializer and a read-only accessor to the backed dictionary.

   ```swift
   import DictionaryStorage

   @DictionaryStorage
   struct Person: Identifiable {
     let name: String = ""
     var age: Int?
     private let _id = UUID()
     var id: UUID { _ id }
   }
   ```

   The macro expands the code to:

   ```swift
   struct Person: Identifiable {
     let name: String = "" {
        get {
            _storage["name"] as? String ?? ""
        }
        set {
            _storage["name"] = newValue
        }
     }
     var age: Int? {
        get {
            _stoarge["age"] as? Int
        }
        set {
            if newValue {
                _storage["age"] = newValue
            }
        }
     }

     // DictionaryStorage does not expand private, nor computed properties.
     private let _id = UUID() 
     var id: UUID { _id  }

     private var _storage: [String: Any]

     init(_ dictionary: [String: Any]) {
        _storage = dictionary
     }

     var rawDictionary: [String: Any] {
        _storage
     }

   }

   extension Person: DictionaryRepresentable {}
   ```

   Using `@DictionaryStorage` type:

   ```swift
   let data = 
        """
        {
            "name": "John Doe",
            "age": 30,
            "gender": "male"
        },
        """.data(using: .utf8)!

    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    var person = Person(json!)
    print(person.name)     // "John Doe"
    print(person.age)      // 30

    person.age += 1

    print(person.rawDictionary)
    // Preserve unknown fields such as `gender`
    // ["name": "John Doe", "age": 31, "gender": "male"]
   ```
   
    You can specify a different key name than the property name by using `@DictionaryStorageProperty`:

   ```swift
   @DictionaryStorage
   struct Person {
     @DictionaryStorageProperty("person_name")
     var name: String = ""
   }
   ```

   The macro expands the code to: 

   ```swift
   struct Person {
     var name: String = "" {
        get {
            _storage["person_name"] as? String ?? ""
        }
        set {
            _storage["person_name"] = newValue
        }
     }
     ...
   }
   ```

## Reference

This package includes the following macros:

### `@DictionaryStorage`

Attach to a type you want to be `DictionaryRepresentable`.

* `@DictionaryStorage`
  <br/> Expand non-private stored properties to computed properties. Also add an initializer with `[String: Any]` as well as a read-only property to access the dictionary.

* `@DictionaryStorage(.equatable)`
  <br/>  Enables the attached type to conform to `Equatable`. Note, that the `==`` method only compares the known properties and does not compare private properties nor already computed properties before the macro applied.

  ```swift
  @DictionaryStorage(.equatable)
  struct Person {
    let name: String = ""
    var age: Int?
  }
  ```

  The macro expands to:
  ```swift
  struct Person {
    let name: String = "" {
       ...
    }
    var age: Int? {
       ...
    }
    ...

    static func == (lhs: Person, rhs: Person) -> Bool {
      lhs.name == rhs.name &&
      lhs.age == rhs.age
    }
  }

  ...

  extension Person: Equatable {}
  ```


* `@DictionaryStorage(.hashable)`
  <br /> Enables the attached type to conform to `Hashable`.

### `@DictionaryStorageProperty(_ key: String)`

Use this macro on property declarations of a type that is annotated with `@DictionaryStorage`.

* `@DictionaryStorageProperty("custom_name")`
  <br /> Specifies "custom_name" as the key for the dictionary.

### `@StringRawRepresentation`

Applying this macro to an enum ensures it can be represented as a raw string. This is particularly useful in conjunction with `@DictionaryStorage`.

* `@StringRawRepresentation`
  <br> Make the attached enum to be a string raw representable.
  ```swift
  @StringRawRepresentation
  public enum InputType {
      case text
      case email
      case password
      @CustomName("select-one") case option
      case unknown(String)
  }
  ```

  The macro expands to:

    ```swift
    public enum InputType {
        ...

        public var rawValue: String {
            switch self {
            case .text:
            return "text"
            case .email:
            return "email"
            case .password:
            return "password"
            case .option:
            return "select-one"
            case .unknown(let value):
            return value
            }
        }

        public init?(rawValue: String) {
            switch rawValue {
            case "text":
            self = .text
            case "email":
            self = .email
            case "password":
            self = .password
            case "select-one":
            self = .option
            default:
            self = .unknown(rawValue)
            }
        }    
    }

    extension InputType: RawRepresentable {
    }

    extension InputType: Equatable {
    }
    ```

### `@CustomName(_ name: String)`

Use this macro to set a custom name for an enum that is annotated with `@StringRawRepresentation`.

* `@CustomName("custom_name")`
  <br /> Specifies `"custom_name"` as a raw value of the enum case this macro is attached to.

## Advanced Topics

### Support Custom Types

By default, DictionaryStorage supports primitive types that `JSONSerialization` supports, which are `Bool`, `Int`, `String`, `Double` and their variants such as `Int8`, `Float`, etc. DictionaryStorage also supports array of those primitives as well other instances DictionaryStorage and arrays of DictionaryStorage.

By writing a custom encoder/decoder, you can use non-primitive types for DictionaryStorage.

Suppose your data has UUID strings and you want to encode/decode to Foundation's `UUID` type instead of `String`, you can write a custom encoder/decoder as an extension of `DictionaryStorage`:

```swift
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
```

Now you can use `@DictionaryStorage` to a type like this:

```swift
@DictionaryStorage
struct Person: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var age: Int?
}
```

The macro expands to:

```swift
struct Person {
    var id: UUID = UUID() {
        get {
            guard let value = _storage["id"] else {
                return UUID()
            }
            return DictionaryStorage.decode(UUID.self, value: value) ?? UUID()
        }
        set {
            _storage["id"] = DictionaryStorage.encode(newValue)
        }
    } 
    var name: String = "" { ... }
    var age: Int? { ... }
}
```

This works for types that consume a single entry in the backed dictionary such as `UUID`, `Date`, `URL`, `Data` and so on. See [CustomTypes.swift](Tests/DictionaryStorageTests/CustomTypes.swift) for a sample implementation.

For types requres multiple entries in the dictionary and you can't use `@DictionaryStorage` macro for the type, use `DictionaryRepresentable` protocol described below.

### Manually conforming `DictionaryRepresentable` protocol

`DictionaryRepresentable` is a protocol that is added to `@DictionaryStorage` attached type:

```swift
public protocol DictionaryRepresentable {
    init(_ dictionary: [String: Any])
    var rawDictionary: [String: Any] { get }
}
```

Manually conforming this protocol to a custom type then `@DictionaryStorage` will be able to handle the custom type.

Say, you need to support a heterogeneous array that holds several different types of `@DictionaryStorage` backed types:

```swift
@DictionaryStorage
struct Web {
    var type: Usage.UsageType = .web
    var name: String = ""
    var url: String = ""
}

@DictionaryStorage
struct App {
    var type: Usage.UsageType = .app
    var name: String = ""
    var bundleId: String = ""
}

// `Usage` can be `Web`, `App`, or possibly something else in a future version.
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

    var _storage: [String: Any]

    // MARK: - DictionaryRepresentable 

    var rawDictionary: [String: Any] {
        _storage
    }

    init(_ dictionary: [String: Any]) {
        self._storage = dictionary
        if let typeString = dictionary["type"] as? String,
          let type = UsageType(rawValue: typeString) {
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

// Now you can use `Usage` inside of another `@DictionaryStorage` type.
@DictionaryStorage
struct Object {
    var usages: [Usage] = []
}

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
                "name": "Chrome",
                "bundleId": "com.google.chrome",
            },
            {
                "type": "something_else",
                "name": "Something Else",
            },
        ]
    }
    """.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let object = Object(json!)
    if case let .web(web) = object.usages[0].value {
        print(web.type == .web) // true
        print(web.name)         // "Example.com"
        print(web.url)          // "https://www.example.com"
    }
```


### Utilizing `@DictionaryStorage` with `@MemberwiseInit`

If you want your type to be capable of both reading from a dictionary and constructing one, use `@DictionaryStorage` with [`@MemberwiseInit`](https://github.com/gohanlon/swift-memberwise-init-macro) macro.

```swift
@DictionaryStorage
struct Person {
    var name: String = ""
}

// This works but not great
var person = Person([:])
person.name = "John Doe"
let dict = person.rawDictionary // ["name": "John Doe"]
```

With `@MemberwiseInit`:

```swift
@MemberwiseInit
@DictionaryStorage
struct Person {
    var name: String = ""
}
```

The macro expands to:

```swift
struct Person {
    var name: String = "" {
        ...
    }

    internal init(
        name: String = ""
    ) {
        self.name = name
    }
}
```

Now you can write like this:

```swift
let person = Person(name: "John Doe")
let dict = person.rawDictionary // ["name": "John Doe"]
```

## License

`@DictionaryStorage` is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

 