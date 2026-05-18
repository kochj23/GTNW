require 'xcodeproj'
project = Xcodeproj::Project.open('/Volumes/Data/xcode/GTNW/GTNW.xcodeproj')
project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['DEVELOPMENT_TEAM'] = 'QRRCB8HB3W'
    config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
  end
end
project.save
puts "Done"
