#!/usr/bin/env ruby
# Adds Shared/Storage/*.swift to the macOS + iOS app targets and GTNWTests/GameStoreTests.swift to the test target.
# Idempotent. Run from the repo root.
require 'xcodeproj'
project = Xcodeproj::Project.open('GTNW.xcodeproj')
shared = project.main_group['Shared'] or abort 'no Shared group'
storage = shared['Storage'] || shared.new_group('Storage', 'Storage')
apps = project.targets.select { |t| %w[GTNW_macOS GTNW_iOS].include?(t.name) }
Dir['Shared/Storage/*.swift'].sort.each do |path|
  name = File.basename(path)
  ref = storage.files.find { |f| f.path == name } || storage.new_file(name)
  apps.each { |t| t.source_build_phase.add_file_reference(ref, true) unless t.source_build_phase.files_references.include?(ref) }
end
tests = project.targets.find { |t| t.name == 'GTNWTests' }
tgroup = project.main_group['GTNWTests']
Dir['GTNWTests/GameStore*.swift'].sort.each do |path|
  name = File.basename(path)
  ref = tgroup.files.find { |f| f.path == name || f.path == path } || tgroup.new_file(name)
  tests.source_build_phase.add_file_reference(ref, true) unless tests.source_build_phase.files_references.include?(ref)
end
project.save
puts 'storage files linked'

# Bundle the games-pg CA (public) and give the macOS app its keychain-access-groups entitlement.
project = Xcodeproj::Project.open('GTNW.xcodeproj')
storage = project.main_group['Shared']['Storage']
ca = storage.files.find { |f| f.path == 'games-pg-ca.crt' } || storage.new_file('games-pg-ca.crt')
project.targets.select { |t| %w[GTNW_macOS GTNW_iOS].include?(t.name) }.each do |t|
  t.resources_build_phase.add_file_reference(ca, true) unless t.resources_build_phase.files_references.include?(ca)
end
mac = project.targets.find { |t| t.name == 'GTNW_macOS' }
shared = project.main_group['Shared']
shared.files.find { |f| f.path == 'GTNW_macOS_App.entitlements' } || shared.new_file('GTNW_macOS_App.entitlements')
mac.build_configurations.each { |c| c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Shared/GTNW_macOS_App.entitlements' }
project.save
puts 'CA + entitlements linked'
