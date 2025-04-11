require "json"

json = File.read(File.join(__dir__, "package.json"))
package = JSON.parse(json).deep_symbolize_keys

Pod::Spec.new do |s|
  s.name = "tristans-file-streamer"
  s.version = package[:version]
  s.license = { type: "MIT" }
  s.homepage = "https://github.com/tristanjakobi/react-native-background-upload-encrypted"
  s.authors = package[:author]
  s.summary = "A fork of react-native-background-upload with enhanced file streaming capabilities for both upload and download operations"
  s.source = { git: package[:repository][:url] }
  s.source_files = "ios/*.{h,m}"
  s.platform = :ios, "9.0"

  s.dependency "React"
end
