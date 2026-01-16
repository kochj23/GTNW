#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'GTNW.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the targets
ios_target = project.targets.find { |t| t.name == 'GTNW_iOS' }
macos_target = project.targets.find { |t| t.name == 'GTNW_macOS' }

# Find or create Design group
shared_group = project.main_group['Shared']
design_group = shared_group['Design'] || shared_group.new_group('Design')

# Add ModernDesign.swift with correct path
modern_design_file = design_group.new_file('Design/ModernDesign.swift')
ios_target.source_build_phase.add_file_reference(modern_design_file)
macos_target.source_build_phase.add_file_reference(modern_design_file)

project.save

puts "✅ ModernDesign.swift added to both iOS and macOS targets"
