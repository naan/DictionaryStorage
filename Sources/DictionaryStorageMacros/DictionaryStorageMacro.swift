//
//  Created by Kazuho Okui on 3/16/24.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct DictionaryStorageMacro {}

extension DictionaryStorageMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        let modifier: TokenSyntax = declaration.modifiers.isPublic ? "public" : ""

        guard let type = declaration.as(StructDeclSyntax.self)?.name ?? declaration.as(ClassDeclSyntax.self)?.name else {
            return []
        }

        let properties = dictionaryStorageProperties(for: declaration)

        let option = dictionaryStorageOption(for: node)

        let variableNames = properties.compactMap({ $0.name })

        let equals = variableNames.map {
            "lhs.\($0) == rhs.\($0)"
        }
        let hash = variableNames.map {
            "hasher.combine(\($0))"
        }

        let variables: [DeclSyntax] = [
            """
            \(modifier) init(_ dictionary: [String: Any]) {
            self._storage = dictionary
            }
            """,
            """
            private var _storage: [String: Any] = [:]
            """,
            """
            \(modifier) var rawDictionary: [String: Any] {
            _storage
            }
            """
        ]

        let hashable: DeclSyntax =
            """
            \(modifier) func hash(into hasher: inout Hasher) {
            \(raw: hash.joined(separator: "\n"))
            }
            """

        let equatable: DeclSyntax =
            """
            \(modifier) static func == (lhs: \(type.trimmed), rhs: \(type.trimmed)) -> Bool {
            return \(raw: equals.joined(separator: " && \n"))
            }
            """

        switch option {
        case "equatable":
            return variables + [equatable]
        case "hashable":
            return variables + [equatable, hashable]
        default:
            return variables
        }
    }
}

extension DictionaryStorageMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let inheritanceClause: InheritanceClauseSyntax? =
            if let classDeclaration = declaration.as(ClassDeclSyntax.self) {
                classDeclaration.inheritanceClause
            } else if let structDeclaration = declaration.as(StructDeclSyntax.self) {
                structDeclaration.inheritanceClause
            } else {
                throw CustomError.message("@DictionaryStorage only applicable to structs or classes")
            }

        if let inheritedTypes = inheritanceClause?.inheritedTypes,
            inheritedTypes.contains(where: { inherited in inherited.type.trimmedDescription == "DictionaryRepresentable" })
        {
            return []
        }

        let dictionaryRepresentableExtension: DeclSyntax =
            """
            extension \(type.trimmed): DictionaryRepresentable {}
            """
        let equatableExtension: DeclSyntax =
            """
            extension \(type.trimmed): Equatable {}
            """
        let hashableExtension: DeclSyntax =
            """
            extension \(type.trimmed): Hashable {}
            """

        guard let dictExtensionDecl = dictionaryRepresentableExtension.as(ExtensionDeclSyntax.self) else { return [] }
        guard let equatableExtensionDecl = equatableExtension.as(ExtensionDeclSyntax.self) else { return [] }
        guard let hashableExtensionDecl = hashableExtension.as(ExtensionDeclSyntax.self) else { return [] }

        let option = dictionaryStorageOption(for: node)

        switch option {
        case "equatable":
            return [dictExtensionDecl, equatableExtensionDecl]
        case "hashable":
            return [dictExtensionDecl, equatableExtensionDecl, hashableExtensionDecl]
        default:
            return [dictExtensionDecl]
        }
    }
}

extension DictionaryStorageMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let property = member.as(VariableDeclSyntax.self),
            property.isStoredProperty && !property.isPrivate
        else {
            return []
        }

        // Ignore if manually set @DictionaryStorageProperty.
        if property.attributes.getAttributedElement("DictionaryStorageProperty") != nil {
            return []
        }

        // Ignore private variables.
        if property.modifiers.contains(where: { $0.name.text == "private" }) {
            return []
        }

        return [
            AttributeSyntax(
                leadingTrivia: [.newlines(1), .spaces(2)],
                attributeName: IdentifierTypeSyntax(
                    name: .identifier("DictionaryStorageProperty")
                )
            )
        ]
    }
}

public struct DictionaryStoragePropertyMacro: AccessorMacro {
    public static func expansion<
        Context: MacroExpansionContext,
        Declaration: DeclSyntaxProtocol
    >(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: Declaration,
        in context: Context
    ) throws -> [AccessorDeclSyntax] {

        guard let varDecl = declaration.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
            binding.accessorBlock == nil,
            let type = binding.typeAnnotation?.type
        else {
            return []
        }

        // Ignore the "_storage" variable.
        if identifier.text == "_storage" {
            return []
        }

        // Ignore the "rawDictionary" variable.
        if identifier.text == "rawDictionary" {
            return []
        }

        let defaultValue = binding.initializer?.value

        if type.isOptional == false && defaultValue == nil {
            throw CustomError.message("non-optional stored property must have an initializer")
        }

        var dictionaryKey = identifier
        // Update dictionary key if specified
        if let argument = node.arguments?.as(LabeledExprListSyntax.self)?.first?
            .expression.as(StringLiteralExprSyntax.self)?.segments.first?
            .as(StringSegmentSyntax.self)?.content
        {
            dictionaryKey = argument
        }

        if isPrimitive(type) == false {
            return dictionaryRepresentableProperty(key: dictionaryKey, defaultValue: defaultValue, type: type)
        } else {
            return primitiveProperty(key: dictionaryKey, defaultValue: defaultValue, type: type)
        }
    }

    private static func isPrimitive(_ type: TypeSyntax) -> Bool {

        guard let typeName = type.identifierName else {
            return false
        }

        let primitiveTypes = [
            "Bool", "Int", "UInt",
            "Int8", "Int16", "Int32", "Int64",
            "UInt8", "UInt16", "UInt32", "UInt64",
            "Float", "Double", "String"
        ]
        return primitiveTypes.contains(typeName)
    }

    private static func dictionaryRepresentableProperty(
        key: TokenSyntax,
        defaultValue: ExprSyntax?,
        type: TypeSyntax
    ) -> [AccessorDeclSyntax] {
        let returnValue: ExprSyntax = defaultValue ?? "nil"
        let newValue: ExprSyntax = type.isOptional ? "newValue?" : "newValue"

        if type.isArray {
            return [
                """
                get {
                  guard let values = _storage[\(literal: key.text)] as? [Any] else {
                    return \(returnValue)
                  }
                  return values.compactMap { DictionaryStorage.decode(\(type.rawType.trimmed).self, value: $0) }
                }
                """,
                setter(key, value: "\(newValue).compactMap { DictionaryStorage.encode($0) }")
            ]
        } else {
            return [
                """
                get {
                  guard let value = _storage[\(literal: key.text)] else {
                    return \(returnValue)
                  }
                  return DictionaryStorage.decode(\(type.rawType.trimmed).self, value: value) ?? \(returnValue)
                }
                """,
                setter(key, value: "DictionaryStorage.encode(newValue)")
            ]
        }
    }

    private static func setter(_ key: TokenSyntax, value: ExprSyntax) -> AccessorDeclSyntax {
        """
        set {
          \(storage(for: key)) = \(value)
        }
        """
    }

    private static func primitiveProperty(key: TokenSyntax, defaultValue: ExprSyntax?, type: TypeSyntax) -> [AccessorDeclSyntax] {
        return [
            primitiveGetter(key: key, defaultValue: defaultValue, type: type),
            setter(key, value: "newValue")
        ]
    }

    private static func primitiveGetter(key: TokenSyntax, defaultValue: ExprSyntax?, type: TypeSyntax) -> AccessorDeclSyntax {

        let castType = type.removeOptional

        if let defaultValue {
            return """
                get {
                  \(storage(for: key, default: defaultValue)) as! \(castType)
                }
                """
        } else {
            return """
                get {
                  \(storage(for: key)) as? \(castType)
                }
                """
        }
    }

    private static func storage(for key: TokenSyntax, default defaultValue: ExprSyntax? = nil) -> TokenSyntax {
        if let defaultValue {
            "_storage[\(literal: key.text), default: \(defaultValue)]"
        } else {
            "_storage[\(literal: key.text)]"
        }
    }
}

extension DictionaryStorageMacro {
    static func dictionaryStorageProperties(for declaration: some DeclGroupSyntax) -> [VariableDeclSyntax] {
        var properties: [VariableDeclSyntax] = []

        for member in declaration.memberBlock.members {
            guard let property = member.decl.as(VariableDeclSyntax.self),
                property.isStoredProperty && !property.isPrivate
            else {
                continue
            }
            properties.append(property)
        }
        return properties
    }

    static func dictionaryStorageOption(for node: AttributeSyntax) -> String? {
        return node.arguments?.as(LabeledExprListSyntax.self)?.first?.expression
            .as(MemberAccessExprSyntax.self)?.declName.baseName.text
    }
}
