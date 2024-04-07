import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension VariableDeclSyntax {
    var isStoredProperty: Bool {
        guard let binding = bindings.first, bindings.count == 1, !isLazyProperty, !isConstant else {
            return false
        }
        switch binding.accessorBlock?.accessors {
        case .accessors(let node):
            for idx in node {
                switch idx.accessorSpecifier {
                case .keyword(.willSet), .keyword(.didSet):
                    break
                default:
                    return false
                }
                return true
            }
            return true
        case .getter:
            return false
        case .none:
            return true
        }
    }

    var isPrivate: Bool {
        for mod in modifiers {
            if mod.name.text == "private" && mod.detail?.detail.text != "set" {
                return true
            }
        }
        return false
    }

    var isLazyProperty: Bool {
        modifiers.contains { $0.name.tokenKind == .keyword(Keyword.lazy) }
    }

    var isConstant: Bool {
        bindingSpecifier.tokenKind == .keyword(Keyword.let) && bindings.first?.initializer != nil
    }

    var name: String? {
        guard let patternBinding = bindings.first?.as(PatternBindingSyntax.self) else { return nil }
        guard let name = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
            return nil
        }
        return name.text
    }

    var getNameAndType: (name: String, type: String)? {
        guard let patternBinding = bindings.first?.as(PatternBindingSyntax.self) else { return nil }
        guard let name = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
            let type = patternBinding.typeAnnotation?.as(TypeAnnotationSyntax.self)?.type.as(IdentifierTypeSyntax.self)?.name
        else {
            return nil
        }
        return (name: name.text, type: type.text)
    }
}

extension DeclGroupSyntax {
    /// Get the stored properties from the declaration based on syntax.
    func storedProperties() -> [VariableDeclSyntax] {
        memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                variable.isStoredProperty
            else {
                return nil
            }
            return variable
        }
    }

    var hasInitFunction: Bool {
        memberBlock
            .members
            .contains { member in
                guard member.decl.as(InitializerDeclSyntax.self) != nil else {
                    return false
                }
                return true
            }
    }
}

extension AttributeListSyntax {
    func getAttributedElement(_ macroName: String) -> AttributeListSyntax.Element? {
        self.first {
            $0.as(AttributeSyntax.self)?
                .attributeName
                .as(IdentifierTypeSyntax.self)?
                .description == macroName
        }
    }

    // Only support to get first parameter
    func getAttributeElementParameter(_ macroName: String) -> TokenSyntax? {
        if let element = self.getAttributedElement(macroName),
            let expr = element.getExprSyntax(),
            let name = expr.as(StringLiteralExprSyntax.self)?.segments.first,
            let content = name.as(StringSegmentSyntax.self)?.content
        {
            return content
        }
        return nil

    }
}

extension AttributeListSyntax.Element {
    func getExprSyntax(_ argumentName: String? = nil) -> ExprSyntax? {
        if let argumentName {
            self
                .as(AttributeSyntax.self)?
                .arguments?
                .as(LabeledExprListSyntax.self)?
                .first(where: {
                    $0.label?.text == argumentName
                })?
                .expression
        } else {
            self
                .as(AttributeSyntax.self)?
                .arguments?
                .as(LabeledExprListSyntax.self)?
                .first?
                .expression
        }
    }
}

extension DeclModifierListSyntax {
    var isPublic: Bool {
        if self.contains(where: {
            $0.as(DeclModifierSyntax.self)?.name.text == "public"
        }) {
            return true
        }
        return false
    }
}

extension TypeSyntax {
    var rawType: TypeSyntax {
        if let optional = self.as(OptionalTypeSyntax.self) {
            if let array = optional.wrappedType.as(ArrayTypeSyntax.self) {
                return array.element
            } else {
                return optional.wrappedType
            }
        } else if let array = self.as(ArrayTypeSyntax.self) {
            return array.element
        } else {
            return self
        }
    }

    var isOptional: Bool {
        self.is(OptionalTypeSyntax.self)
    }

    var isArray: Bool {
        if let optional = self.as(OptionalTypeSyntax.self) {
            optional.wrappedType.is(ArrayTypeSyntax.self)
        } else {
            self.is(ArrayTypeSyntax.self)
        }
    }

    var removeOptional: TypeSyntax {
        self.as(OptionalTypeSyntax.self)?.wrappedType ?? self
    }

    var identifierName: String? {
        self.rawType.as(IdentifierTypeSyntax.self)?.name.text
    }

}

extension TokenSyntax {
    var identifierName: String {
        self.text.replacingOccurrences(of: "`", with: "")
    }
}
