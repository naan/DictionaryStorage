//
//  Created by Kazuho Okui on 3/17/24.
//
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum StringRepresentationMacro {}

extension StringRepresentationMacro: ExtensionMacro {

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        if try errorCheck(declaration: declaration) == false {
            return []
        }

        let rawRepresentableExtension: DeclSyntax =
            """
            extension \(type.trimmed): RawRepresentable {}
            """
        let equatableExtension: DeclSyntax =
            """
            extension \(type.trimmed): Equatable {}
            """
        guard let rawRepresentable = rawRepresentableExtension.as(ExtensionDeclSyntax.self) else { return [] }
        guard let equtable = equatableExtension.as(ExtensionDeclSyntax.self) else { return [] }

        return [rawRepresentable, equtable]
    }
}

extension StringRepresentationMacro: MemberMacro {

    // swiftlint:disable:next function_body_length
    public static func expansion<Declaration, Context>(
        of node: AttributeSyntax,
        providingMembersOf declaration: Declaration,
        in context: Context
    ) throws -> [DeclSyntax]
    where Declaration: DeclGroupSyntax, Context: MacroExpansionContext {

        if try errorCheck(declaration: declaration) == false {
            return []
        }

        let cases = declaration.memberBlock.members
            .compactMap {
                $0.decl.as(EnumCaseDeclSyntax.self)
            }

        let modifier: TokenSyntax = declaration.modifiers.isPublic ? "public" : ""

        let initializer = try InitializerDeclSyntax("\(modifier) init?(rawValue: String)") {
            try SwitchExprSyntax("switch rawValue") {
                var hasDefault = false
                for caseDecl in cases {
                    let customName = customName(for: caseDecl)
					let customPrefix = customPrefix(for: caseDecl)
                    for element in caseDecl.elements {

						let name = customName ?? element.name.trimmed

                        if element.parameterClause == nil {
                            SwitchCaseSyntax(
                                """
                                case "\(name)":
                                  self = .\(element.name.trimmed)
                                """
                            )
                        } else if let customPrefix {
                            SwitchCaseSyntax(
                                """
                                case let name where name.hasPrefix("\(customPrefix)"):
                                  self = .\(name)(String(name.suffix(from: name.index(name.startIndex, offsetBy: "\(customPrefix)".count))))
                                """
                            )
                        } else {
							let _ = (hasDefault = true)
                            SwitchCaseSyntax(
                                """
                                default:
                                  self = .\(name)(rawValue)
                                """
                            )
                        }
                    }
                }
                if !hasDefault {
                    SwitchCaseSyntax(
                        """
                        default:
                          return nil
                        """
                    )
                }
            }
        }

        let variable = try VariableDeclSyntax("\(modifier) var rawValue: String") {
            try SwitchExprSyntax("switch self") {
                for caseDecl in cases {
                    let customName = customName(for: caseDecl)
                    let customPrefix = customPrefix(for: caseDecl)
                    for element in caseDecl.elements {

                        let value = customName ?? element.name.trimmed

                        if element.parameterClause == nil {
                            SwitchCaseSyntax(
                                """
                                case .\(element.name.trimmed):
                                  return "\(value)"
                                """
                            )
                        } else if let customPrefix {
                            SwitchCaseSyntax(
                                """
                                case .\(element.name.trimmed)(let value):
                                  return "\(customPrefix)" + value
                                """
                            )
                        } else {
                            SwitchCaseSyntax(
                                """
                                case .\(element.name.trimmed)(let value):
                                  return value
                                """
                            )
                        }
                    }
                }
            }
        }

        return [
            DeclSyntax(variable),
            DeclSyntax(initializer)
        ]
    }
}

extension StringRepresentationMacro {

    private static func customName(for caseDecl: EnumCaseDeclSyntax) -> TokenSyntax? {
        return caseDecl.attributes.getAttributeElementParameter("CustomName")
    }

    private static func customPrefix(for caseDecl: EnumCaseDeclSyntax) -> TokenSyntax? {
        return caseDecl.attributes.getAttributeElementParameter("CustomPrefix")
    }

    private static func errorCheck(declaration: some DeclGroupSyntax) throws -> Bool {
        if let enumDeclaration = declaration.as(EnumDeclSyntax.self) {
            if let inheritedTypes = enumDeclaration.inheritanceClause?.inheritedTypes,
                inheritedTypes.contains(where: { inherited in
                    inherited.type.trimmedDescription == "RawRepresentable" || inherited.type.trimmedDescription == "Equatable"
                }) {
                return false
            }
        } else {
            throw CustomError.message("@StringRawRepresentation only works with Enums")
        }
        return true
    }
}
