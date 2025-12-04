#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'GTNW.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == 'GTNW_macOS' }

# Find or create Models group
models_group = project.main_group['Shared']['Models']
views_group = project.main_group['Shared']['Views']

# Add HistoricalAdministrations.swift
hist_file = models_group.new_file('Shared/Models/HistoricalAdministrations.swift')
target.source_build_phase.add_file_reference(hist_file)

# Add AdministrationSelectionView.swift
admin_view_file = views_group.new_file('Shared/Views/AdministrationSelectionView.swift')
target.source_build_phase.add_file_reference(admin_view_file)

project.save

puts "✅ Files added to Xcode project"
