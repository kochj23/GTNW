#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('GTNW.xcodeproj')

# Find files with wrong paths and fix them
project.files.each do |file|
  if file.path&.include?('Shared/Models/Shared/Models/')
    file.path = file.path.gsub('Shared/Models/Shared/Models/', 'Shared/Models/')
    puts "Fixed: #{file.path}"
  elsif file.path&.include?('Shared/Views/Shared/Views/')
    file.path = file.path.gsub('Shared/Views/Shared/Views/', 'Shared/Views/')
    puts "Fixed: #{file.path}"
  end
end

project.save
puts "✅ Paths fixed"
