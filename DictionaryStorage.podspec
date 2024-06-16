Pod::Spec.new do |s|

  s.name         = "DictionaryStorage"
  s.version      = "1.2"
  s.summary      = "A Swift Macro expands the stored properties of a type into computed properties that access a storage dictionary."

  s.description  = <<-DESC
    A Swift Macro expands the stored properties of a type into computed properties that access a storage dictionary.
    DESC

  s.homepage     = "https://github.com/naan/DictionaryStorage"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "naan" => "https://github.com/naan" }

  s.ios.deployment_target = "13.0"
  s.tvos.deployment_target = "13.0"
  s.osx.deployment_target = "10.15"
  s.watchos.deployment_target = "6.0"

  s.source       = { :git => "https://github.com/naan/DictionaryStorage.git", :tag => "#{s.version}" }

  s.prepare_command = 'swift build -c release && cp -f .build/release/DictionaryStorageMacros ./Binary'

  s.source_files  = "Sources/DictionaryStorage/*.swift"
  s.swift_versions = "5.9"

  s.preserve_paths = ["Binary/DictionaryStorageMacros"]
  s.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => [
      '-load-plugin-executable ${PODS_ROOT}/DictionaryStorage/Binary/DictionaryStorageMacros#DictionaryStorageMacros'
    ]
  }
  s.user_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => [
      '-load-plugin-executable ${PODS_ROOT}/DictionaryStorage/Binary/DictionaryStorageMacros#DictionaryStorageMacros'
    ]
  }

end
