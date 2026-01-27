#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('GTNW.xcodeproj')

files_to_remove = [
  'ImageGenerationService.swift',
  'ImageGenerationView.swift'
]

files_to_remove.each do |filename|
  project.targets.each do |target|
    target.source_build_phase.files.to_a.each do |build_file|
      if build_file.file_ref && build_file.file_ref.display_name == filename
        puts "Removing #{filename} from #{target.name}"
        target.source_build_phase.remove_file_reference(build_file.file_ref)
      end
    end
  end

  # Remove from groups
  project.main_group.recursive_children.each do |item|
    if item.respond_to?(:display_name) && item.display_name == filename
      puts "Removing #{filename} from project groups"
      item.remove_from_project
    end
  end
end

project.save
puts "✅ Removed image generation file references"
