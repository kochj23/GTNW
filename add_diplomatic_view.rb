#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('GTNW.xcodeproj')
target = project.targets.find { |t| t.name == 'GTNW_macOS' }
views_group = project.main_group.groups.find { |g| g.display_name == 'Shared' }&.groups&.find { |g| g.display_name == 'Views' }

unless target && views_group
  puts "Error: Could not find target or Views group"
  exit 1
end

file_ref = views_group.new_reference('DiplomaticMessagesView.swift')
file_ref.source_tree = '<group>'
target.source_build_phase.add_file_reference(file_ref)

project.save
puts "✅ Added DiplomaticMessagesView.swift to project"
