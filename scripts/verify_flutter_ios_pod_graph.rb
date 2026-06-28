#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pathname'

app_root = Pathname.new(ARGV.fetch(0, '.')).expand_path
deps_path = app_root.join('.flutter-plugins-dependencies')

abort("Missing #{deps_path}. Run flutter pub get first.") unless deps_path.file?

deps = JSON.parse(deps_path.read)
spm_enabled = deps.fetch('swift_package_manager_enabled', {}).fetch('ios', nil)
ios_plugins = deps.fetch('plugins').fetch('ios')
plugins_by_name = ios_plugins.to_h { |plugin| [plugin.fetch('name'), plugin] }

required_plugins = %w[google_mobile_ads webview_flutter_wkwebview]
missing_plugins = required_plugins.reject { |name| plugins_by_name.key?(name) }
unless missing_plugins.empty?
  abort("Missing iOS Flutter plugin(s): #{missing_plugins.join(', ')}")
end

google_mobile_ads = plugins_by_name.fetch('google_mobile_ads')
webview_wkwebview = plugins_by_name.fetch('webview_flutter_wkwebview')
google_mobile_ads_dependencies = google_mobile_ads.fetch('dependencies', [])

unless google_mobile_ads_dependencies.include?('webview_flutter_wkwebview')
  abort('google_mobile_ads no longer declares webview_flutter_wkwebview; review this guard before release.')
end

unless spm_enabled == false
  abort("Expected swift_package_manager_enabled.ios=false for CocoaPods release builds; got #{spm_enabled.inspect}.")
end

webview_path = Pathname.new(webview_wkwebview.fetch('path'))
webview_path = app_root.join(webview_path) unless webview_path.absolute?
webview_darwin_dir = webview_path.join('darwin')
webview_podspec = webview_darwin_dir.join('webview_flutter_wkwebview.podspec')
webview_package_swift = webview_darwin_dir.join('webview_flutter_wkwebview', 'Package.swift')

unless webview_podspec.file?
  abort("Missing local webview_flutter_wkwebview podspec at #{webview_podspec}.")
end

puts "swift_package_manager_enabled.ios=#{spm_enabled.inspect}"
puts "google_mobile_ads.dependencies=#{google_mobile_ads_dependencies.join(',')}"
puts "webview_flutter_wkwebview.podspec=#{webview_podspec}"
puts "webview_flutter_wkwebview.package_swift=#{webview_package_swift.file? ? webview_package_swift : 'not present'}"
puts 'iOS CocoaPods plugin graph is release-ready.'
