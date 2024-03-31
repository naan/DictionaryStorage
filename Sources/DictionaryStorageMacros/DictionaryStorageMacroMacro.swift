import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct DictionaryStorageMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DictionaryStorageMacro.self,
        DictionaryStoragePropertyMacro.self,
        StringRepresentationMacro.self,
        CustomNameMacro.self
    ]
}
